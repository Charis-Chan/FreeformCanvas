package main

import rl "vendor:raylib"

Vec2 :: rl.Vector2

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------

Button :: enum {
	Left, Right, Up, Down,
	Jump, Dash,
	Attack,  // jab on the ground, aerial in the air
	Special,
	Strong,
}

// The set of buttons held this tick. A fighter only ever sees this, never the
// keyboard, so a CPU opponent (CP4) can drive a fighter by filling one in.
Input :: bit_set[Button]

Key_Bindings :: [Button]rl.KeyboardKey

// Keys marked PROVISIONAL were not specified yet; change them freely.
P1_BINDINGS := Key_Bindings {
	.Left    = .A,
	.Right   = .D,
	.Up      = .W,
	.Down    = .S,
	.Jump    = .SPACE,
	.Dash    = .LEFT_SHIFT,
	.Attack  = .P,
	.Special = .O,
	.Strong  = .I,
}

// Player 2 is a stand-in until the CPU opponent (CP4) takes this slot.
// Uses keys that exist on laptop keyboards (no numpad).
P2_BINDINGS := Key_Bindings {
	.Left    = .LEFT,
	.Right   = .RIGHT,
	.Up      = .UP,
	.Down    = .DOWN,
	.Jump    = .RIGHT_SHIFT,
	.Dash    = .RIGHT_CONTROL,
	.Attack  = .PERIOD,
	.Special = .COMMA,
	.Strong  = .SLASH,
}

// Reads which buttons are *held*. "Just pressed" is worked out per fighter
// step by comparing with the previous step's input. rl.IsKeyPressed can't be
// used here: with a fixed timestep a screen frame may run 0 or 2+ ticks, so
// a press would be missed or counted twice.
read_input :: proc(bindings: Key_Bindings) -> Input {
	input: Input
	for key, button in bindings {
		if rl.IsKeyDown(key) do input += {button}
	}
	return input
}

// ---------------------------------------------------------------------------
// Data: stats and moves (per character, shared by every fighter using them).
// The values live in data/characters/*.json; see data.odin.
// ---------------------------------------------------------------------------

// All speeds are in pixels per tick, gravity in pixels per tick^2.
Fighter_Stats :: struct {
	size:                 Vec2,
	walk_speed:           f32,
	run_speed:            f32,
	air_speed:            f32, // max horizontal speed while airborne
	air_accel:            f32,
	gravity:              f32,
	max_fall_speed:       f32,
	jump_velocity:        f32,
	double_jump_velocity: f32,
	max_air_jumps:        int,
	dash_speed:           f32,
	dash_frames:          int,
	dash_cooldown:        int, // ticks before you can dash again
	max_air_dashes:       int, // refreshed on landing
}

Move :: enum {
	Jab,
	Side_Strong,
	Neutral_Special,
	Forward_Aerial,
	Up_Aerial,
	Down_Aerial,
}

// The combo openers from the GDD; each character's gimmick is attached to
// its moves as data.
Opener :: enum {
	None,
	Stun,
	Slow,
}

// One attack. Frame counts are in ticks. The hitbox is relative to the
// fighter's feet while facing right; it is mirrored when facing left
// (see the hitbox explanation in data/characters/lucy.json).
// Openers are not applied on hit yet.
Attack_Data :: struct {
	startup:          int,
	active:           int,
	recovery:         int,
	hitbox:           rl.Rectangle,
	damage:           f32,
	base_knockback:   f32,
	knockback_growth: f32,
	angle:			  f32,
	opener:           Opener,
}

attack_total_frames :: proc(a: Attack_Data) -> int {
	return a.startup + a.active + a.recovery
}

// Which move a button press means. Ground and air are separate tables: the
// same Attack button gives a jab on the ground and an aerial in the air.
is_aerial :: proc(move: Move) -> bool {
	return move == .Forward_Aerial || move == .Up_Aerial || move == .Down_Aerial
}

// `held` gives the direction (e.g. holding up in the air means up aerial);
// `pressed` gives which attack button was just pushed.
select_move :: proc(grounded: bool, pressed, held: Input) -> (move: Move, ok: bool) {
	if grounded {
		if .Attack in pressed do return .Jab, true
		if .Strong in pressed do return .Side_Strong, true
		if .Special in pressed do return .Neutral_Special, true
	} else {
		// Strong has no air version, so in the air it gives an aerial
		// instead of eating the input. No neutral/back aerial yet (stretch),
		// so anything that isn't up or down gives the forward aerial, in the
		// direction the fighter is facing.
		if .Attack in pressed || .Strong in pressed {
			if (.Up in held){
				return .Up_Aerial, true
			}else if (.Down in held){
				return .Down_Aerial, true
			}else {
				return .Forward_Aerial, true
			}
		}
		if .Special in pressed do return .Neutral_Special, true
	}
	return {}, false
}

// ---------------------------------------------------------------------------
// The fighter entity
// ---------------------------------------------------------------------------

Fighter_State :: enum {
	Idle,
	Walk,
	Run,
	Airborne,
	Dash,    // ground dash and air dash
	Attack,  // which one is in `move`
	Hitstun, // knocked back, can't act until hitstun_left runs out
}

