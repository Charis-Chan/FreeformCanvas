# Openers Guide: Stun and Slow on hit

Lucy's moves marked `"opener": "Stun"` freeze the opponent. David's moves
marked `"opener": "Slow"` put the opponent in slow motion. This is the code
that makes them happen on hit.

**Claude Code wrote this code directly into the repo (Nov 26).** The parts
below explain each change, in an order where the game builds after every
part.

## How they work (decided Nov 26)

**Stun (Lucy)**
- A stun hit freezes the victim exactly where they were hit, in the air too,
  for **1 s**. No movement, no falling, no control. They vibrate so it's
  obvious, and the HUD says STUNNED.
- Another **stun** hit while frozen restarts the 1 s. A hit **without** stun
  doesn't restart it.
- Every hit taken while frozen does its damage straight away, but its launch
  is saved. When the stun ends, the victim is launched **once**:
  - as hard as the **last** hit taken while frozen
  - in the **average direction** of all the hits taken while frozen
- At most **5 stuns in one combo**. After the 5th, a **1 s cooldown** during
  which stun moves hit normally. A combo ends once the victim has been free
  for half a second.

**Slow (David)**
- A slow hit puts the victim at **half speed** for **5 s**. More slow hits
  don't refresh it. Then a **3 s cooldown** before it can be applied again.
