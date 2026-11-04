# CPU Guide (CP4)

You type `src/cpu.odin`, the state machine and movement the CP4 marks are
for. I've written the plumbing (the title menu, loading `data/cpu.json`, and
hooking the CPU into player 2), which you drop in as finished files.

All of this is code I've built and tested in my copy. At normal speed and
slowed, the CPU approaches and hits a standing player, recovers from both
sides of the stage (including from low), climbs via a middle platform to
fight you on the top one, backs off sometimes, never walks off a platform's
edge, and attacks the right way. It fell off 0 times in 20 fifteen-second
matches.

**Read `docs/cpu.md` first.** It has the states, the transitions, and why the
movement works the way it does. This guide is the code.

## If you already typed the first version

The first version delayed the CPU's **button presses**. Testing at the ledge,
in slow motion and on platforms showed that this caused a whole family of
bugs: it overshot edges, wasted its double jump, recovered too late and
attacked the wrong way. This version delays what the CPU **sees** instead.
That's simpler, and it removes `predict` and the press-wait bookkeeping.

Changes from the first version:

| Where | Change |
|---|---|
| `fighter.odin` | Part 0 (new): buttons pressed on ticks a slowed fighter skips are kept |
| `Cpu_Config` | Only the comment on `reaction_ticks` |
| `Cpu` struct | `press_wait` becomes `last`. Add `target`, `target_is_opp` and `attack_dirs`. `history` becomes `seen` |
| `on_main_platform` | Replaced by `platform_under` |
| `is_off_stage` | First line: `if me.grounded do return false` |
| `steer` | Uses `platform_under`. No `config` parameter |
| `press` | Back to "not held last tick" |
| `predict` | **Delete it** |
| `jump_reach` | Counts only the lift it has left |
| `waypoint` | Also returns whether the target is the opponent |
| `cpu_think` | Approach, Attack and Recover all change (see Part 3) |
| `cpu_update` | Rewritten (Part 4) |

Comparing line by line is slower than retyping the changed procedures from
this guide. `cpu_set_state`, `main_platform`, `on_soft_platform`,
`room_ahead`, `choose_attack` and the Retreat state are unchanged.

| Part | What | Builds after? |
|---|---|---|
| 0 | `fighter.odin`: keep presses for slowed fighters | Yes |
| 1 | The types: states, config, the CPU's memory | Yes |
| 2 | Helpers: small questions about the stage, and button pressing | Yes |
| 3 | `cpu_think`: the state machine | Yes |
| 4 | `cpu_update`: the reaction delay | Yes |
| 5 | Drop in my files and `data/cpu.json` | Yes, and the CPU plays from here |
| 6 | Test | |

---

## The one idea to understand first

**The CPU presses buttons. It never moves the fighter.**

Each tick, `cpu_update` returns an `Input`, the same `bit_set[Button]` that
`read_input` fills in from the keyboard. `match_update` then passes it to
`fighter_update`, exactly like a player's input. Because of that, every rule
you've built applies to the CPU for free: frame data, jumps, dashes, hitstun,
knockback and collision.

---

## Part 0: presses on skipped ticks (`src/fighter.odin`)

A slowed fighter only takes a step every other tick, and it only reads input
on ticks it steps. A human holds a key for many ticks, so they never notice.
The CPU presses a button for exactly one tick, so half its presses landed on
skipped ticks and were lost. It switched to ATTACK and nothing came out.

Under `Input :: bit_set[Button]`, add:

```odin
DIRECTIONS :: Input{.Left, .Right, .Up, .Down}
```

In the `Fighter` struct, under `prev_input: Input,`, add:

```odin
	// Every button (not direction) held on any tick since the last step. A
	// slowed fighter skips ticks, so a quick press on a skipped tick would
	// otherwise be lost.
	held_since_step: Input,
```

Replace `fighter_update` with:

