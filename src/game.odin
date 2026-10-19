package main

import "core:fmt"
import rl "vendor:raylib"

Game_State :: enum {
	Title,
	Match,
	Results,
}

// Which character each player uses (character select screen comes later).
PLAYER_CHARACTERS := [2]Character_Id{.Lucy, .David}

STAGE_FILE :: "data/stages/main.json"

RELOAD_MESSAGE_TICKS :: 120 // how long the F5 result stays on screen

Game :: struct {
	state:    Game_State,
	stage:    Stage,
	fighters: [2]Fighter,
	bindings: [2]Key_Bindings,
	winner:   int, // index into fighters, valid in .Results

	// Loaded from data/ once at startup, replaced in place by F5.
	// Fighters point at these, so they always see the latest values.
	rules:      Rules,
	characters: [Character_Id]Character_Data,

	reload_message:      cstring,
	reload_message_good: bool,
	reload_message_left: int, // ticks until the message disappears

	// Menu keys are edge-detected per tick (see read_input in fighter.odin
	// for why we don't use rl.IsKeyPressed inside update).
	prev_confirm: bool,
	prev_debug:   bool,
	prev_reload:  bool,
}

// Loads all data files. Returns ok = false if any of them is missing or
// broken; the file and the problem have already been printed by then.
game_init :: proc() -> (g: Game, ok: bool) {
	rules, rules_ok := load_rules(RULES_FILE)
	if !rules_ok do return
	g.rules = rules

	characters, chars_ok := load_all_characters()
	if !chars_ok do return
	g.characters = characters

	stage, stage_ok := load_stage(STAGE_FILE)
	if !stage_ok do return
	g.stage = stage

	g.state = .Title
	g.bindings = {P1_BINDINGS, P2_BINDINGS}
	return g, true
}

start_match :: proc(g: ^Game) {
	for i in 0 ..< 2 {
		character := &g.characters[PLAYER_CHARACTERS[i]]
		facing: f32 = 1 if i == 0 else -1
		g.fighters[i] = fighter_make(character, &g.rules, g.stage.spawns[i], facing)
	}
	g.state = .Match
}

// F5: reread every data file. If anything fails to load, nothing is changed
// and the game keeps running on the old values.
reload_data :: proc(g: ^Game) {
	rules, rules_ok := load_rules(RULES_FILE)
	characters, chars_ok := load_all_characters()
	stage, stage_ok := load_stage(STAGE_FILE)
	if !rules_ok || !chars_ok || !stage_ok {
		if chars_ok do for &c in characters do free_character(&c)
		if stage_ok do delete(stage.platforms)
		show_reload_message(g, "Reload FAILED - see console, kept old data", false)
		return
	}

	// Replace in place: fighters hold pointers to these exact variables.
	for &c in g.characters do free_character(&c)
	g.rules = rules
	g.characters = characters
	delete(g.stage.platforms)
	g.stage = stage
	show_reload_message(g, "Data reloaded", true)
	fmt.println("Reloaded data files")
}

show_reload_message :: proc(g: ^Game, message: cstring, good: bool) {
	g.reload_message = message
	g.reload_message_good = good
	g.reload_message_left = RELOAD_MESSAGE_TICKS
}

// Pass 1: all game logic. No drawing happens here.
game_update :: proc(g: ^Game) {
	confirm := rl.IsKeyDown(.ENTER)
	confirm_pressed := confirm && !g.prev_confirm
	g.prev_confirm = confirm

	reload := rl.IsKeyDown(.F5)
	if reload && !g.prev_reload do reload_data(g)
	g.prev_reload = reload
	if g.reload_message_left > 0 do g.reload_message_left -= 1

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
			f.events += {.KO}
			if f.stocks <= 0 {
				g.winner = 1 - i
				g.state = .Results
				return
			}
			fighter_respawn(&f, g.stage.spawns[i])
		}
	}
}