- The 5 s are real seconds, not slowed ones.
- The slowed fighter is tinted blue, and a small clock next to their tag
  empties as the slow runs out (like Bayonetta's Witch Time). The HUD shows
  the seconds left.

Every number is in `data/rules.json`, so F5 retunes them.

The F1 debug key (toggle Slow on P2) is removed: Slow now comes from David's
hits.

## What I tested

- **Stun:** a jab stuns for exactly 60 ticks. The victim doesn't move at all,
  on the ground or in the air, and vibrates ±3 px every 2 ticks. It's then
  launched in the jab's direction with the jab's knockback.
- **Restarting:** a second stun hit restarts the timer, and a forward air
  (no opener) doesn't.
- **Launch:** the launch uses the last hit's knockback. Two 30° hits from
  opposite sides launch straight up.
- **The cap:** the 5th stun starts the cooldown, a 6th stun move in the same
  combo hits normally, and stun works again once the combo and cooldown are
  over.
- **Slow:** a jab slows to half speed for 300 ticks, and another slow hit
  doesn't refresh it. It ends after 5 real seconds, then can't be reapplied
  for 3 s, then can.
- **Respawning** clears both.
- **The CPU** gets stunned and recovers normally afterwards (it treats stun
  like hitstun). It slows you with its own hits, and never fell off in six
  30-second test matches.

| Part | What | Builds after? |
|---|---|---|
| 1 | New rules (`data.odin`, `rules.json`) | Yes |
| 2 | Fighter fields | Yes |
| 3 | Applying Stun and Slow, the Stunned state, my `render.odin`, one CPU line | Yes, once the whole part is in |
| 4 | Timers and respawn | Yes, and openers work fully from here |
| 5 | Remove F1 from `game.odin` | Yes |
| 6 | Test | |

---

## Part 1: the rules

### `src/data.odin`, in `Rules`

Add under `knockback_friction`:

```odin
	// Stun (Lucy's opener)
	stun_ticks:          int, // how long a stun hit freezes the victim
	stun_max_per_combo:  int, // stun hits allowed in one combo
	stun_cooldown_ticks: int, // after the last allowed stun, how long until stun works again
	combo_reset_ticks:   int, // a combo ends after the victim is free this long

	// Slow (David's opener)
	slow_scale:          f32, // victim's speed while slowed (0.5 = half speed)
	slow_ticks:          int, // how long Slow lasts
	slow_cooldown_ticks: int, // after Slow ends, how long until it can be applied again
```

### `src/data.odin`, in `load_rules`

Add after the `hitstun_per_knockback` check, before `return rules, true`:

```odin
	if rules.stun_ticks <= 0 || rules.stun_max_per_combo <= 0 || rules.combo_reset_ticks <= 0 || rules.slow_ticks <= 0 {
		fmt.eprintln(path, "- stun_ticks, stun_max_per_combo, combo_reset_ticks and slow_ticks must be above 0 (misspelled key?)")
		return
	}
	if rules.slow_scale <= 0 || rules.slow_scale > 1 {
		fmt.eprintln(path, "- slow_scale must be above 0 and at most 1 (misspelled key?)")
		return
	}
```

These are the same "misspelled key" safety checks as before. A misspelled key
loads as 0, and a 0-tick stun or 0× speed would break the game in confusing
ways.

### `data/rules.json`

Add these after `knockback_friction`:

```json
	// Stun (Lucy's opener). 60 ticks = 1 second.
	"stun_ticks": 60,          // how long a stun hit freezes the victim
	"stun_max_per_combo": 5,   // stun hits allowed in one combo
	"stun_cooldown_ticks": 60, // after the last allowed stun, how long until stun works again
	"combo_reset_ticks": 30,   // a combo ends once the victim has been free this long

	// Slow (David's opener)
	"slow_scale": 0.5,          // victim's speed while slowed (0.5 = half speed)
	"slow_ticks": 300,          // how long Slow lasts (5 s)
	"slow_cooldown_ticks": 180, // after Slow ends, how long until it can be applied again (3 s)
```

**Build.** Nothing changes in game yet.

---

## Part 2: fighter fields (`src/fighter.odin`)

### `src/fighter.odin`, in `Fighter`

Add under `hitstun_left: int,`:

```odin
	// Stun (Lucy's opener). While stunned, hits don't launch: their launch
	// directions are added up here, and the last hit's knockback is kept.
	// When the stun ends, the fighter is launched once with that knockback
	// in the average of those directions.
	stun_left:        int,  // ticks of stun remaining
	stun_dir_total:   Vec2, // sum of the saved launch directions
	stun_last_dir:    Vec2, // used if the saved directions cancel out
	stun_knockback:   f32,  // knockback of the last hit taken while stunned
	stuns_this_combo: int,  // stun hits taken in the current combo
	stun_cooldown:    int,  // ticks until this fighter can be stunned again
	free_ticks:       int,  // ticks since last in hitstun or stun (ends a combo)

	// Slow (David's opener), counted in real game ticks, not slowed ones.
	slow_left:     int, // ticks of slow remaining
	slow_cooldown: int, // ticks until this fighter can be slowed again
```

- **Stun state lives on the victim**, not the attacker: it's the victim who
  is frozen, who has a combo count, and who has a cooldown.
- `stun_dir_total` adds up one **direction** per hit. A direction is an arrow
  of length 1, so adding them and then scaling the result back to length 1
  gives the average direction (Part 3).
- `stun_last_dir`: if two hits point exactly opposite ways, they add up to
  nothing, so the last hit's direction is used instead.
- `free_ticks`: how long since the fighter was last hit. Once it reaches
  `combo_reset_ticks`, the combo is over.

**Build.** Nothing changes in game yet.

---

## Part 3: applying Stun and Slow, the Stunned state, and my render file

**This part only builds once all of it is in.** Adding `Stunned` to the
state list means every `switch` on the state must handle it (the one in
`fighter_step` and the one in `render.odin`), and the combat code uses it.
So type it all, then build.

### `src/combat.odin`

Add this import under `import "core:math"`:

```odin
import "core:math/linalg"
```

`linalg` is Odin's vector maths package. It's used for `linalg.length`, the
length of a vector.

### Replace `apply_hit`

```odin
apply_hit :: proc(attacker, victim: ^Fighter) {
	a := attacker.character.moves[attacker.move]
	rules := attacker.rules
	attacker.hit_landed = true // each attack hits once

	victim.damage += a.damage

	// Knockback grows with the victim's damage (counted after this hit).
	// knockback_growth is the extra speed added per 100%.
	knockback := a.base_knockback + a.knockback_growth * victim.damage / 100

	// The angle is in degrees: 0 = straight forward (the way the attacker
	// faces), 90 = straight up, -90 = straight down. Screen y points down,
	// so the y part is negated.
	radians := a.angle * math.RAD_PER_DEG
	direction := Vec2{math.cos(radians) * attacker.facing, -math.sin(radians)}

	stuns := a.opener == .Stun && can_be_stunned(victim^)
	if stuns || victim.state == .Stunned {
		// Frozen: save this hit's launch for when the stun ends.
		if victim.state != .Stunned do victim.stun_dir_total = {}
		victim.stun_dir_total += direction
		victim.stun_last_dir = direction
		victim.stun_knockback = knockback // only the last hit's strength counts
		if stuns {
			// A stun hit (re)starts the stun; other hits don't.
			victim.stun_left = rules.stun_ticks
			victim.stuns_this_combo += 1
			if victim.stuns_this_combo >= rules.stun_max_per_combo {
				victim.stun_cooldown = rules.stun_cooldown_ticks
			}
		}
		victim.vel = {}
		set_state(victim, .Stunned)
	} else {
		victim.vel = direction * knockback
		victim.hitstun_left = int(knockback * rules.hitstun_per_knockback)
		set_state(victim, .Hitstun)
	}

	if a.opener == .Slow && victim.slow_left == 0 && victim.slow_cooldown == 0 {
		victim.slow_left = rules.slow_ticks
		victim.time_scale = rules.slow_scale
	}

	victim.events += {.Hit}
}
```

What changed from the collision version:

- `rules := attacker.rules`: a short name, since it's used a lot.
- **`direction`** is split out from the velocity. Before, the velocity was
  built in one go as `direction × knockback`. Now the direction on its own is
  needed, because a stunned victim saves it instead of being launched.
- `stuns`: true if this move stuns **and** the victim can be stunned right
  now (under the cap, not in cooldown). `victim^` passes the fighter itself
  (a copy) rather than the pointer.
- **`if stuns || victim.state == .Stunned`**: freeze if this hit stuns, **or**
  if the victim is already frozen. That's how a non-stun hit on a frozen
  victim gets saved too.
  - `if victim.state != .Stunned do victim.stun_dir_total = {}`: a brand-new
    stun starts the saved directions from nothing, so an old stun's hits
    never leak into this one.
  - `+= direction`: adds this hit's direction to the total.
  - `stun_knockback = knockback`: **replaces** the saved strength, so only
    the last hit's counts.
  - `if stuns { ... }`: only a stun hit restarts the timer and counts toward
    the 5. On the 5th, the cooldown is set (it starts counting once the stun
    is over; see `update_opener_timers` below).
  - `victim.vel = {}` and `.Stunned`: frozen from this tick.
- `else`: a normal hit, exactly as before.
- **Slow:** applied only if the victim isn't already slowed (`slow_left ==
  0`, so no refresh) and isn't in the cooldown. Setting `time_scale` is the
  same thing F1 used to do; the timer is what turns it back off.
- Slow is checked separately from stun, so a hit can stun and slow at once.
  No move does both right now.

### Add these three procedures below `apply_hit`

```odin
// Stun only works up to stun_max_per_combo times in one combo, and not
// during the cooldown after that.
can_be_stunned :: proc(f: Fighter) -> bool {
	return f.stuns_this_combo < f.rules.stun_max_per_combo && f.stun_cooldown == 0
}

// The stun has run out: launch once, as hard as the last hit, in the
// average direction of every hit taken while stunned.
launch_after_stun :: proc(f: ^Fighter) {
	direction := f.stun_last_dir
	if length := linalg.length(f.stun_dir_total); length > 0.01 {
		direction = f.stun_dir_total / length
	}
	f.vel = direction * f.stun_knockback
	f.hitstun_left = int(f.stun_knockback * f.rules.hitstun_per_knockback)
	set_state(f, .Hitstun)
}

// Called once per game tick (real time, even for a slowed fighter).
update_opener_timers :: proc(f: ^Fighter) {
	// Slow runs out, then can't be applied again until its cooldown ends.
	if f.slow_left > 0 {
		f.slow_left -= 1
		if f.slow_left == 0 {
			f.time_scale = 1
			f.slow_cooldown = f.rules.slow_cooldown_ticks
		}
	} else if f.slow_cooldown > 0 {
		f.slow_cooldown -= 1
	}

	// A combo ends once the fighter has been free for combo_reset_ticks.
	in_combo := f.state == .Hitstun || f.state == .Stunned
	if in_combo {
		f.free_ticks = 0
	} else {
		f.free_ticks += 1
		if f.free_ticks >= f.rules.combo_reset_ticks do f.stuns_this_combo = 0
	}
	// The stun cooldown starts once the last stun is over.
	if f.stun_cooldown > 0 && f.state != .Stunned do f.stun_cooldown -= 1
}
```

**`launch_after_stun`, the averaging:**
- `linalg.length(f.stun_dir_total)`: how long the summed arrow is. Two hits
  pointing the same way give length 2, opposite ways give 0, and at right
  angles about 1.41.
- `f.stun_dir_total / length`: divides the arrow by its own length, so it's
  length 1 again but pointing the average way. This is why directions are
  added and not angle numbers: 30° from the left and 30° from the right are
  opposite sides, and their arrows correctly average to straight up.
- `length > 0.01`: if the hits cancelled out (length about 0), dividing by
  it would explode, so the last hit's direction is kept instead.
- Then it's an ordinary launch: velocity, hitstun from that knockback, and
  `.Hitstun`.

**`update_opener_timers`:**
- It runs once per **game tick**, not per fighter step (Part 4 calls it from
  `fighter_update`). A half-speed fighter only steps every other tick, so if
  Slow counted steps it would last 10 s instead of 5.
- **Slow:** counts down. When it hits 0, normal speed comes back and the
  cooldown starts. `else if`: the cooldown only counts once the slow is over.
- **Combo:** being in hitstun or stun resets `free_ticks`. Otherwise it
  counts up, and after `combo_reset_ticks` (half a second) the combo count
  goes back to 0.
- **Stun cooldown:** only counts down when not frozen, so the 1 s starts
  after the 5th stun ends, not while it's still running.

### `src/fighter.odin`, in `Fighter_State`

Add the last line:

```odin
	Hitstun, // knocked back, can't act until hitstun_left runs out
	Stunned, // frozen in place by a Stun hit until stun_left runs out
```

### In `fighter_step`, after the `case .Hitstun:` block

```odin
	case .Stunned:
		// Frozen exactly where it was hit: no movement, no gravity.
		f.vel = {}
		f.stun_left -= 1
		if f.stun_left <= 0 do launch_after_stun(f)
```

### In `fighter_step`, the physics `if`

Change it to skip gravity while stunned:

```odin
	// Physics. Dashes ignore gravity for their duration; stunned fighters
	// are frozen.
	if f.state != .Dash && f.state != .Stunned {
```

- With velocity 0 and no gravity, the `f.pos += f.vel` that follows moves
  nothing, so a stunned fighter stays exactly where it was hit, even in
  mid-air.
- Input is never read in the `.Stunned` case, so there's no control either.
- On the tick the stun runs out, `launch_after_stun` switches to `.Hitstun`
  with a launch velocity. The physics then runs normally on that same tick,
  so the launch starts straight away.

### Replace `src/render.odin` with my file

Drawing only, written by me like the earlier render changes:
- `stunned` added to the state labels, and the `Stunned` animation (falls
  back to the placeholder until Art draws `lucy_stunned.png` /
  `david_stunned.png`)
- the vibration: the sprite is drawn ±3 px left and right every 2 ticks while
  stunned. Only the drawing moves; the real position stays frozen.
- the blue tint and the slow clock (`rl.DrawCircleSector`, a pie slice that
  shrinks from full to empty)
- STUNNED and "SLOWED 3.8s" in the HUD
- F1 removed from the help line

It's your pushed `render.odin` with only these changes. If you've edited it
since your last push, tell me before replacing it.

### `src/cpu.odin`, in `cpu_think`

The first check becomes:

```odin
	// Getting hit (or stunned) overrides everything.
	if me.state == .Hitstun || me.state == .Stunned {
```

A stunned CPU has no control, exactly like hitstun, so it uses the same
state.

**Build. Stun works from here.** Slow applies too, but it won't wear off until Part 4 adds the timers.

---

## Part 4: timers and respawn (`src/fighter.odin`)

### In `fighter_respawn`

Add before `set_state(f, .Airborne)`:

```odin
	// A new stock starts with no openers on it.
	f.stun_left = 0
	f.stuns_this_combo = 0
	f.stun_cooldown = 0
	f.slow_left = 0
	f.slow_cooldown = 0
	f.time_scale = 1
```

### In `fighter_update`

Add the timers as the first line:

```odin
fighter_update :: proc(f: ^Fighter, input: Input, stage: Stage) {
	update_opener_timers(f)
	f.held_since_step += input - DIRECTIONS
```

**Build. Stun and Slow both work fully from here.**

---

## Part 5: remove F1 (`src/game.odin`)

Delete:
- the line `prev_debug:   bool,` in the `Game` struct
- the whole `// DEBUG: toggle Slow on player 2 ...` block at the start of
  `match_update` (from that comment down to `g.prev_debug = debug`)

**Build.**

---

## Part 6: test

Keep F2 on.

1. **Stun:** as Lucy, jab David. He freezes where he was hit, vibrates, his
   label says `stunned`, and the HUD says STUNNED. After 1 s he's launched.
2. **Mid-air:** jab or up-air him while he's in the air. He freezes in the
   air and doesn't fall.
3. **Restarting:** jab, then jab again before 1 s is up: the freeze starts
   over. Jab, then forward air (no stun): it doesn't start over.
4. **Launch:** jab, then side strong while he's frozen: when the stun ends,
   he flies as hard as the side strong. Side strong, then jab: he flies as
   weakly as the jab.
5. **The cap:** keep stunning in one combo. The 6th stun move hits normally,
   then stun works again a little after the combo ends.
6. **Slow:** as David (VERSUS, player 2), jab Lucy. She's tinted blue, the
   clock next to her tag empties over 5 s, and she plays at half speed. A
   second slow hit doesn't refill the clock. Right after it ends, she can't
   be slowed for 3 s.
7. **VS CPU:** the CPU slows you with its jab, neutral special and up air.
   When you stun it, it stays frozen, then recovers normally.
8. **KO:** lose a stock while stunned or slowed (or at least once with
   either): you respawn with neither.
9. **F5:** change `stun_ticks` to 30 in `rules.json` and press F5. Stuns get
   noticeably shorter.

## Attribution

- Original work: the opener code in `src/combat.odin` (`apply_hit` changes,
  `can_be_stunned`, `launch_after_stun`, `update_opener_timers`), typed by me
  from an AI-provided, line-by-line explained example
  (`docs/openers_guide.md`).
- AI table:
  - `docs/openers_guide.md` (Claude Code, written from my decisions)
  - `src/render.odin`: add "stun vibration and HUD, slow tint and clock"
  - `src/fighter.odin`, `src/data.odin`, `src/cpu.odin`, `src/game.odin`:
    add "openers: Stunned state, opener timers, new rules, F1 removed",
    typed by me from the guide
