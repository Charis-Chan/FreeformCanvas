# Attribution

| asset (file) | source (URL) | author | licence | changes you made |
|---|---|---|---|---|
| raylib (library, via Odin `vendor:raylib`) | https://www.raylib.com | Ramon Santamaria (raysan5) and contributors | zlib | none |
| raylib default font (used for all on-screen text) | https://www.raylib.com | Ramon Santamaria (raysan5) and contributors | zlib | none |

## AI-generated assets

| asset (file) | tool + model | prompt (short) | hand edits |
|---|---|---|---|
| `src/main.odin` | Claude Code (Anthropic) | CP2 skeleton: fixed-timestep loop with update/render split | |
| `src/game.odin` | Claude Code (Anthropic) | CP2 skeleton: Title / Match / Results game states | |
| `src/fighter.odin` | Claude Code (Anthropic) | Fighter entity as data (stats, moves, input), movement (walk, run, jump, double jump, ground/air dash), ground vs air attack selection, per-fighter time scale for Slow, air facing lock, held-direction air dash, B-reverse | Added a Down_Aerial (move, frame data, hitbox, selection); retuned Side_Strong, Neutral_Special frame data and Forward_Aerial hitbox; added hitbox explanation comment; changed the B_REVERSE_WINDOW (4->5) |
| `src/stage.odin` | Claude Code (Anthropic) | Stage and platform data | |
| `src/render.odin` | Claude Code (Anthropic) | All drawing, separate from game logic | Added a Down_Aerial label |
| `src/data.odin` | Claude Code (Anthropic) | CP3: loads rules and characters from JSON, error messages with line numbers | |
| `src/assets.odin` | Claude Code (Anthropic) | CP3: Assets struct (font + sounds) loaded once, shared, unloaded once; audio pass | |
| `data/rules.json`, `data/characters/lucy.json` | Claude Code (Anthropic) | CP3: values moved from code into data files | Chose which moves stun |
| `docs/scope.md` | Claude Code (Anthropic) | Core / polish / stretch scope table from my design decisions | Rewrote anti-infinite wording; moved down aerial to Core, added back aerial to Stretch; maintain the Changes log |
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

## Other

`CLAUDE.md` (instructions for the AI assistant): the first paragraph is a
prompt from a post I saw on Instagram (original author unknown); the last
line is mine.
