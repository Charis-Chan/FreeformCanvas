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
| Movement | Walk, run (double-tap), jump, double jump, ground dash, air dash (held direction, else facing). No turning in the air |
| Movement | Run-turnaround: reversing while running skids for a few frames, then keeps running the other way (no new double-tap) |
| Movement | Dash dancing: reversing in the first few frames of a run has no skid (window length is data; tuned by playtest) |
| Movement | Jump squat (a few frames before leaving the ground) + short hop (jump released during jump squat) vs full hop (held) |
| Movement | Reverse aerial rush: jumping during a run-turnaround keeps the old momentum but uses the new facing |
| Attacks (per character) | Jab, side strong, forward aerial, up aerial, down aerial, neutral special (with B-reverse) |
| Combat | Damage %, knockback that scales with damage, blast zones, stocks |
| Combat | Ground bounce: a fighter spiked into the ground or a platform while still in hitstun bounces up once per move (two different spike moves can each bounce once). Fixed bounce height below a damage threshold (data, ~20-30%), higher with knockback above it. Hitstun keeps counting (no reset). No dropping through platforms during hitstun |
| Combat | Hurtbox: one box per fighter (48 x 90, `size` in character data), not shaped to the art |
| Combo openers | Stun (with stun decay + cooldown), Slow (timer + cooldown) |
| Cancels | Attack → attack, attack → dash |
| Anti-infinite | Combo scaling (decreased hitstun for consecutive hits, providing an end to combos) + attack decay (using same attack repeatedly within a short window has decreased damage) |
| Defense | Shield |
| Content | 1 stage |
| Modes | Versus (local), vs CPU |
| AI | CPU opponent (state machine; steering + recovery to stage) |

## Polish — needed to look "Steam ready"

| Feature |
|---|
| Hitstop, screenshake, hit sounds |
| Hurtbox size per state (e.g. shorter in jump squat), only if playtesting shows the single box feels wrong |
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
| Attacks | Neutral aerial, back aerial |
| Attacks | Dash attack |
| Combat | Per-move hurtbox changes (e.g. an extended limb can be hit during a slow attack's startup) |

## Controls

| Action | Player 1 | Player 2 (stand-in until CPU) |
|---|---|---|
| Move left / right | A / D | Left / Right arrow |
| Up / down (aim, drop through platforms) | W / S | Up / Down arrow |
| Run | Double-tap A or D | Double-tap Left or Right |
| Jump (tap = short hop, hold = full hop) | Space | Right Shift |
| Dash (held direction, else facing; doesn't turn you in the air) | Left Shift | Right Ctrl |
| Attack (jab on ground; in air: up aerial if holding up, down aerial if holding down, else forward aerial) | P | . (period) |
| Special (hold the opposite direction right after pressing to B-reverse) | O | , (comma) |
| Strong (aerial in the air) | I | / (slash) |
| Menus: confirm | Enter | Enter |
| Debug: toggle Slow on P2 | F1 | — |

## Changes

- Oct 6: Down aerial moved Stretch → Core (already implemented; covers below for edge-guarding). Back aerial added to Stretch.
- Oct 6: No turning in the air; air dash follows the held direction. B-reverse on neutral special added to Core (moves that knock the opponent behind you need a way to turn around mid-air to extend combos).
- Oct 19: Added run-turnaround, dash dancing, jump squat + short hop, and reverse aerial rush to Core. Nothing removed: judged essential to movement feel (short hops are needed for aerial combos; with air facing locked, ground facing before a jump decides every aerial). Frame counts live in character data. Built after collision (Oct 26).
- Oct 21: Hurtboxes stay boxes, not shaped to the sprites (pixel shapes feel unfair, tie balance to the art and cost days). One 48 x 90 box per fighter in Core; per-state sizes in Polish if playtesting needs it; per-move hurtboxes in Stretch.
- Oct 27: Added ground bounce to Core (gives down aerial an on-stage combo use). Nothing removed: small, and part of how knockback meets the stage. Raises the priority of combo scaling, since low-% bounce loops are the main infinite risk.
