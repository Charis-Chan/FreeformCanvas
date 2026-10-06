package main

import rl "vendor:raylib"

Platform :: struct {
	rect: rl.Rectangle,
	soft: bool, // soft platforms can be dropped through by holding down
}

Stage :: struct {
	platforms:  []Platform,
	blast_zone: rl.Rectangle, // leave this rectangle and you lose a stock
	spawns:     [2]Vec2,      // feet position of each player at (re)spawn
}

// Level data. Moves to a data file in CP3.
DEFAULT_PLATFORMS := [?]Platform {
	{rect = {290, 520, 700, 200}, soft = false}, // main stage
	{rect = {390, 380, 180, 12}, soft = true},
	{rect = {710, 380, 180, 12}, soft = true},
	{rect = {550, 250, 180, 12}, soft = true},
}

make_default_stage :: proc() -> Stage {
	return Stage {
		platforms  = DEFAULT_PLATFORMS[:],
		blast_zone = {-300, -400, 1880, 1500},
		spawns     = {{450, 520}, {830, 520}},
	}
}
