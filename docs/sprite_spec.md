# Sprite Spec

Rules every character sprite follows, so art drops into the game without
code changes. Decide before drawing; changing these later means redrawing.

## Tools

Either **Pixelorama** (PC, iPad as drawing tablet) or **Pixel Art Studio**
(iPad). Both are fine as long as the exported file follows this spec. Before
drawing anything real, do a **test export** with 2 blank frames and check you
get one PNG at 1x with the frames side by side. If an app can only export
frames as separate PNGs, export them that way and tell Claude, so the loader
can be changed to match instead of you stitching files by hand.

Pick one app per animation: switching mid-animation risks mismatched canvas
size or palette.

## Canvas

| Setting | Value | Why |
|---|---|---|
| Frame size | **64 x 64** px | Fits every current move: up aerial reaches 45 art px above the feet, down aerial 15 below |
| In-game scale | **3x** (each art pixel = 3x3 screen pixels) | Character ~30 px tall = fewer pixels to draw per frame |
| Character size (idle) | about **16 wide x 30 tall** art px | Matches the 50 x 90 body box (hurtbox) / 3 (16.7 rounded down so it centres on the canvas) |
| Feet line | lowest foot pixel on **row 51** (rows counted 0 at the top) | Leaves rows 52-63 for down-aerial legs and effects |
| Horizontal centre | between **columns 31 and 32** (columns counted 0 at the left) | Body box: columns 24-39, rows 22-51: 8 columns each side of the centre, so mirroring for left-facing doesn't shift the body |
| Facing | **right** | Code mirrors it for left |
| Background | transparent | |

**Tip:** in either app, make a guide layer with the body box (columns 24-39,
rows 22-51) and a line on row 51. Hide it before exporting. Keep the idle
pose inside the box; attacks can reach out of it.

Only the forward aerial's hitbox reaches past the canvas edge (by ~6 art px).
That's fine: a hitbox may extend beyond the art (a swipe effect), or the
hitbox can be shortened in data.

## Files

- One PNG **per animation**, frames side by side in **one row**, left to right.
- Exported at **1x** (the game scales it), no gaps or padding between frames.
- Path: `assets/sprites/<character>/<animation>.png`, e.g. `assets/sprites/lucy/run.png`
- Lucy and David each get their own folder. Draw in full colour.
- Frame timing (how many game ticks each frame shows) goes in the character
  data file, not the art, so it can be tuned with F5.

## Animations

Frame counts are art frames, not game ticks. A 3-frame jab still lasts
17 ticks in game; each art frame is just held for several ticks.
For attacks, split frames as: wind-up (startup) / hit pose (active) / return (recovery).

| Animation | Minimum | Full | Notes |
|---|---|---|---|
| idle | 2 | 4 | looping breathing |
| walk | 2 | 4 | loop |
| run | 2 | 4 | loop |
| run_turnaround | 1 | 2 | skid; also used for reverse aerial rushes |
| jump_squat | 1 | 1 | crouch before leaving the ground; **reused as landing** |
| jump_rise | 1 | 1 | going up (first and short hop) |
| jump_fall | 1 | 1 | coming down |
| double_jump | 1 | 2 | flip/kick; minimum can reuse jump_rise |
| dash | 1 | 2 | ground dash; **reused for air dash** |
| shield | 1 | 1 | |
| jab | 2 | 3 | startup / active / recovery |
| side_strong | 3 | 4 | the wind-up matters: it's 15 ticks |
| neutral_special | 3 | 4 | |
| forward_aerial | 2 | 3 | |
| up_aerial | 2 | 3 | |
| down_aerial | 2 | 3 | uses the space below the feet line |
| hitstun | 1 | 2 | being hit |
| stunned | 1 | 2 | dizzy loop (being hit by Lucy's stun) |
| **Total per character** | **28** | **46** | x2 characters = **56 / 92 frames** |

Not needed: KO (fighter leaves the screen), slowed (the whole fighter runs at
half speed, no special pose), landing (reuses jump_squat), air dash (reuses dash).

## Draw order

Draw in this order so the most-seen states get art first. Anything not drawn
yet falls back to the placeholder.

1. idle -> run -> jump_rise / jump_fall -> jab -> forward_aerial -> hitstun
2. walk, jump_squat, dash, shield, the other attacks
3. run_turnaround, double_jump, stunned
4. Upgrade minimum animations to full

## Before drawing everything

1. Draw **Lucy's idle (minimum, 2 frames)** and **time it**, from first
   pixel to exported PNG.
2. Multiply: (time per frame) x 56 = minimum art budget for both characters.
3. If that doesn't fit before Nov 9 (content week) alongside coding, cut to
   minimum frames everywhere, or share more poses between Lucy and David.
