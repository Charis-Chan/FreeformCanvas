package main

import "core:math"
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

apply_hit :: proc(attacker, victim: ^Fighter){
    a := attacker.character.moves[attacker.move]
    attacker.hit_landed = true

    victim.damage += a.damage
    
    knockback := a.base_knockback + a.knockback_growth * victim.damage / 100

    radians := a.angle * math.RAD_PER_DEG
    victim.vel = {
        math.cos(radians) * knockback * attacker.facing,
        -math.sin(radians) * knockback,
    }

    victim.hitstun_left = int(knockback * attacker.rules.hitstun_per_knockback)
    set_state(victim, .Hitstun)
    victim.events += {.Hit}
}