```odin
fighter_update :: proc(f: ^Fighter, input: Input, stage: Stage) {
	f.held_since_step += input - DIRECTIONS
	f.time_accum += f.time_scale
	for f.time_accum >= 1 {
		f.time_accum -= 1
		// Buttons: anything pressed since the last step. Directions: only
		// what's held now (Left then Right would otherwise cancel out).
		fighter_step(f, f.held_since_step + input & DIRECTIONS, stage)
		f.held_since_step = {}
	}
}
```

- `input - DIRECTIONS`: the input without the four directions. `-` on bit
  sets removes elements.
- `+=`: collects every button held on any tick since the last step.
- `input & DIRECTIONS`: only the directions held **this** tick. `&` keeps
  what's in both sets. In Odin, `&` happens before `+`, so this reads as
  `held_since_step + (input & DIRECTIONS)`.
- **Why directions are treated differently:** a direction means "where the
  stick is now". If Left on one tick and Right on the next were combined, the
  fighter would see both, they'd cancel out, and it wouldn't turn. That was
  the slowed CPU attacking the wrong way.
- `f.held_since_step = {}`: start collecting again after each step.
- At normal speed there's a step every tick, so this changes nothing for
  players.

**Build.**

---

## Part 1: types (`src/cpu.odin`)

```odin
package main

// The CPU opponent. It doesn't move the fighter itself: each tick it decides
// which buttons to hold and hands back an Input, exactly like a keyboard
// would. So it obeys the same rules as a player (frame data, jumps, dashes,
// hitstun) and gets hit by the same collision.

Cpu_State :: enum {
	Approach, // move toward the opponent
	Attack,   // one attack, chosen for where the opponent is
	Retreat,  // back off for a moment
	Recover,  // off the stage: get back to it
	Hitstun,  // being hit: no control, wait it out
}

// Tuning, loaded from data/cpu.json.
Cpu_Config :: struct {
	reaction_ticks: int, // how late the CPU sees what the opponent does (0 = instantly)
	attack_range:   f32, // horizontal distance at which it starts an attack
	aggression:     f32, // 0..1: chance to keep attacking instead of retreating
	retreat_ticks:  int, // how long a retreat lasts
	dash_distance:  f32, // dash toward the opponent when farther than this
}

MAX_REACTION_TICKS :: 60

Cpu :: struct {
	state:       Cpu_State,
	state_ticks: int, // ticks spent in the current state
	// Buttons it decided last tick (see press).
	last: Input,
	// Where Approach is heading. Chosen on the ground and kept through a
	// jump (a player commits to a jump the same way), except when it's the
	// opponent, who is followed every tick.
	target:        Vec2,
	target_is_opp: bool,

	// The directions of the current attack (e.g. Up for up air, Right to
	// face right). Held for the whole attack, so a slowed fighter that skips
	// a tick still sees them, and B-reverse has time to happen.
	attack_dirs: Input,

	// The reaction delay: what the opponent looked like on each recent
	// tick. The CPU acts on the one from reaction_ticks ago.
	seen: [MAX_REACTION_TICKS + 1]Fighter,
	tick: int,
}

cpu_set_state :: proc(cpu: ^Cpu, state: Cpu_State) {
	if cpu.state != state {
		cpu.state = state
		cpu.state_ticks = 0
	}
}
```

- `Cpu_State` lists the five states: these are the "states you can name" from
  the rubric.
- `Cpu_Config`: every number that tunes the CPU's behaviour. The field names
  must match the keys in `data/cpu.json` (Part 5).
- `MAX_REACTION_TICKS :: 60`: the longest allowed delay, 1 second. `::`
  makes it a constant, which is needed because it sets the size of an array.
- `Cpu` is the CPU's memory between ticks:
  - `state` and `state_ticks` work like the fighter's `state` and
    `state_frame`.
  - `last`: what it pressed last tick, so it can release a button before
    pressing it again (see `press`).
  - `target` and `target_is_opp`: where it's heading, explained in Part 3.
  - `attack_dirs`: explained in Part 3.
  - `seen: [MAX_REACTION_TICKS + 1]Fighter`: a fixed array of 61 copies of
    the opponent, one per recent tick. The reaction delay reads the one from
    `reaction_ticks` ago (Part 4).
  - `tick`: counts every tick since the match started.
