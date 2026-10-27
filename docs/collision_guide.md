# Collision Guide: hits, damage, knockback, hitstun

You type everything in this guide. I've built and run this exact code in my
copy: Lucy's side strong hits David once, he takes 14%, gets launched up and
away, lands, and recovers to idle.

**Do the steps in order.** The game compiles after every step, so if a build
fails, the mistake is in the step you just did. Build with your usual command
after each one.

What you're adding:

| Step | File | What |
|---|---|---|
| 1 | `src/data.odin`, `data/rules.json` | Two new rules: how long hitstun lasts, how fast a launch slows down |
| 2 | `src/fighter.odin`, both character files | A launch angle for every move, plus knockback numbers |
| 3 | `src/fighter.odin` | Two new fighter fields and a new event |
| 4 | `src/fighter.odin` | What a fighter does while in hitstun |
| 5 | `src/combat.odin` (**new file, yours**) | Hit detection and hit response |
| 6 | `src/game.odin` | Run the hit checks every tick (hits start working here) |
| 7 | `src/assets.odin` | Play the hit sound |

---

## How a hit works (read this first)

Every tick, after both fighters have moved:

1. **Detection:** is the attacker's hitbox active, and does it overlap the
   victim's body box (the yellow 48 x 90 box)? Both are rectangles, so raylib's
   `rl.CheckCollisionRecs` answers that.
2. **Hits once:** an attack is active for several ticks (side strong: 8).
   Without a guard it would hit 8 times. Each fighter remembers
   `hit_landed` for its current attack.
3. **Response:**
   - damage is added to the victim's %
   - knockback strength = `base_knockback + knockback_growth x damage / 100`.
     So the more damage the victim has, the further they fly.
   - the strength is turned into a velocity using the move's angle
   - the victim goes into hitstun: no control for a number of ticks that
     grows with knockback
   - the victim gets a `Hit` event, so the hit sound plays

---

## Step 1: two new rules

### `src/data.odin`, in `Rules`

Add the last two lines:

```odin
Rules :: struct {
	starting_stocks:   int,
	double_tap_window: int, // ticks between two taps of a direction to start a run
	b_reverse_window:  int, // ticks after neutral special in which B-reverse works
	hitstun_per_knockback: f32, // ticks of hitstun per unit of knockback
	knockback_friction:    f32, // how much horizontal launch speed is lost per tick
}
```

- `hitstun_per_knockback`: a hit with knockback 10 and this set to 2.5 gives
  25 ticks of hitstun. One number tunes hitstun for every move at once.
- `knockback_friction`: without it, a fighter knocked sideways would keep
  that sideways speed forever. Each tick, this much is taken off.
- `f32` because these can be fractions (2.5, 0.2).

### `src/data.odin`, in `load_rules`

Add the second `if` after the `starting_stocks` check:

```odin
	if rules.starting_stocks < 1 {
		fmt.eprintln(path, "- starting_stocks must be at least 1")
		return
	}
	if rules.hitstun_per_knockback <= 0 || rules.knockback_friction <= 0 {
		fmt.eprintln(path, "- hitstun_per_knockback and knockback_friction must be above 0 (misspelled key?)")
		return
	}
```

- If you misspell a key in the JSON, the parser silently leaves it at 0.
  Zero hitstun or zero friction would break hits in confusing ways, so the
  game refuses to start and tells you instead.
- `||` means "or".

### `data/rules.json`

```json
{
	"starting_stocks": 3,
	"double_tap_window": 12, // ticks between two taps of a direction to start a run
	"b_reverse_window": 5,   // ticks after neutral special in which B-reverse works
	"hitstun_per_knockback": 2.5, // ticks of hitstun per unit of knockback
	"knockback_friction": 0.2,    // horizontal launch speed lost per tick
}
```

The key names must match the field names in `Rules` exactly.

**Build. It should run exactly as before.**

---

## Step 2: launch angles and knockback numbers

### `src/fighter.odin`, in `Attack_Data`

Add the `angle` line, and the comment on `knockback_growth`:

```odin
Attack_Data :: struct {
	startup:          int,
	active:           int,
	recovery:         int,
	hitbox:           rl.Rectangle,
	damage:           f32,
	base_knockback:   f32,
	knockback_growth: f32, // extra knockback per 100% the victim has
	angle:            f32, // launch angle in degrees: 0 = forward, 90 = up, -90 = down
	opener:           Opener,
}
```

How the angle works, measured from the way the **attacker** faces:

