package main

import "core:math/rand"
import rl "vendor:raylib"

// The CPU opponent. It doesn't move the fighter itself: each tick it decides
// which buttons to hold and hands back an Input, exactly like a keyboard
// would. So it obeys the same rules as a player (frame data, jumps, dashes,
// hitstun) and gets hit by the same collision.

Cpu_State :: enum {
	Approach, // move toward the opponent
	Attack,   // one attack, chosen for where the opponent is
	Retreat,  // back off for a moment
	Recover,  // off the stage: get back to it
	Hitstun,  // being hit: no control, wait it out
}

// Tuning, loaded from data/cpu.json.
Cpu_Config :: struct {
	reaction_ticks: int, // how late the CPU's button presses arrive (0 = instant)
	attack_range:   f32, // horizontal distance at which it starts an attack
	aggression:     f32, // 0..1: chance to keep attacking instead of retreating
	retreat_ticks:  int, // how long a retreat lasts
	dash_distance:  f32, // dash toward the opponent when farther than this
}

MAX_REACTION_TICKS :: 60

Cpu :: struct {
	state:       Cpu_State,
	state_ticks: int, // ticks spent in the current state
	// Buttons it decided last tick (see press).
	last: Input,
	// Where Approach is heading. Chosen on the ground and kept through a
	// jump (a player commits to a jump the same way), except when it's the
	// opponent, who is followed every tick.
	target:        Vec2,
	target_is_opp: bool,

	// The directions of the current attack (e.g. Up for up air, Right to
	// face right). Held for the whole attack, so a slowed fighter that skips
	// a tick still sees them, and B-reverse has time to happen.
	attack_dirs: Input,

	// The reaction delay: what the opponent looked like on each recent
	// tick. The CPU acts on the one from reaction_ticks ago.
	seen: [MAX_REACTION_TICKS + 1]Fighter,
	tick: int,
}

cpu_set_state :: proc(cpu: ^Cpu, state: Cpu_State) {
	if cpu.state != state {
		cpu.state = state
		cpu.state_ticks = 0
	}
}

EDGE_MARGIN :: 40 // how far inside the stage's edge counts as safe

// The solid platform everyone fights on (the first one that isn't soft).
main_platform :: proc(stage: Stage) -> rl.Rectangle {
	for p in stage.platforms {
		if !p.soft do return p.rect
	}
	return {}
}

// The platform the fighter is standing on, if any (even with the body
// hanging over its edge).
platform_under :: proc(me: Fighter, stage: Stage) -> (rect: rl.Rectangle, standing: bool) {
	if !me.grounded do return
	half_w := me.character.stats.size.x / 2
	for p in stage.platforms {
		r := p.rect
		if me.pos.y == r.y && me.pos.x + half_w > r.x && me.pos.x - half_w < r.x + r.width {
			return r, true
		}
	}
	return
}

on_soft_platform :: proc(me: Fighter, stage: Stage) -> bool {
	for p in stage.platforms {
		if p.soft && me.grounded && me.pos.y == p.rect.y do return true
	}
	return false
}

// Past the sides of the main stage, or below its top. Standing on anything
// counts as on stage, even with the body hanging over an edge.
is_off_stage :: proc(me: Fighter, stage: Stage) -> bool {
	if me.grounded do return false
	main := main_platform(stage)
	return me.pos.x < main.x || me.pos.x > main.x + main.width || me.pos.y > main.y + 1
}

// Moves in `dir` (+1 right, -1 left), but never walks off the platform it's
// standing on (it leaves a soft platform by dropping through instead).
steer :: proc(me: Fighter, stage: Stage, dir: f32) -> Input {
	if under, standing := platform_under(me, stage); standing {
		if dir > 0 && me.pos.x > under.x + under.width - EDGE_MARGIN do return {}
		if dir < 0 && me.pos.x < under.x + EDGE_MARGIN do return {}
	}
	return {.Right} if dir > 0 else {.Left}
}

