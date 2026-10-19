package main

import rl "vendor:raylib"
import "core:os"
import "core:encoding/json"
import "core:fmt"

Platform :: struct {
	rect: rl.Rectangle,
	soft: bool, // soft platforms can be dropped through by holding down
}

Stage :: struct {
	platforms:  []Platform,
	blast_zone: rl.Rectangle, // leave this rectangle and you lose a stock
	spawns:     [2]Vec2,      // feet position of each player at (re)spawn
}


load_stage :: proc(path: string) -> (stage: Stage, ok: bool) {
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil{
		fmt.eprintln("Could not read", path, "-", read_err)
		return
	}
	defer delete(data)
	json_err := json.unmarshal(data, &stage)
	if json_err != nil{
		fmt.eprintln("Could not parse", path, "-", json_err)
		return
	}

	ok = true
	return
}