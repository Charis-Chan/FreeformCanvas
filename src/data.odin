package main

import "core:encoding/json"
import "core:fmt"
import "core:os"

// Everything tunable lives in data/ and is loaded at startup (and on F5).
// The game reads these files with Odin's JSON parser, which accepts JSON5:
// comments and trailing commas are allowed.

RULES_FILE :: "data/rules.json"

Character_Id :: enum {
	Lucy,  // Stun opener
	David, // Slow opener
}

CHARACTER_FILES := [Character_Id]string {
	.Lucy  = "data/characters/lucy.json",
	.David = "data/characters/david.json",
}

// Match-wide rules shared by every fighter.
Rules :: struct {
	starting_stocks:   int,
	double_tap_window: int, // ticks between two taps of a direction to start a run
	b_reverse_window:  int, // ticks after neutral special in which B-reverse works
	hitstun_per_knockback: f32,
	knockback_friction: f32,
}

// One character file: name, movement stats and every move's data.
Character_Data :: struct {
	id:           Character_Id, // set by the loader, not read from the file
	display_name: string,
	stats:        Fighter_Stats,
	moves:        [Move]Attack_Data,
	animations:   [Anim]Anim_Timing, // optional in the file; missing ones use DEFAULT_TICKS_PER_FRAME
}

// How long each art frame stays on screen, in game ticks (60 per second).
// Attacks ignore this: their frames follow startup / active / recovery.
Anim_Timing :: struct {
	ticks_per_frame: int,
}

DEFAULT_TICKS_PER_FRAME :: 8

// Reads a JSON file into `out`. Prints a message naming the file on failure.
load_json_file :: proc(path: string, out: ^$T) -> bool {
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		fmt.eprintln("Could not read", path, "-", read_err)
		return false
	}
	defer delete(data)

	if json_err := json.unmarshal(data, out); json_err != nil {
		// For syntax mistakes (missing comma, colon, quote) unmarshal only
		// says "Invalid_Data", so find the position ourselves.
		if line, column, found := find_json_syntax_error(data); found {
			fmt.eprintf("Could not parse %s - %v at line %d, column %d\n", path, json_err, line, column)
		} else {
			fmt.eprintln("Could not parse", path, "-", json_err)
		}
		return false
	}
	return true
}

// Parses `data` without converting it, to report where invalid JSON is.
find_json_syntax_error :: proc(data: []byte) -> (line, column: int, found: bool) {
	p := json.make_parser(data)
	value, err := json.parse_value(&p)
	json.destroy_value(value)
	if err == .None do return
	pos := p.curr_token.pos
	return pos.line, pos.column, true
}

load_rules :: proc(path: string) -> (rules: Rules, ok: bool) {
	if !load_json_file(path, &rules) do return
	if rules.starting_stocks < 1 {
		fmt.eprintln(path, "- starting_stocks must be at least 1")
		return
	}
	if rules.hitstun_per_knockback <= 0 || rules.knockback_friction <= 0{
		fmt.eprintln(path, "- hitstun_per_knockback and knockback must be above 0 (misspelled key?)")
		return
	}
	return rules, true
}

load_character :: proc(path: string) -> (c: Character_Data, ok: bool) {
	if !load_json_file(path, &c) do return

	// The JSON parser silently ignores misspelled keys, leaving that field at
	// 0. Catch the zeros that would break the game outright.
	s := c.stats
	if s.size.x <= 0 || s.size.y <= 0 || s.gravity <= 0 || s.max_fall_speed <= 0 {
		fmt.eprintln(path, "- size, gravity and max_fall_speed must all be above 0 (misspelled key?)")
		free_character(&c)
		return
	}
	for a, move in c.moves {
		if attack_total_frames(a) <= 0 {
			fmt.eprintln(path, "- move", move, "has no frames (missing from the file?)")
			free_character(&c)
			return
		}
	}
	return c, true
}

free_character :: proc(c: ^Character_Data) {
	delete(c.display_name)
	c.display_name = ""
}

load_all_characters :: proc() -> (chars: [Character_Id]Character_Data, ok: bool) {
	for path, id in CHARACTER_FILES {
		c, loaded := load_character(path)
		if !loaded {
			for &already in chars do free_character(&already)
			return
		}
		c.id = id
		chars[id] = c
	}
	return chars, true
}
