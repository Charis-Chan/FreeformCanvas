# Repository Structure and Files
assets/             - anything to load (art, sounds, fonts)
data/               - tuning values, level data
docs/               - documentation for the game
- gdd.md            - game design document
- postmortem.md     - 
- scope.md          - locked scope (core / polish / stretch) and controls
src/                - the game
- fighter.odin      - fighter entity: input, stats, moves/hitboxes, movement and attack state machine
- game.odin         - Game struct, game states (Title, Match, Results) and switching between them
- main.odin         - entry point: window setup and the fixed 60 Hz loop (update, then render)
- render.odin       - all drawing; reads the game state, never changes it
- stage.odin        - stage data: platforms, blast zone, spawn points

ATTRIBUTION.md      - AI use and third-party assets; original assets should be disclosed here too
README.md           - how to build and run it
CLAUDE.md           - Instructions file for Claude
repo.md             - repository structure and what each file is for