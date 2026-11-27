# Attribution

| asset (file) | source (URL) | author | licence | changes you made |
|---|---|---|---|---|
| raylib (library, via Odin `vendor:raylib`) | https://www.raylib.com | Ramon Santamaria (raysan5) and contributors | zlib | none |
| raylib default font (fallback only) | https://www.raylib.com | Ramon Santamaria (raysan5) and contributors | zlib | none |
| `assets/fonts/main.ttf` (Audiowide, used for all on-screen text) | https://fonts.google.com/specimen/Audiowide | Astigmatic | SIL Open Font License 1.1 | renamed to main.ttf |
| `assets/sounds/jump.ogg` (original: drop_001.ogg) | https://kenney.nl/assets/interface-sounds | Kenney (kenney.nl) | CC0 1.0 | renamed to jump.ogg |
| `assets/sounds/hit.ogg` (original: impactPunch_medium_001.ogg) | https://kenney.nl/assets/impact-sounds | Kenney (kenney.nl) | CC0 1.0 | renamed to hit.ogg |
| `assets/sounds/ko.ogg` (original: explosionCrunch_001.ogg) | https://kenney.nl/assets/sci-fi-sounds | Kenney (kenney.nl) | CC0 1.0 | renamed to ko.ogg |

## AI-generated assets