Fighter :: struct {
	character:   ^Character_Data, // shared, loaded from data/characters/
	rules:       ^Rules,          // shared, loaded from data/rules.json
	pos:         Vec2, // feet, horizontally centred
	vel:         Vec2,
	facing:      f32,  // +1 right, -1 left
	state:       Fighter_State,
	state_frame: int,  // ticks spent in the current state
	grounded:    bool,

	air_jumps_left:  int,
	air_dashes_left: int,
	dash_dir:        Vec2,
	dash_cooldown:   int,
	move:            Move,

	// Double-tap detection for running.
	tap_dir:   f32, // direction of the last tap: -1, 0 or +1
	tap_timer: int, // ticks left to tap the same direction again

	b_reversed: bool, // already B-reversed during the current attack
	hit_landed: bool,
	hitstun_left: int,


	damage: f32,
	stocks: int,

	// Per-fighter clock. 1 = normal, 0.5 = half speed (the Slow gimmick),
	// 0 = frozen (hitstop, later). The fighter simulates one step each time
	// time_accum reaches 1.
	time_scale: f32,
	time_accum: f32,

	prev_input: Input,

	// Things that happened this tick, for the audio pass to play sounds.
	// Cleared by play_fighter_sounds after it reads them.
	events: bit_set[Fighter_Event],
}

Fighter_Event :: enum {
	Jumped,
	Hit,
	KO,
}

fighter_make :: proc(character: ^Character_Data, rules: ^Rules, spawn: Vec2, facing: f32) -> Fighter {
	f := Fighter {
		character  = character,
		rules      = rules,
		facing     = facing,
		stocks     = rules.starting_stocks,
		time_scale = 1,
	}
	fighter_respawn(&f, spawn)
	return f
}

fighter_respawn :: proc(f: ^Fighter, spawn: Vec2) {
	f.pos = spawn
	f.vel = {}
	f.damage = 0
	f.grounded = false
	f.air_jumps_left = f.character.stats.max_air_jumps
	f.air_dashes_left = f.character.stats.max_air_dashes
	f.dash_cooldown = 0
	f.tap_timer = 0
	set_state(f, .Airborne)
}

set_state :: proc(f: ^Fighter, state: Fighter_State) {
	if f.state != state {
		f.state = state
		f.state_frame = 0
	}
}

// Called once per game tick. Runs 0, 1 or more steps depending on time_scale.
fighter_update :: proc(f: ^Fighter, input: Input, stage: Stage) {
	f.time_accum += f.time_scale
	for f.time_accum >= 1 {
		f.time_accum -= 1
		fighter_step(f, input, stage)
	}
}

// One frame of this fighter's own time.
fighter_step :: proc(f: ^Fighter, input: Input, stage: Stage) {
	s := &f.character.stats
	pressed := input - f.prev_input
	f.prev_input = input
	if f.dash_cooldown > 0 do f.dash_cooldown -= 1

	dir: f32
	if .Left in input do dir -= 1
	if .Right in input do dir += 1

	// A direction tapped twice in quick succession means "run".
	tap: f32
	if .Left in pressed do tap -= 1
	if .Right in pressed do tap += 1
	double_tapped := false
	if f.tap_timer > 0 do f.tap_timer -= 1
	if tap != 0 {
		double_tapped = f.tap_timer > 0 && tap == f.tap_dir
		f.tap_dir = tap
		f.tap_timer = f.rules.double_tap_window
	}

	switch f.state {
	case .Idle, .Walk, .Run:
		was_facing := f.facing
		if dir != 0 do f.facing = dir
		keep_running := f.state == .Run && dir == was_facing

		if try_start_attack(f, pressed, input) {
			// attack started
		} else if .Dash in pressed && f.dash_cooldown == 0 {
			start_dash(f, input)
		} else if .Jump in pressed {
			f.vel.y = -s.jump_velocity
			f.events += {.Jumped}
			set_state(f, .Airborne)
		} else if dir == 0 {
			f.vel.x = 0
			set_state(f, .Idle)
		} else if keep_running || double_tapped {
			f.vel.x = dir * s.run_speed
			set_state(f, .Run)
		} else {
			f.vel.x = dir * s.walk_speed
			set_state(f, .Walk)
		}

	case .Airborne:
		// No turning in the air: facing stays as it was when you left the
		// ground. Holding the other way only drifts you backwards.
		if try_start_attack(f, pressed, input) {
			// attack started
		} else if .Dash in pressed && f.dash_cooldown == 0 && f.air_dashes_left > 0 {
			f.air_dashes_left -= 1
			start_dash(f, input)
		} else {
			if .Jump in pressed && f.air_jumps_left > 0 {
				f.air_jumps_left -= 1
				f.vel.y = -s.double_jump_velocity
				f.events += {.Jumped}
			}
			air_drift(f, dir)
		}

	case .Dash:
		f.vel = f.dash_dir * s.dash_speed
		if f.state_frame >= s.dash_frames {
			f.vel = f.dash_dir * (s.walk_speed if f.grounded else s.air_speed)
			f.dash_cooldown = s.dash_cooldown
			set_state(f, .Idle if f.grounded else .Airborne)
		}

	case .Attack:
		// B-reverse: early in neutral special, holding the opposite
		// direction turns you around and flips your horizontal momentum.
		if f.move == .Neutral_Special && !f.b_reversed &&
		   f.state_frame <= f.rules.b_reverse_window && dir == -f.facing {
			f.facing = -f.facing
			f.vel.x = -f.vel.x
			f.b_reversed = true
		}

		if f.grounded {
			f.vel.x = 0
		} else {
			air_drift(f, dir)
		}
		if f.state_frame >= attack_total_frames(f.character.moves[f.move]) {
			set_state(f, .Idle if f.grounded else .Airborne)
		}

	case .Hitstun:
		f.vel.x = move_toward(f.vel.x, 0, f.rules.knockback_friction)
		f.hitstun_left -= 1
		if f.hitstun_left <= 0{
			set_state(f, .Idle if f.grounded else .Airborne)
		}
	}

	// Physics. Dashes ignore gravity for their duration.
	if f.state != .Dash {
		f.vel.y = min(f.vel.y + s.gravity, s.max_fall_speed)
	}
	prev_feet_y := f.pos.y
	f.pos += f.vel
	land_on_platforms(f, stage, prev_feet_y, drop_through = .Down in input)

	// Walked off an edge.
	if !f.grounded && (f.state == .Idle || f.state == .Walk || f.state == .Run) {
		set_state(f, .Airborne)
	}

	f.state_frame += 1
}