- `cpu_set_state` is a copy of the fighter's `set_state`: it only resets the
  timer if the state actually changes.

**Build.**

---

## Part 2: helpers

Add these imports under `package main`:

```odin
import "core:math/rand"
import rl "vendor:raylib"
```

Then add these at the bottom of the file:

```odin
EDGE_MARGIN :: 40 // how far inside the stage's edge counts as safe

// The solid platform everyone fights on (the first one that isn't soft).
main_platform :: proc(stage: Stage) -> rl.Rectangle {
	for p in stage.platforms {
		if !p.soft do return p.rect
	}
	return {}
}

// The platform the fighter is standing on, if any (even with the body
// hanging over its edge).
platform_under :: proc(me: Fighter, stage: Stage) -> (rect: rl.Rectangle, standing: bool) {
	if !me.grounded do return
	half_w := me.character.stats.size.x / 2
	for p in stage.platforms {
		r := p.rect
		if me.pos.y == r.y && me.pos.x + half_w > r.x && me.pos.x - half_w < r.x + r.width {
			return r, true
		}
	}
	return
}

on_soft_platform :: proc(me: Fighter, stage: Stage) -> bool {
	for p in stage.platforms {
		if p.soft && me.grounded && me.pos.y == p.rect.y do return true
	}
	return false
}

// Past the sides of the main stage, or below its top. Standing on anything
// counts as on stage, even with the body hanging over an edge.
is_off_stage :: proc(me: Fighter, stage: Stage) -> bool {
	if me.grounded do return false
	main := main_platform(stage)
	return me.pos.x < main.x || me.pos.x > main.x + main.width || me.pos.y > main.y + 1
}
```

- `main_platform`: the stage file has no "main" flag, so this uses the first
  platform that isn't soft. In `main.json` that's the big one.
- `platform_under`: the same test `land_on_platforms` uses. Feet exactly on
  the top (`land_on_platforms` sets them exactly), and any part of the body
  overlapping it sideways. `(rect, standing)` are named return values, so a
  bare `return` gives `{}, false`.
- `is_off_stage`: anything it's standing on counts as on stage. A fighter
  stays on a platform while any part of its body overlaps it, so it can stand
  with its centre past the edge. Checking only the centre made the CPU flip
  between Recover and Approach every tick and freeze at the ledge (found in
  testing). Remember y grows **downward**, so `>` means lower.

```odin
// Moves in `dir` (+1 right, -1 left), but never walks off the platform it's
// standing on (it leaves a soft platform by dropping through instead).
steer :: proc(me: Fighter, stage: Stage, dir: f32) -> Input {
	if under, standing := platform_under(me, stage); standing {
		if dir > 0 && me.pos.x > under.x + under.width - EDGE_MARGIN do return {}
		if dir < 0 && me.pos.x < under.x + EDGE_MARGIN do return {}
	}
	return {.Right} if dir > 0 else {.Left}
}

// How far the fighter can go in `dir` before the main stage's edge.
room_ahead :: proc(me: Fighter, stage: Stage, dir: f32) -> f32 {
	main := main_platform(stage)
	if dir > 0 do return main.x + main.width - me.pos.x
	return me.pos.x - main.x
}

// Adds `button` only if it wasn't held last tick, so the fighter sees a fresh
// press (fighters react to presses, not to buttons being held).
press :: proc(cpu: ^Cpu, input: ^Input, button: Button) {
	if button not_in cpu.last do input^ += {button}
}
```

- `steer` is the steering: it holds left or right toward a direction. Its
  one rule is edge safety: on any platform, near the edge, it stops instead
  of walking off. Without this it fell off the main stage chasing you, and
  walked off middle platforms before it could jump from them.
