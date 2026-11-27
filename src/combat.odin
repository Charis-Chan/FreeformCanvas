package main

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

resolve_hits :: proc(g: ^Game){
    a, b := &g.fighters[0], &g.fighters[1]
    a_hits_b := attack_connects(a^, b^)
    b_hits_a := attack_connects(b^, a^)
    if a_hits_b do apply_hit(a, b)
    if b_hits_a do apply_hit(b, a)
}

attack_connects :: proc(attacker, victim: Fighter) -> bool {
    if attacker.hit_landed do return false
    box, active := attack_hitbox(attacker)
    if !active do return false
    return rl.CheckCollisionRecs(box, fighter_body(victim))
}

apply_hit :: proc(attacker, victim: ^Fighter) {
	a := attacker.character.moves[attacker.move]
	rules := attacker.rules
	attacker.hit_landed = true // each attack hits once

	victim.damage += a.damage

	// Knockback grows with the victim's damage (counted after this hit).
	// knockback_growth is the extra speed added per 100%.
	knockback := a.base_knockback + a.knockback_growth * victim.damage / 100

	// The angle is in degrees: 0 = straight forward (the way the attacker
	// faces), 90 = straight up, -90 = straight down. Screen y points down,
	// so the y part is negated.
	radians := a.angle * math.RAD_PER_DEG
	direction := Vec2{math.cos(radians) * attacker.facing, -math.sin(radians)}

	stuns := a.opener == .Stun && can_be_stunned(victim^)
	if stuns || victim.state == .Stunned {
		// Frozen: save this hit's launch for when the stun ends.
		if victim.state != .Stunned do victim.stun_dir_total = {}
		victim.stun_dir_total += direction
		victim.stun_last_dir = direction
		victim.stun_knockback = knockback // only the last hit's strength counts
		if stuns {
			// A stun hit (re)starts the stun; other hits don't.
			victim.stun_left = rules.stun_ticks
			victim.stuns_this_combo += 1
			if victim.stuns_this_combo >= rules.stun_max_per_combo {
				victim.stun_cooldown = rules.stun_cooldown_ticks
			}
		}
		victim.vel = {}
		set_state(victim, .Stunned)
	} else {
		victim.vel = direction * knockback
		victim.hitstun_left = int(knockback * rules.hitstun_per_knockback)
		set_state(victim, .Hitstun)
	}

	if a.opener == .Slow && victim.slow_left == 0 && victim.slow_cooldown == 0 {
		victim.slow_left = rules.slow_ticks
		victim.time_scale = rules.slow_scale
	}

	victim.events += {.Hit}
}

// Stun only works up to stun_max_per_combo times in one combo, and not
// during the cooldown after that.
can_be_stunned :: proc(f: Fighter) -> bool {
	return f.stuns_this_combo < f.rules.stun_max_per_combo && f.stun_cooldown == 0
}

// The stun has run out: launch once, as hard as the last hit, in the
// average direction of every hit taken while stunned.
launch_after_stun :: proc(f: ^Fighter) {
	direction := f.stun_last_dir
	if length := linalg.length(f.stun_dir_total); length > 0.01 {
		direction = f.stun_dir_total / length
	}
	f.vel = direction * f.stun_knockback
	f.hitstun_left = int(f.stun_knockback * f.rules.hitstun_per_knockback)
	set_state(f, .Hitstun)
}

// Called once per game tick (real time, even for a slowed fighter).
update_opener_timers :: proc(f: ^Fighter) {
	// Slow runs out, then can't be applied again until its cooldown ends.
	if f.slow_left > 0 {
		f.slow_left -= 1
		if f.slow_left == 0 {
			f.time_scale = 1
			f.slow_cooldown = f.rules.slow_cooldown_ticks
		}
	} else if f.slow_cooldown > 0 {
		f.slow_cooldown -= 1
	}

	// A combo ends once the fighter has been free for combo_reset_ticks.
	in_combo := f.state == .Hitstun || f.state == .Stunned
	if in_combo {
		f.free_ticks = 0
	} else {
		f.free_ticks += 1
		if f.free_ticks >= f.rules.combo_reset_ticks do f.stuns_this_combo = 0
	}
	// The stun cooldown starts once the last stun is over.
	if f.stun_cooldown > 0 && f.state != .Stunned do f.stun_cooldown -= 1
}
