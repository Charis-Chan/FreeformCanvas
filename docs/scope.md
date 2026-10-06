# Scope

Locked for CP2 (Oct 2026). This decides **which features exist**. Numbers
(damage, knockback, frame data, timers) are tuning and keep changing through
CP5.

Rule: nothing moves from Stretch into Core without something of equal size
moving out. Stretch is only touched after Core is done and CP6 has passed.

## Core — must ship

| Area | Feature |
|---|---|
| Characters | 2 characters, built one at a time: **Character 1 = Stun opener**, **Character 2 = Slow opener** |
| Movement | Walk, run (double-tap), jump, double jump, ground dash, air dash (dash direction = facing, for now) |
| Attacks (per character) | Jab, side strong, forward aerial, up aerial, neutral special |
| Combat | Damage %, knockback that scales with damage, blast zones, stocks |
| Combo openers | Stun (with stun decay + cooldown), Slow (timer + cooldown) |
| Cancels | Attack → attack, attack → dash |
| Anti-infinite | Combo scaling (less hitstun per hit) + repeat decay (same move weakens) |
| Defense | Shield |
| Content | 1 stage |
| Modes | Versus (local), vs CPU |
| AI | CPU opponent (state machine; steering + recovery to stage) |

## Polish — needed to look "Steam ready"

| Feature |
|---|
| Hitstop, screenshake, hit sounds |
| Controller support |
| Pause menu |
| Character select screen |
| Consistent art style |
| Results screen (basic version exists) |

## Stretch — only if ahead after CP6

| Area | Feature |
|---|---|
| Movement | Wall jump, wall slide |
| Stage | Platform spawner |
| Defense | Grabs, parries |
| Modes | Training mode |
| Attacks | Directional normals (up / down / forward) |
| Attacks | Directional specials (up / down / side) |
| Attacks | Up strong, down strong |
| Attacks | Neutral aerial, down aerial |
| Attacks | Dash attack |

## Controls

| Action | Player 1 | Player 2 (stand-in until CPU) |
|---|---|---|
| Move left / right | A / D | Left / Right arrow |
| Up / down (aim, drop through platforms) | W / S | Up / Down arrow |
| Run | Double-tap A or D | Double-tap Left or Right |
| Jump | Space | Right Shift |
| Dash | Left Shift | Right Ctrl |
| Attack (jab on ground; in air: up aerial if holding up, else forward aerial) | P | . (period) |
| Special | O | , (comma) |
| Strong (aerial in the air) | I | / (slash) |
| Menus: confirm | Enter | Enter |
| Debug: toggle Slow on P2 | F1 | — |