- `if under, standing := platform_under(...); standing`: calls it, names
  both results, and only enters if `standing` is true.
- `return {}`: an empty `Input`, meaning "hold nothing".
- `{.Right} if dir > 0 else {.Left}` is Odin's one-line if/else for values.
- `room_ahead` is checked before dashing (12 px a tick for 10 ticks = 120 px)
  so it never dashes off the edge.
- `press`: fighters react to **presses** (`pressed := input - f.prev_input`),
  not held buttons. So to jump twice the CPU has to let go in between, and
  `press` makes sure it does. `input: ^Input` is a pointer, so `press` can
  add to the caller's input: `input^ += {button}` means "add `button` to the
  input that `input` points at".

```odin
// How much higher the fighter can still get from here, with a margin: a
// jump if it's on the ground (or what's left of its rise if it's already
// going up), plus a double jump if it has one left.
// Height of a jump = speed^2 / (2 x gravity).
jump_reach :: proc(me: Fighter) -> f32 {
	s := me.character.stats
	reach: f32
	if me.grounded {
		reach = s.jump_velocity * s.jump_velocity / (2 * s.gravity)
	} else if me.vel.y < 0 {
		reach = me.vel.y * me.vel.y / (2 * s.gravity)
	}
	if me.air_jumps_left > 0 {
		reach += s.double_jump_velocity * s.double_jump_velocity / (2 * s.gravity)
	}
	return reach * 0.9
}
```

- `speed² / (2 × gravity)` is the standard physics formula for how high
  something thrown upward rises before it stops. For David: 13² / 1.5 = 113
  px for the jump, plus 11² / 1.5 = 81 px for the double jump.
- **Only the lift it has left:** in the air, the jump is already used, so
  only the rest of its rise counts (`me.vel.y < 0` means still going up),
  plus the double jump if it hasn't used it. Counting a full jump mid-air
  made it think the top platform was in reach when it wasn't, so it swerved
  off course in testing.
- `* 0.9` keeps a 10% margin so it doesn't try jumps it can only just make.
- It reads the character's stats, so it stays right if you retune jumps.

```odin
// Where to head for. Usually the opponent; but if they're higher than a jump
// and double jump can reach, the platform that gets it closest to them on
// the way up. The stage is a handful of platforms, so this one rule is all
// the pathfinding it needs.
waypoint :: proc(me, opponent: Fighter, stage: Stage) -> (target: Vec2, is_opponent: bool) {
	reach := jump_reach(me)
	if me.pos.y - opponent.pos.y <= reach do return opponent.pos, true

	best := opponent.pos
	best_dist: f32 = max(f32)
	for p in stage.platforms {
		top := p.rect.y
		rise := me.pos.y - top
		// Must be above us, reachable, and below the opponent.
		if rise < 20 || rise > reach || top <= opponent.pos.y do continue
		// The point on this platform closest to the opponent.
		x := clamp(opponent.pos.x, p.rect.x + EDGE_MARGIN, p.rect.x + p.rect.width - EDGE_MARGIN)
		if dist := abs(x - opponent.pos.x); dist < best_dist {
			best_dist = dist
			best = {x, top}
		}
	}
	return best, best == opponent.pos
}
```

This is the "pathfinding". From the ground, the top platform is 270 px up,
more than the 190 px a jump and double jump reach.

- `me.pos.y - opponent.pos.y`: how far above the CPU the opponent is
  (positive = above, because y grows downward). If that's within reach, the
  opponent is the target, and `true` says so.
- Otherwise it looks at every platform and keeps the best one that is:
  - above the CPU (`rise < 20` skips its own platform and anything lower)
  - reachable (`rise > reach` skips ones too high)
  - lower than the opponent (`top <= opponent.pos.y` skips ones at or above
    them)
- Of those, it picks the one whose closest point is nearest the opponent.
- `max(f32)`: the largest possible `f32`, so the first platform checked is
  always "better".
- `clamp(value, low, high)`: `value` limited to between `low` and `high`.
  Here that's the opponent's x, limited to stay on the platform.
