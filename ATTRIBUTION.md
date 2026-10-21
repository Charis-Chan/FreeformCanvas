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
| `src/game.odin` | Claude Code (Anthropic) | CP2 skeleton: Title / Match / Results game states; CP3: loads data files at startup, F5 reload of all data; F2 debug box toggle | |
| `src/fighter.odin` | Claude Code (Anthropic) | Fighter entity as data (stats, moves, input), movement (walk, run, jump, double jump, ground/air dash), ground vs air attack selection, per-fighter time scale for Slow, air facing lock, held-direction air dash, B-reverse; CP3: reads stats/moves/rules from loaded data, sound events | Added a Down_Aerial (move, frame data, hitbox, selection); retuned Side_Strong, Neutral_Special frame data and Forward_Aerial hitbox; added hitbox explanation comment; changed the B_REVERSE_WINDOW (4->5) |
| `src/stage.odin` | Claude Code (Anthropic) | Stage and platform structs | `load_stage` is mine (see Original work) |
| `src/render.odin` | Claude Code (Anthropic) | All drawing, separate from game logic; CP3: loaded font, character names, F5 reload message; sprite drawing (feet anchored, mirrored by facing, tinted per player) | Added a Down_Aerial label |
| `src/data.odin` | Claude Code (Anthropic) | CP3: loads rules and characters from JSON, error messages with line numbers | |
| `src/assets.odin` | Claude Code (Anthropic) | CP3: Assets struct (font + sounds) loaded once, shared, unloaded once; audio pass; shared fighter sprite | Changed sound paths to .ogg |
| `data/rules.json`, `data/characters/lucy.json` | Claude Code (Anthropic) | CP3: values moved from code into data files | Chose which moves stun; retuned Lucy's run_speed (8.5 -> 10) and air_speed (4.5 -> 5.5) |
| `docs/scope.md` | Claude Code (Anthropic) | Core / polish / stretch scope table from my design decisions | Rewrote anti-infinite wording; moved down aerial to Core, added back aerial to Stretch; maintain the Changes log |
| `docs/tasks.md` | Claude Code (Anthropic) | CP3 task list with owners | Keep the status column updated |
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
| `data/characters/david.json` | David's stats and Slow moves, my design |
| `assets/sprites/placeholder/hero.png` | placeholder fighter sprite, drawn by me |
| `assets/sprites/lucy/idle.png`     | Lucy’s idle (2 frames), drawn by me. Character design is my own, inspired by Cyberpunk: Edgerunners (CD Projekt / Studio Trigger). Colours picked from cyberpunk palettes suggested by Claude Code (Anthropic) |

## Other

`CLAUDE.md` (instructions for the AI assistant): the first paragraph is a
prompt from a post I saw on Instagram (original author unknown); the last
line is mine.