| asset (file) | tool + model | prompt (short) | hand edits |
|---|---|---|---|
| `src/main.odin` | Claude Code (Anthropic) | CP2 skeleton: fixed-timestep loop with update/render split; CP3: audio device, asset loading, audio pass, quit on missing data | |
| `src/game.odin` | Claude Code (Anthropic) | CP2 skeleton: Title / Match / Results game states; CP3: loads data files at startup, F5 reload of all data; F2 debug box toggle; Collision (typed in by me from `docs/collision_guide.md`): runs hit checks every tick; CP4: VS CPU / VERSUS menu on the title screen, player 2's input from the CPU, loads data/cpu.json (F5 reloads it); Openers: removed the F1 Slow debug toggle | |
| `src/fighter.odin` | Claude Code (Anthropic) | Fighter entity as data (stats, moves, input), movement (walk, run, jump, double jump, ground/air dash), ground vs air attack selection, per-fighter time scale for Slow, air facing lock, held-direction air dash, B-reverse; CP3: reads stats/moves/rules from loaded data, sound events; Collision (typed in by me from `docs/collision_guide.md`): knockback angle per move, hitstun state, each attack hits once, Hit event; CP4: buttons held on ticks a slowed fighter skips still count (fixes lost CPU presses under Slow); Openers: Stunned state (frozen in place, launched when it ends), stun and slow fields, opener timers each game tick, respawn clears openers; Recovery: double jump redirects you toward the held direction | Added a Down_Aerial (move, frame data, hitbox, selection); retuned Side_Strong, Neutral_Special frame data and Forward_Aerial hitbox; added hitbox explanation comment; changed the B_REVERSE_WINDOW (4->5) |
| `src/stage.odin` | Claude Code (Anthropic) | Stage and platform structs | `load_stage` is mine (see Original work) |
| `src/render.odin` | Claude Code (Anthropic) | All drawing, separate from game logic; CP3: loaded font, character names, F5 reload message; sprite drawing (feet anchored, mirrored by facing); real character art drawn untinted with placeholder fallback, animation frames from data; grey grid background, platform top edges, HUD panels and text shadows, P1/P2 tags above fighters; CP4: title mode menu, CPU state label (F2), CPU name in the HUD and "CPU WINS"; Openers: stun vibration and STUNNED in the HUD, slowed fighters tinted blue with a countdown clock | Added a Down_Aerial label |
| `src/data.odin` | Claude Code (Anthropic) | CP3: loads rules and characters from JSON, error messages with line numbers; per-animation frame timing in character data; Collision (typed in by me from `docs/collision_guide.md`): hitstun and knockback friction rules with a zero check; CP4: loads data/cpu.json with checks; Openers: stun and slow rules with checks | |
| `src/assets.odin` | Claude Code (Anthropic) | CP3: Assets struct (font + sounds) loaded once, shared, unloaded once; audio pass; shared fighter sprite; per-character, per-animation sprite loading (64x64 frames, feet on row 51); Collision (typed in by me from `docs/collision_guide.md`): hit sound, per-sound volume | Changed sound paths to .ogg; changed sprite file naming to `<character>_<animation>.png` |
| `data/rules.json`, `data/characters/lucy.json` | Claude Code (Anthropic) | CP3: values moved from code into data files; idle frame timing; collision: hitstun and knockback friction rules; openers: stun and slow rules | Chose which moves stun; retuned Lucy's run_speed (8.5 -> 10) and air_speed (4.5 -> 5.5); knockback values and angles (starting values suggested by Claude Code); after playtesting, side strong and double jump retuned by Claude Code from kill-percentage tests |
| `docs/scope.md` | Claude Code (Anthropic) | Core / polish / stretch scope table from my design decisions | Rewrote anti-infinite wording; moved down aerial to Core, added back aerial to Stretch; maintain the Changes log |
| `docs/tasks.md` | Claude Code (Anthropic) | CP3 task list with owners; code backlog | Keep the status column updated |
| `data/cpu.json` | Claude Code (Anthropic) | CP4: CPU tuning values (reaction time, attack range, aggression, retreat time, dash distance) | |
| `src/combat.odin` (openers) | Claude Code (Anthropic) | Openers: Stun and Slow applied on hit, hits saved while stunned, one launch when the stun ends (last hit's knockback, averaged direction), 5 stuns per combo with a cooldown, Slow timer and cooldown | |
| `docs/openers_guide.md` | Claude Code (Anthropic) | Explanation of the opener code, written from my decisions | |
| `docs/controls.md` | Claude Code (Anthropic) | How-to-play guide (goal, modes, controls, moves, Stun and Slow, debug keys) from the game's code | |
| `docs/playtest_feedback.md` | Claude Code (Anthropic) | Playtest feedback list, from my playtest notes | |
| `docs/cpu.md` | Claude Code (Anthropic) | CP4 write-up: CPU states, transitions and the movement justification, written from my decisions | |
| `docs/cpu_guide.md` | Claude Code (Anthropic) | Step-by-step guide with explained code for the CPU opponent, written from my decisions | |
| `docs/collision_guide.md` | Claude Code (Anthropic) | Step-by-step guide with explained code for hit detection, damage, knockback angles and hitstun, written from my decisions | |
| `docs/sprite_spec.md` | Claude Code (Anthropic) | Sprite spec (canvas, feet line, files, animation list, draw order), written from my decisions | Changed the file naming to `<character>_<animation>.png` |
| `repo.md` | Claude Code (Anthropic) | Reformatted file listing into a code block so line breaks render | Wrote/edited the file descriptions |

Design decisions (characters, openers, controls, which moves are core) are
mine; the AI wrote code to implement them. AI use was approved by the
professor.

## Code

Any code copied or adapted from somewhere other than an LLM (tutorials,
examples, templates), with the link.

None so far.

## Original work (made by me)

| file | what |
|---|---|
| `data/stages/main.json` | stage data, written by me |
| `src/stage.odin` → `load_stage` | typed by me from an AI-provided, line-by-line explained example |
| `src/combat.odin` | hit detection and hit response, typed by me from an AI-provided, line-by-line explained example (`docs/collision_guide.md`); the opener code was written by Claude Code (see the AI table) |
| `src/cpu.odin` | CPU opponent (state machine, steering, waypoints, reaction delay), typed by me from an AI-provided, line-by-line explained example (`docs/cpu_guide.md`); one line changed by Claude Code so a stunned CPU waits like in hitstun |
| `data/characters/david.json` | David's stats and Slow moves, my design; knockback values and angles (starting values suggested by Claude Code); after playtesting, side strong and double jump retuned by Claude Code from kill-percentage tests |
| `assets/sprites/placeholder/hero.png` | placeholder fighter sprite, drawn by me |
| `assets/sprites/lucy/lucy_idle.png` | Lucy’s idle (2 frames), drawn by me. Character design is my own, inspired by Cyberpunk: Edgerunners (CD Projekt / Studio Trigger). Colours picked from cyberpunk palettes suggested by Claude Code (Anthropic) |
| `assets/sprites/lucy/lucy_walk.png` | Lucy’s walk (2 frames), drawn by me |
| `assets/sprites/lucy/lucy_run.png` | Lucy’s run (4 frames), drawn by me. Run style inspired by “Stickman Naruto Run Animation drawing practice #ninjarun” by ALKDR Animations, https://youtu.be/gFIHhML5BPA |
| `assets/sprites/lucy/lucy_jump_squat.png` | Lucy’s jump squat / landing (1 frame), drawn by me |
| `assets/sprites/lucy/lucy_jump_rise.png` | Lucy’s jump rise (1 frame), drawn by me |
| `assets/sprites/lucy/lucy_jump_fall.png` | Lucy’s jump fall (1 frame), drawn by me |

## Other

`CLAUDE.md` (instructions for the AI assistant): the first paragraph is a
prompt from a post I saw on Instagram (original author unknown); the last
line is mine.