- `if dist := ...; dist < best_dist`: declares `dist` and tests it in one
  line.
- `best == opponent.pos` at the end: if no platform qualified, the target is
  still the opponent.

Once the CPU lands on the middle platform, the next `waypoint` sees the
opponent is now in reach and targets them directly. One rule gives the whole
climb.

```odin
// Picks the attack that fits where the opponent is. On the ground the held
// direction turns the fighter to face them first.
choose_attack :: proc(me: Fighter, dx, dy: f32) -> Input {
	toward: Input = {.Right} if dx > 0 else {.Left}
	if me.grounded {
		if abs(dx) < 55 do return toward + {.Attack}         // jab
		if rand.float32() < 0.5 do return toward + {.Strong} // side strong
		return toward + {.Special}                           // neutral special
	}
	if dy < -40 do return {.Up, .Attack}   // up aerial
	if dy > 40 do return {.Down, .Attack}  // down aerial
	facing_them := (dx > 0) == (me.facing > 0)
	if facing_them do return {.Attack}     // forward aerial
	return toward + {.Special}             // behind us: neutral special, B-reversed toward them
}
```

- `dx`, `dy`: where the opponent is relative to the CPU (`dx > 0` is to the
  right, `dy < 0` is above).
- **On the ground:** holding toward the opponent turns the fighter that way
  on the same tick (the `Idle/Walk/Run` case sets `facing` from the held
  direction before starting the attack). Very close gives jab. Otherwise
  it's a coin flip between side strong and neutral special.
  `rand.float32()` is a random number between 0 and 1.
- **In the air:** `select_move` already turns "Up + Attack" into up aerial,
  and so on, so these return the same buttons you'd press.
- `facing_them`: in the air you can't turn around. If the opponent is
  behind it, a forward aerial would miss, so it uses neutral special while
  holding toward them, which is your B-reverse. That's an existing system
  being used on purpose.

**Build.**

---

## Part 3: the state machine

```odin
// The state machine: what to do in each state, and when to switch.
cpu_think :: proc(cpu: ^Cpu, me, opponent: Fighter, stage: Stage, config: Cpu_Config) -> Input {
	// Getting hit overrides everything.
	if me.state == .Hitstun {
		cpu_set_state(cpu, .Hitstun)
		return {}
	}
	if cpu.state != .Recover && is_off_stage(me, stage) {
		cpu_set_state(cpu, .Recover)
	}

	input: Input
	dx := opponent.pos.x - me.pos.x // + = opponent is to the right
	dy := opponent.pos.y - me.pos.y // + = opponent is below

	switch cpu.state {
	case .Hitstun:
		// Hitstun just ended (the check above didn't return).
		cpu_set_state(cpu, .Approach)
```

- `me` is the CPU's fighter, as it is now. `opponent` is yours **as the CPU
  saw it `reaction_ticks` ago** (Part 4). Both are plain values, so the CPU
  can look but not change anything. Only its buttons do that.
- **The two checks before the `switch` are transitions that apply from any
  state:** getting hit goes to Hitstun, and being off the stage goes to
  Recover. Putting them first means no individual state has to remember to
  check them.
- `return {}` in hitstun: you can't act in hitstun anyway, so it holds
  nothing.
- `input: Input` starts empty. Each state adds the buttons it wants.
- `case .Hitstun:` only runs on the first tick after hitstun ends, because
  while it lasts, the check above returns early. If it ended off the stage,
  the Recover check has already switched the state, so this case doesn't
  run.