// How far the fighter can go in `dir` before the main stage's edge.
room_ahead :: proc(me: Fighter, stage: Stage, dir: f32) -> f32 {
	main := main_platform(stage)
	if dir > 0 do return main.x + main.width - me.pos.x
	return me.pos.x - main.x
}

// Adds `button` only if it wasn't held last tick, so the fighter sees a fresh
// press (fighters react to presses, not to buttons being held).
press :: proc(cpu: ^Cpu, input: ^Input, button: Button) {
	if button not_in cpu.last do input^ += {button}
}

// How much higher the fighter can still get from here, with a margin: a
// jump if it's on the ground (or what's left of its rise if it's already
// going up), plus a double jump if it has one left.
// Height of a jump = speed^2 / (2 x gravity).
jump_reach :: proc(me: Fighter) -> f32 {
	s := me.character.stats
	reach: f32
	if me.grounded {
		reach = s.jump_velocity * s.jump_velocity / (2 * s.gravity)
	} else if me.vel.y < 0 {
		reach = me.vel.y * me.vel.y / (2 * s.gravity)
	}
	if me.air_jumps_left > 0 {
		reach += s.double_jump_velocity * s.double_jump_velocity / (2 * s.gravity)
	}
	return reach * 0.9
}

// Where to head for. Usually the opponent; but if they're higher than a jump
// and double jump can reach, the platform that gets it closest to them on
// the way up. The stage is a handful of platforms, so this one rule is all
// the pathfinding it needs.
waypoint :: proc(me, opponent: Fighter, stage: Stage) -> (target: Vec2, is_opponent: bool) {
	reach := jump_reach(me)
	if me.pos.y - opponent.pos.y <= reach do return opponent.pos, true

	best := opponent.pos
	best_dist: f32 = max(f32)
	for p in stage.platforms {
		top := p.rect.y
		rise := me.pos.y - top
		// Must be above us, reachable, and below the opponent.
		if rise < 20 || rise > reach || top <= opponent.pos.y do continue
		// The point on this platform closest to the opponent.
		x := clamp(opponent.pos.x, p.rect.x + EDGE_MARGIN, p.rect.x + p.rect.width - EDGE_MARGIN)
		if dist := abs(x - opponent.pos.x); dist < best_dist {
			best_dist = dist
			best = {x, top}
		}
	}
	return best, best == opponent.pos
}

// Picks the attack that fits where the opponent is. On the ground the held
// direction turns the fighter to face them first.
choose_attack :: proc(me: Fighter, dx, dy: f32) -> Input {
	toward: Input = {.Right} if dx > 0 else {.Left}
	if me.grounded {
		if abs(dx) < 55 do return toward + {.Attack}         // jab
		if rand.float32() < 0.5 do return toward + {.Strong} // side strong
		return toward + {.Special}                           // neutral special
	}
	if dy < -40 do return {.Up, .Attack}   // up aerial
	if dy > 40 do return {.Down, .Attack}  // down aerial
	facing_them := (dx > 0) == (me.facing > 0)
	if facing_them do return {.Attack}     // forward aerial
	return toward + {.Special}             // behind us: neutral special, B-reversed toward them
}

// Called once per game tick. Returns the buttons the CPU's fighter holds.
cpu_update :: proc(cpu: ^Cpu, me, opponent: Fighter, stage: Stage, config: Cpu_Config) -> Input {
	// Remember the opponent as it is now, and look at it as it was
	// reaction_ticks ago (or as it is now, early in the match).
	size := len(cpu.seen)
	cpu.seen[cpu.tick % size] = opponent
	seen := opponent
	if cpu.tick >= config.reaction_ticks {
		seen = cpu.seen[(cpu.tick - config.reaction_ticks) % size]
	}
	cpu.tick += 1

	input := cpu_think(cpu, me, seen, stage, config)
	cpu.last = input
	cpu.state_ticks += 1
	return input
}

