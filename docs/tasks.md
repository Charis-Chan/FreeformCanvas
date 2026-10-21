# CP3 Tasks

CP3 (Oct 19): resources loaded once and shared, tuning and level data in
files (not literals), attribution complete.

| # | Owner | Task | Status |
|---|---|---|---|
| 1 | Me | Stage data file (`data/stages/main.json`) | Done |
| 2 | Me | `load_stage` in `src/stage.odin` | Done (typed from explained example) |
| 3 | Me | `data/characters/lucy.json` and `david.json`, incl. which moves stun/slow | Done |
| 4 | Me | Find sounds + a font (CC0/OFL), add attribution rows | Done |
| 5 | Me | Sprite pipeline decisions + Lucy's idle animation (timed) | Not started |
| 6 | Claude | Character loader + `data/rules.json` loader | Done, handed over |
| 7 | Claude | F5 reload of data files | Done, handed over |
| 8 | Claude | `Assets` struct: load once, share, unload once (font + sounds) | Done, handed over |
| 9 | Claude | Code that displays sprites in `render.odin` | Done Oct 21 (per-animation files, timing from data) |
| 10 | Claude | Review everything I push | Ongoing |

Character code names: `lucy` (Stun), `david` (Slow, applied on hit).

## Code backlog (after collision, Oct 26)

| # | Task | Priority | Notes |
|---|---|---|---|
| B1 | P1/P2 tag above each fighter's head, always visible, in player colour | Low | Done Oct 21; debug state label moved under the feet (F2) |
| B2 | Draw colour art untinted. Mirror matches: light near-white tint on P2 only if playtesting shows it's needed | Lowest | Untinted art done Oct 21; mirror tint not started |
| B3 | Per-animation sprite files per character, frame timing from character data | Done Oct 21 | `"animations"` block in the character file, F5 reloadable |
| B4 | Run-turnaround, dash dancing, jump squat + short hop, reverse aerial rush | After collision | Locked in `docs/scope.md` (Oct 19) |