```
              90 (straight up)
               |
     135       |       45 (up and forward)
         \     |     /
          \    |    /
  180 ---- attacker ----> 0 (straight forward)
  (backward)   |
               |
             -90 (straight down, a spike)
```

Since it's measured from the attacker's facing, a B-reversed neutral special
sends the victim the new way, which is what you want.

Also change the comment above `Attack_Data` from
`// Damage/knockback/opener are not applied yet (collision week, Oct 26).` to
`// Openers are not applied on hit yet.`

### Both character files: add numbers to every move

In `data/characters/lucy.json` and `david.json`, every move line has
`"base_knockback": 0, "knockback_growth": 0,`. Change both numbers and add
`"angle"` after them. Starting values (the same for both characters for now):

| Move | base_knockback | knockback_growth | angle | Feel |
|---|---|---|---|---|
| Jab | 3 | 3 | 30 | Small pop, never kills |
| Side_Strong | 7 | 16 | 40 | The kill move |
| Neutral_Special | 5 | 8 | 45 | Medium |
| Forward_Aerial | 5 | 10 | 40 | Medium, combo into more aerials |
| Up_Aerial | 6 | 9 | 90 | Straight up, juggles |
| Down_Aerial | 4 | 10 | -80 | Spike: down and slightly forward |

Lucy's jab line becomes:

```json
"Jab": {"startup": 4, "active": 3, "recovery": 10, "hitbox": {"x": 20, "y": -60, "width": 45, "height": 25}, "damage": 3, "base_knockback": 3, "knockback_growth": 3, "angle": 30, "opener": "Stun"},
```