// Which way a dash goes: the held left/right direction, or the facing
// direction if neither is held. This does not turn the fighter, so in the
// air you can dash backwards while still facing forwards.
// dash_dir is a 2D vector, so diagonal/8-way dashes only need changes here.
dash_direction :: proc(f: ^Fighter, input: Input) -> Vec2 {
	dir: f32
	if .Left in input do dir -= 1
	if .Right in input do dir += 1
	if dir == 0 do dir = f.facing
	return {dir, 0}
}

start_dash :: proc(f: ^Fighter, input: Input) {
	f.dash_dir = dash_direction(f, input)
	f.vel = f.dash_dir * f.character.stats.dash_speed
	set_state(f, .Dash)
}

try_start_attack :: proc(f: ^Fighter, pressed, held: Input) -> bool {
	move, ok := select_move(f.grounded, pressed, held)
	if !ok do return false
	f.move = move
	f.b_reversed = false
	f.hit_landed = false
	set_state(f, .Attack)
	return true
}

air_drift :: proc(f: ^Fighter, dir: f32) {
	target := dir * f.character.stats.air_speed
	f.vel.x = move_toward(f.vel.x, target, f.character.stats.air_accel)
}

move_toward :: proc(current, target, step: f32) -> f32 {
	if current < target do return min(current + step, target)
	return max(current - step, target)
}

// Lands the fighter on any platform whose top it crossed this step.
// Platforms are one-way for now (you can jump up through them and you don't
// collide with their sides); proper collision is the Oct 26 studio.
land_on_platforms :: proc(f: ^Fighter, stage: Stage, prev_feet_y: f32, drop_through: bool) {
	was_grounded := f.grounded
	f.grounded = false
	if f.vel.y < 0 do return

	half_w := f.character.stats.size.x / 2
	for p in stage.platforms {
		if p.soft && drop_through do continue

		top := p.rect.y
		overlaps_x := f.pos.x + half_w > p.rect.x && f.pos.x - half_w < p.rect.x + p.rect.width
		if overlaps_x && prev_feet_y <= top && f.pos.y >= top {
			f.pos.y = top
			f.vel.y = 0
			f.grounded = true
			break
		}
	}

	if f.grounded && !was_grounded {
		f.air_jumps_left = f.character.stats.max_air_jumps
		f.air_dashes_left = f.character.stats.max_air_dashes
		// Landing ends a jump or an aerial (landing lag comes later).
		if f.state == .Airborne || (f.state == .Attack && is_aerial(f.move)) {
			set_state(f, .Idle)
		}
	}
}

// ---------------------------------------------------------------------------
// Geometry helpers (pure functions: used by render now, collision later)
// ---------------------------------------------------------------------------

fighter_body :: proc(f: Fighter) -> rl.Rectangle {
	w, h := f.character.stats.size.x, f.character.stats.size.y
	return {f.pos.x - w / 2, f.pos.y - h, w, h}
}

// The current hitbox in world space, if the attack is in its active frames.
attack_hitbox :: proc(f: Fighter) -> (box: rl.Rectangle, active: bool) {
	if f.state != .Attack do return {}, false
	a := f.character.moves[f.move]
	if f.state_frame < a.startup || f.state_frame >= a.startup + a.active {
		return {}, false
	}

	box = a.hitbox
	box.x = f.pos.x + box.x if f.facing > 0 else f.pos.x - box.x - box.width
	box.y = f.pos.y + box.y
	return box, true
}