```odin
	case .Approach:
		in_range := abs(dx) < config.attack_range && dy > -140 && dy < 60
		// Standing on a platform above it: climb up and fight there instead
		// of up-airing through the platform every time.
		if opponent.grounded && dy < -40 do in_range = false
		if in_range {
			attack := choose_attack(me, dx, dy)
			cpu.attack_dirs = attack & DIRECTIONS
			cpu_set_state(cpu, .Attack)
			input += attack
			break
		}
		// Head for the opponent, or for a platform on the way up to them.
		if me.grounded || cpu.target_is_opp || cpu.state_ticks == 0 {
			cpu.target, cpu.target_is_opp = waypoint(me, opponent, stage)
		}
		target := cpu.target
		tx := target.x - me.pos.x
		ty := target.y - me.pos.y // negative = target is above
		toward: f32 = 1 if tx > 0 else -1
		if abs(tx) > 10 do input += steer(me, stage, toward)

		if me.grounded {
			if ty < -40 && abs(tx) < 150 {
				press(cpu, &input, .Jump) // target is above: jump
			} else if dy > 60 && on_soft_platform(me, stage) {
				input += {.Down} // opponent is below: drop through
			} else if abs(dx) > config.dash_distance && me.dash_cooldown == 0 && room_ahead(me, stage, toward) > 200 {
				press(cpu, &input, .Dash) // close the gap
			}
		} else if me.air_jumps_left > 0 {
			// Double jump once it starts falling, if still below the target.
			if me.vel.y > 0 && ty < -40 {
				press(cpu, &input, .Jump)
			}
		}
```

- `in_range`: close enough sideways, and between 140 px above and 60 px
  below.
- **The climbing rule:** if you're *standing* on a platform above it, it
  doesn't count as in range. Without this, it jumped under your platform and
  up-aired through it every single time (19 out of 19 attacks in testing).
  Now it climbs up and fights you there. Up air is still used when you're in
  the air above it.
- **Approach → Attack:** it chooses the attack, remembers its directions
  (`attack & DIRECTIONS`) for the Attack state, presses it on this same tick,
  then `break` leaves the `switch` (in Odin, `break` inside a `case` ends the
  switch).
- **Committing to a jump:** the target is only recalculated on the ground,
  or when the target is you (you move, so it follows you every tick), or on
  the first tick of Approach. Mid-jump it keeps the platform it jumped for.
  When it recalculated mid-air in testing, it changed its mind and missed the
  platform.
- `cpu.target, cpu.target_is_opp = waypoint(...)`: both return values go
  straight into the struct.
- `tx`, `ty`: how far away the target is. `if abs(tx) > 10`: within 10 px it
  stops pushing, so it doesn't jitter left and right on top of its target.
- **On the ground**, at most one of these:
  - target above and close sideways: jump
  - opponent below and standing on a soft platform: hold Down to drop
    through (the same input you use)
  - far away, dash ready, and room before the edge: dash
- **In the air:** double jump once it starts falling (`me.vel.y > 0`), if
  it's still below the target. Waiting until it falls uses the whole first
  jump before the second one.
- `&input`: the address of `input`, because `press` takes a pointer.

```odin
	case .Attack:
		// The attack was pressed on entering this state. Keep facing it, and
		// wait until it has started (a slowed fighter can take a tick or
		// two), then finished.
		input += cpu.attack_dirs
		started := cpu.state_ticks > 2
		if started && me.state != .Attack {
			if rand.float32() < config.aggression {
				cpu_set_state(cpu, .Approach)
			} else {
				cpu_set_state(cpu, .Retreat)
			}
		}

	case .Retreat:
		away: f32 = -1 if dx > 0 else 1
		input += steer(me, stage, away)
		if cpu.state_ticks >= config.retreat_ticks {
			cpu_set_state(cpu, .Approach)
		}
```

- **Attack** keeps holding the attack's directions for the whole attack.
  Two reasons, both found in testing:
  - a slowed fighter only reads directions on ticks it steps (Part 0), so a
    one-tick Up was missed and up air came out as forward air
  - B-reverse checks the held direction during the first few frames of
    neutral special, so it needs the direction still held then
- `started`: a slowed fighter can take a couple of ticks to step and start
  the attack, so the CPU doesn't check `me.state` until then.
- Once the attack is finished, it rolls `aggression`. With 0.6, that's 60%
  Approach (keep pressing you) and 40% Retreat.
