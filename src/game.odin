package main

import rl "vendor:raylib"

STARTING_STOCKS :: 3

Game_State :: enum {
	Title,
	Match,
	Results,
}

Game :: struct {
	state:    Game_State,
	stage:    Stage,
	fighters: [2]Fighter,
	bindings: [2]Key_Bindings,
	winner:   int, // index into fighters, valid in .Results

	// Menu keys are edge-detected per tick (see read_input in fighter.odin
	// for why we don't use rl.IsKeyPressed inside update).
	prev_confirm: bool,
	prev_debug:   bool,
}

game_init :: proc() -> Game {
	return Game {
		state    = .Title,
		stage    = make_default_stage(),
		bindings = {P1_BINDINGS, P2_BINDINGS},
	}
}

start_match :: proc(g: ^Game) {
	g.fighters[0] = fighter_make(&DEFAULT_STATS, g.stage.spawns[0], facing = 1)
	g.fighters[1] = fighter_make(&DEFAULT_STATS, g.stage.spawns[1], facing = -1)
	g.state = .Match
}

// Pass 1: all game logic. No drawing happens here.
game_update :: proc(g: ^Game) {
	confirm := rl.IsKeyDown(.ENTER)
	confirm_pressed := confirm && !g.prev_confirm
	g.prev_confirm = confirm

	switch g.state {
	case .Title:
		if confirm_pressed do start_match(g)
	case .Match:
		match_update(g)
	case .Results:
		if confirm_pressed do g.state = .Title
	}
}

match_update :: proc(g: ^Game) {
	// DEBUG: toggle Slow on player 2 to demonstrate per-fighter time scale.
	debug := rl.IsKeyDown(.F1)
	if debug && !g.prev_debug {
		f := &g.fighters[1]
		f.time_scale = 0.5 if f.time_scale == 1 else 1
	}
	g.prev_debug = debug

	for &f, i in g.fighters {
		fighter_update(&f, read_input(g.bindings[i]), g.stage)

		if !rl.CheckCollisionPointRec(f.pos, g.stage.blast_zone) {
			f.stocks -= 1
			if f.stocks <= 0 {
				g.winner = 1 - i
				g.state = .Results
				return
			}
			fighter_respawn(&f, g.stage.spawns[i])
		}
	}
}
