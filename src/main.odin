package main

import rl "vendor:raylib"

SCREEN_WIDTH  :: 1280
SCREEN_HEIGHT :: 720

// The simulation always runs at exactly 60 ticks per second, no matter how
// fast the monitor refreshes. All frame data (startup, dash length, ...) is
// counted in these ticks.
TICK_RATE :: 60
TICK_DT   :: 1.0 / f32(TICK_RATE)

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Freeform Canvas")
	defer rl.CloseWindow()

	game := game_init()

	// Fixed-timestep loop:
	//   pass 1 (update) runs 0..n times per screen frame, always in TICK_DT steps
	//   pass 2 (render) runs once per screen frame and only reads the game
	accumulator: f32
	for !rl.WindowShouldClose() {
		// Clamp so a long hitch (dragging the window, a breakpoint) doesn't
		// make the game try to catch up on hundreds of ticks at once.
		accumulator += min(rl.GetFrameTime(), 0.25)
		for accumulator >= TICK_DT {
			game_update(&game)
			accumulator -= TICK_DT
		}

		// `game` is passed by value: Odin parameters are read-only, so the
		// compiler guarantees render cannot change the game state.
		render(game)
	}
}