- If the attack never came out (for example, it pressed during a dash), the
  fighter isn't in `.Attack` once `started` is true, so it moves on instead
  of getting stuck.
- **Retreat:** steer away from the opponent (still edge-safe), then go back
  to Approach after `retreat_ticks`.

```odin
	case .Recover:
		if me.grounded {
			cpu_set_state(cpu, .Approach)
			break
		}
		main := main_platform(stage)
		// Head for the nearest point just inside the stage's edge. If it's
		// under the stage, go out past the nearest edge first.
		target_x := clamp(me.pos.x, main.x + EDGE_MARGIN, main.x + main.width - EDGE_MARGIN)
		if me.pos.y > main.y && target_x == me.pos.x {
			left_gap := me.pos.x - main.x
			right_gap := main.x + main.width - me.pos.x
			target_x = main.x - EDGE_MARGIN if left_gap < right_gap else main.x + main.width + EDGE_MARGIN
		}
		input += {.Right} if target_x > me.pos.x else {.Left}

		falling := me.vel.y > 0
		gap := abs(target_x - me.pos.x)
		if falling && me.pos.y > main.y - 40 && me.air_jumps_left > 0 {
			press(cpu, &input, .Jump) // about to drop below the stage: double jump
		} else if me.pos.y < main.y - 10 && gap > 40 && me.air_dashes_left > 0 && me.dash_cooldown == 0 {
			press(cpu, &input, .Dash) // still above the stage's top: dash sideways toward it
		}
	}
	return input
}
```

- **Recover → Approach:** landing on anything ends the recovery.
- `target_x`: clamping its own x into the stage gives the nearest safe
  point. If it's already over the stage, that's straight below it.
- **Under the stage:** if it's below the top *and* already between the
  edges (`target_x == me.pos.x`), heading "inward" wouldn't help. It has to
  get back out past the nearest edge first.
- It always holds toward the target: that's steering again.
- **Double jump** when it's falling and about to drop below the stage's top.
- **Air dash** only while it's still *above* the top. Air dashes are
  horizontal, and in testing, dashing from below the top carried it under the
  stage.
- `return input` hands the buttons back to `cpu_update`.

**Build.**

---

## Part 4: the reaction delay