Keep your own openers (Lucy's Side_Strong stays `"Stun"`). Only the
knockback numbers and `angle` change.

Replace the comment above `"moves"` that says knockback isn't applied:

```json
	// opener: "None", "Stun" or "Slow" (not applied on hit yet).
	// Knockback = base_knockback + knockback_growth x (victim's damage / 100), in pixels per tick.
	// angle: launch direction in degrees. 0 = straight forward, 45 = up and forward, 90 = straight up, -90 = straight down.
```

**Build. Still no change in game: nothing reads these yet.**

---

## Step 3: new fighter fields and the Hit event

### `src/fighter.odin`, in `Fighter`

Add the two new lines right under `b_reversed`:

```odin
	b_reversed:   bool, // already B-reversed during the current attack
	hit_landed:   bool, // the current attack already hit (each attack hits once)
	hitstun_left: int,  // ticks of hitstun remaining
```

- `hit_landed`: the "hits once" guard from the overview.
- `hitstun_left`: counts down to 0 while in hitstun. It's a separate counter
  instead of using `state_frame`, so a fighter hit again while already in
  hitstun gets a fresh hitstun length.

### `src/fighter.odin`, in `try_start_attack`

Every new attack gets a fresh guard. Add the middle line:

```odin
	f.b_reversed = false
	f.hit_landed = false
	set_state(f, .Attack)
```

### `src/fighter.odin`, in `Fighter_Event`

```odin
Fighter_Event :: enum {
	Jumped,
	Hit, // this fighter was hit
	KO,
}
```

The victim gets this event, and the audio pass plays the hit sound for it
(step 7). It works the same way `Jumped` plays the jump sound.

Also change the comment on `Hitstun` in `Fighter_State` from
`// not used until collision week` to
`// knocked back, can't act until hitstun_left runs out`.

**Build.**

---

## Step 4: what hitstun does

### `src/fighter.odin`, in `fighter_step`

Near the end of the big `switch f.state`, there's an empty `case .Hitstun:`.
Fill it in:

```odin
	case .Hitstun:
		// No control: the launch carries the fighter, slowed down a
		// little each tick, with gravity still pulling.
		f.vel.x = move_toward(f.vel.x, 0, f.rules.knockback_friction)
		f.hitstun_left -= 1
		if f.hitstun_left <= 0 {
			set_state(f, .Idle if f.grounded else .Airborne)
		}
	}
```

(That last `}` is the end of the switch; it's already there.)

Line by line:
- Nothing in this case reads `input`, which is what "no control" means.
- `move_toward(f.vel.x, 0, ...)` brings the sideways speed closer to 0 by
  `knockback_friction` each tick. It's the same helper air drift uses.
- Vertical speed isn't touched here. The physics code right after the switch
  already applies gravity to every state except Dash, so a launched fighter
  rises, slows and falls on its own.
- `-= 1` counts hitstun down by one tick.
- When it reaches 0, the fighter gets control back: `Idle` if standing on
  something, `Airborne` if still in the air.

Landing during hitstun already works: `land_on_platforms` stops the fall and
leaves the state alone, so the fighter slides to a stop on the ground until
hitstun ends.

**Build.**

---

## Step 5: `src/combat.odin` (new file)

Create `src/combat.odin`. Odin builds every `.odin` file in `src/` together,
so there's nothing to import or register.

```odin
package main

import "core:math"
import rl "vendor:raylib"

// Hits between fighters: detection (does a hitbox touch a body?) and
// response (damage, knockback, hitstun).

// Called once per game tick, after both fighters have moved.
// Both checks happen before either hit is applied, so if both fighters hit
// each other on the same tick, both hits count (a trade) instead of player 1
// always winning.
resolve_hits :: proc(g: ^Game) {
	a, b := &g.fighters[0], &g.fighters[1]
	a_hits_b := attack_connects(a^, b^)
	b_hits_a := attack_connects(b^, a^)
	if a_hits_b do apply_hit(a, b)
	if b_hits_a do apply_hit(b, a)
}

// True if the attacker's active hitbox overlaps the victim's body and this
// attack hasn't already hit.
attack_connects :: proc(attacker, victim: Fighter) -> bool {
	if attacker.hit_landed do return false
	box, active := attack_hitbox(attacker)
	if !active do return false
	return rl.CheckCollisionRecs(box, fighter_body(victim))
}

apply_hit :: proc(attacker, victim: ^Fighter) {
	a := attacker.character.moves[attacker.move]
	attacker.hit_landed = true // each attack hits once

	victim.damage += a.damage

	// Knockback grows with the victim's damage (counted after this hit).
	// knockback_growth is the extra speed added per 100%.
	knockback := a.base_knockback + a.knockback_growth * victim.damage / 100

	// The angle is in degrees: 0 = straight forward (the way the attacker
	// faces), 90 = straight up, -90 = straight down. Screen y points down,
	// so the y part is negated.
	radians := a.angle * math.RAD_PER_DEG
	victim.vel = {
		math.cos(radians) * knockback * attacker.facing,
		-math.sin(radians) * knockback,
	}

	victim.hitstun_left = int(knockback * attacker.rules.hitstun_per_knockback)
	set_state(victim, .Hitstun)
	victim.events += {.Hit}
}
```

### `resolve_hits`

- `g: ^Game`: the `^` means a pointer, so this procedure can change the
  game (the fighters' damage, velocity, state).
- `a, b := &g.fighters[0], &g.fighters[1]`: short names for the two fighters.
  `&` takes their address, so changing `a` changes the real fighter 0, not a
  copy.
- `attack_connects(a^, b^)`: `a^` means "the fighter `a` points at". Checking
  only needs to read, so it gets plain values.
- **Why check both before applying either:** `apply_hit` puts the victim in
  hitstun, which ends their attack. If P1's hit were applied first, P2's
  attack would vanish before it was checked, so P1 would win every
  simultaneous hit. Checking both first makes it a fair trade.
- `if a_hits_b do apply_hit(a, b)`: `do` is Odin's one-line `if` body, the
  same as `{ apply_hit(a, b) }`.

### `attack_connects`

- `-> bool`: returns true or false.
- `if attacker.hit_landed do return false`: this attack already hit, so it
  can't hit again.
- `box, active := attack_hitbox(attacker)`: this already existed, and it's what
  draws the red box with F2. It gives the hitbox in world position (mirrored
  if facing left), and `active` is false outside the active frames.
- `rl.CheckCollisionRecs(box, fighter_body(victim))`: true if the two
  rectangles overlap at all. `fighter_body` is the yellow box.

### `apply_hit`

- `a := attacker.character.moves[attacker.move]`: the data for the move being
  used: damage, knockback, angle.
- `attacker.hit_landed = true`: closes the "hits once" guard.
- `victim.damage += a.damage`: adds the move's damage to the victim's %.
- `knockback := ...`: the formula. The victim's damage is added **before**
  this line, so a hit counts its own damage. Example: side strong (7 base,
  16 growth) on David at 86%: he goes to 100%, knockback = 7 + 16 x 100 / 100
  = 23.
- `radians := a.angle * math.RAD_PER_DEG`: `cos` and `sin` use radians, not
  degrees. Multiplying by `RAD_PER_DEG` converts (90 degrees becomes about
  1.57).
- `victim.vel = { x, y }`: replaces the victim's velocity. Their old movement
  is gone, and the launch is all that matters.
  - `math.cos(radians)` is how much of the launch is sideways: 1 at 0
    degrees, 0 at 90, about 0.77 at 40.
  - `* attacker.facing` flips it to the left when the attacker faces left
    (`facing` is +1 or -1).
  - `math.sin(radians)` is how much is upward: 0 at 0 degrees, 1 at 90.
  - **The minus:** on screen, y grows *downward*, so "up" is negative y.
    Without the minus, a 90 degree up aerial would launch straight into the
    floor.
- `victim.hitstun_left = int(...)`: the hitstun length. `int(...)` turns the
  `f32` result into whole ticks (it drops the fraction).
- `set_state(victim, .Hitstun)`: the victim's attack, dash or jump ends right
  now. A hit interrupts anything.
- `victim.events += {.Hit}`: tells the audio pass to play the hit sound.

**Build. Nothing calls `resolve_hits` yet, so nothing changes.**

---

## Step 6: run the checks every tick

### `src/game.odin`, at the end of `match_update`

Add the `resolve_hits(g)` line after the `for` loop, before the last `}`:

```odin
	for &f, i in g.fighters {
		fighter_update(&f, read_input(g.bindings[i]), g.stage)

		if !rl.CheckCollisionPointRec(f.pos, g.stage.blast_zone) {
			...  (unchanged)
		}
	}

	resolve_hits(g)
}
```

- It runs after the loop, so both fighters have already moved this tick and
  their boxes are in this tick's positions.
- `g` is already a `^Game` here, so it's passed straight through.

**Build and test. Hits work from here.**

---

## Step 7: hit sound

### `src/assets.odin`, in `play_fighter_sounds`

Add the middle line:

```odin
		if .Jumped in f.events do play_sound(assets, .Jump)
		if .Hit in f.events do play_sound(assets, .Hit)
		if .KO in f.events do play_sound(assets, .KO)
```

`hit.ogg` was already loaded in CP3, so this just plays it. You can also
delete the comment `// played once hits exist (collision week)` from `Hit` in
`Sound_Id`.

---

## Test checklist

Keep F2 boxes on.

1. **Basic hit:** walk P1 next to P2 and press I (side strong). P2's % goes
   up by 14, their label says `hitstun`, they fly up and away, then return
   to `idle` or `air`.
2. **Hits once:** after one side strong, P2's damage is exactly 14 more, not 14
   times several.
3. **Direction:** hit P2 from the left, then from the right. They should fly
   away from P1 both times.
4. **Angles:** up aerial sends straight up; down aerial on a jumping P2
   sends them down.
5. **Scaling:** hit P2 repeatedly. Higher % means they fly further. With my
   starting numbers, side strong sends P2 off the side of the stage at
   roughly 100%. These numbers are a starting point for you to tune.
6. **Trade:** both players jab at the same moment. Both should take damage.
7. **F5:** change Side_Strong's `angle` to 0, press F5, hit again. It should
   send them flat.
8. **Sound:** a hit plays `hit.ogg`.

## What's not in this step (on purpose)

- **Openers:** Lucy's Stun and David's Slow on hit. That's the next step, once
  this works. F1 still toggles Slow.
- **Solid stage sides:** you can still walk through the main platform from
  the side.
- **Hitstop, screen shake:** these are Polish.
- **Combo scaling and attack decay:** these come later.

## Tuning: what to change if it feels wrong

| Problem | Change |
|---|---|
| Everything flies too far / not far enough | `knockback_growth` on the moves |
| Weak moves still push too much at 0% | `base_knockback` |
| Victims recover too fast to combo / too slow (infinite combos) | `hitstun_per_knockback` in rules.json |
| Victims slide too far along the ground | `knockback_friction` in rules.json |
| A move sends the wrong way | That move's `angle` |

## Attribution, when you commit

- Original work: `src/combat.odin`, typed by me from an AI-provided,
  line-by-line explained example (same wording as `load_stage`).
- Add "Collision: hit handling (hitstun state, knockback angle, hit fields)"
  to the prompt column of the `src/fighter.odin`, `src/game.odin`,
  `src/data.odin` and `src/assets.odin` rows, only if you count those as
  AI-written. You're typing them, so they're arguably yours too: pick one and
  be consistent.
- Character files: your column gets "knockback values and angles", with
  "starting values suggested by Claude Code" if you keep mine.