// The state machine: what to do in each state, and when to switch.
cpu_think :: proc(cpu: ^Cpu, me, opponent: Fighter, stage: Stage, config: Cpu_Config) -> Input {
	// Getting hit (or stunned) overrides everything.
	if me.state == .Hitstun || me.state == .Stunned {
		cpu_set_state(cpu, .Hitstun)
		return {}
	}
	if cpu.state != .Recover && is_off_stage(me, stage) {
		cpu_set_state(cpu, .Recover)
	}

	input: Input
	dx := opponent.pos.x - me.pos.x // + = opponent is to the right
	dy := opponent.pos.y - me.pos.y // + = opponent is below

	switch cpu.state {
	    case .Hitstun:
		    // Hitstun just ended (the check above didn't return).
		    cpu_set_state(cpu, .Approach)
    	case .Approach:
		    in_range := abs(dx) < config.attack_range && dy > -140 && dy < 60
            // Standing on a platform above it: climb up and fight there instead
            // of up-airing through the platform every time.
            if opponent.grounded && dy < -40 do in_range = false
            if in_range {
                attack := choose_attack(me, dx, dy)
                cpu.attack_dirs = attack & DIRECTIONS
                cpu_set_state(cpu, .Attack)
                input += attack
                break
            }
            // Head for the opponent, or for a platform on the way up to them.
            if me.grounded || cpu.target_is_opp || cpu.state_ticks == 0 {
                cpu.target, cpu.target_is_opp = waypoint(me, opponent, stage)
            }
            target := cpu.target
            tx := target.x - me.pos.x
            ty := target.y - me.pos.y // negative = target is above
            toward: f32 = 1 if tx > 0 else -1
            if abs(tx) > 10 do input += steer(me, stage, toward)

            if me.grounded {
                if ty < -40 && abs(tx) < 150 {
                    press(cpu, &input, .Jump) // target is above: jump
                } else if dy > 60 && on_soft_platform(me, stage) {
                    input += {.Down} // opponent is below: drop through
                } else if abs(dx) > config.dash_distance && me.dash_cooldown == 0 && room_ahead(me, stage, toward) > 200 {
                    press(cpu, &input, .Dash) // close the gap
                }
            } else if me.air_jumps_left > 0 {
                // Double jump once it starts falling, if still below the target.
                if me.vel.y > 0 && ty < -40 {
                    press(cpu, &input, .Jump)
                }
            }
    	case .Attack:
            // The attack was pressed on entering this state. Keep facing it, and
            // wait until it has started (a slowed fighter can take a tick or
            // two), then finished.
            input += cpu.attack_dirs
            started := cpu.state_ticks > 2
            if started && me.state != .Attack {
                if rand.float32() < config.aggression {
                    cpu_set_state(cpu, .Approach)
                } else {
                    cpu_set_state(cpu, .Retreat)
                }
            }
        case .Retreat:
            away: f32 = -1 if dx > 0 else 1
            input += steer(me, stage, away)
            if cpu.state_ticks >= config.retreat_ticks {
                cpu_set_state(cpu, .Approach)
            }
        case .Recover:
            if me.grounded {
                cpu_set_state(cpu, .Approach)
                break
            }
            main := main_platform(stage)
            // Head for the nearest point just inside the stage's edge. If it's
            // under the stage, go out past the nearest edge first.
            target_x := clamp(me.pos.x, main.x + EDGE_MARGIN, main.x + main.width - EDGE_MARGIN)
            if me.pos.y > main.y && target_x == me.pos.x {
                left_gap := me.pos.x - main.x
                right_gap := main.x + main.width - me.pos.x
                target_x = main.x - EDGE_MARGIN if left_gap < right_gap else main.x + main.width + EDGE_MARGIN
            }
            input += {.Right} if target_x > me.pos.x else {.Left}

            falling := me.vel.y > 0
            gap := abs(target_x - me.pos.x)
            if falling && me.pos.y > main.y - 40 && me.air_jumps_left > 0 {
                press(cpu, &input, .Jump) // about to drop below the stage: double jump
            } else if me.pos.y < main.y - 10 && gap > 40 && me.air_dashes_left > 0 && me.dash_cooldown == 0 {
                press(cpu, &input, .Dash) // still above the stage's top: dash sideways toward it
            }
	}
	return input
}