Add this at the bottom of the file (Odin doesn't care about order):

```odin
// Called once per game tick. Returns the buttons the CPU's fighter holds.
cpu_update :: proc(cpu: ^Cpu, me, opponent: Fighter, stage: Stage, config: Cpu_Config) -> Input {
	// Remember the opponent as it is now, and look at it as it was
	// reaction_ticks ago (or as it is now, early in the match).
	size := len(cpu.seen)
	cpu.seen[cpu.tick % size] = opponent
	seen := opponent
	if cpu.tick >= config.reaction_ticks {
		seen = cpu.seen[(cpu.tick - config.reaction_ticks) % size]
	}
	cpu.tick += 1

	input := cpu_think(cpu, me, seen, stage, config)
	cpu.last = input
	cpu.state_ticks += 1
	return input
}
```

**The reaction delay is on what the CPU sees, not on its hands.** It sees
you as you were 0.2 s ago, the way a person reacts to what they saw a moment
ago, but it controls its own body instantly, the way you control yours. So
it reacts to your moves late (that's what makes it fair and beatable), but
it never misjudges its own jumps or edges. The first version delayed its
button presses instead, and that one choice caused the overshooting, wasted
jumps and late recoveries.

- **The ring buffer:**
  - `cpu.tick % size`: `%` is the remainder after dividing. As `tick` goes
    0, 1, 2 … 60, 61, 62, this gives 0, 1, 2 … 60, 0, 1. So the 61 slots get
    reused in a loop, and the newest copy always overwrites the oldest.
  - `cpu.seen[(cpu.tick - config.reaction_ticks) % size]`: the copy saved
    `reaction_ticks` ticks ago.
  - `if cpu.tick >= config.reaction_ticks`: for the first few ticks of a
    match there's nothing that old yet, so it uses what it sees now.
- `cpu_think(cpu, me, seen, ...)`: its own fighter now, the opponent as it
  was.
- `cpu.last = input`: remembered so `press` can tell what was held.
- Copying a whole `Fighter` 60 times a second is fine: it's a few hundred
  bytes.

**Build.**

---

## Part 5: drop in the plumbing

Replace these with the files I sent:

| File | What changed |
|---|---|
| `src/game.odin` | `Game_Mode` (VS CPU / VERSUS), the title menu, loading `cpu.json`, P2's input coming from `cpu_update` in VS CPU, F5 reloads it, CPU reset at match start |
| `src/render.odin` | The title menu, the CPU's state above its head with F2, "CPU David" in the HUD, "CPU WINS" |
| `src/data.odin` | `load_cpu_config`, with checks for misspelled keys |
| `data/cpu.json` (new) | The CPU's tuning |

They're your pushed versions with only these changes added. **If you've
edited any of those three `.odin` files since your last push, tell me before
replacing them**, so nothing of yours is lost.

The part of `game.odin` that matters for CP4 is in `match_update`:

```odin
		input := read_input(g.bindings[i])
		if i == 1 && g.mode == .Vs_Cpu {
			input = cpu_update(&g.cpu, f, g.fighters[0], g.stage, g.cpu_config)
		}
		fighter_update(&f, input, g.stage)
```

That's the whole hookup: in VS CPU, player 2's input comes from the CPU
instead of the keyboard, and everything after that is the same code a player
goes through.

**Build. The title screen now has VS CPU and VERSUS.**

---

## Part 6: test

Keep F2 on so you can see `CPU: <state>` above David. Test everything at
normal speed, then again with F1 (Slow on P2).

1. **Title menu:** W/S switches between VS CPU and VERSUS. VERSUS plays
   exactly like before.
2. **Approach and Attack:** stand still. It walks up, attacks, and the label
   goes APPROACH, then ATTACK, then APPROACH or RETREAT.
3. **Facing:** walk or jump over it. Its attacks come out facing you (it
   reacts to where you were 0.2 s ago, so a very fast cross-up can still
   fool it, which is fair).
4. **Retreat:** sometimes it backs off after an attack (about 40% of the
   time).
5. **Edges:** jump off the stage and wait there. It stops at the edge and
   doesn't follow you off. It doesn't walk off middle platforms either.
6. **Recover:** knock it off either side. The label shows RECOVER, and it
   double jumps and air dashes back.
7. **Hitstun:** hit it. The label shows HITSTUN until it can act again.
8. **Platforms:** stand on the top platform. It climbs via a middle platform
   and fights you up there. Jump above it and it up-airs. Stand on a middle
   platform and then drop down: it follows.
9. **Tuning with F5:** set `reaction_ticks` to 0 in `cpu.json` and press F5.
   It gets noticeably harder. Set `aggression` to 1 and it never retreats.

## For the demo (CP4 marks: 2 behaviour, 2 movement, 1 justification)

- **Behaviour:** name the five states and show each one with the F2 label.
  The transition table is in `docs/cpu.md`.
- **Movement:** show it approaching, climbing to the top platform and
  recovering.
- **Justification:** steering plus a waypoint rule, not A*, because the stage
  is a single screen with four platforms. The only obstacle is height, and
  the target moves every tick. Read `docs/cpu.md` until you can say this in
  your own words, because you'll be asked.

## Attribution

- Original work: `src/cpu.odin`, typed by me from an AI-provided, line-by-line
  explained example (`docs/cpu_guide.md`).
- AI table: `docs/cpu.md` and `docs/cpu_guide.md` (Claude Code, written from
  my decisions), plus CPU hookup, title mode menu and CPU state label added to
  the `game.odin`, `render.odin` and `data.odin` rows, the slowed-input fix in
  the `fighter.odin` row, and a new `data/cpu.json` row.
