package main

import rl "vendor:raylib"

// Pass 2: drawing only. Everything here reads the game; nothing changes it.

BACKGROUND_COLOR    :: rl.Color{24, 24, 32, 255}
PLATFORM_COLOR      :: rl.Color{90, 90, 110, 255}
SOFT_PLATFORM_COLOR :: rl.Color{130, 130, 160, 255}
HITBOX_COLOR        :: rl.Color{255, 60, 60, 140}

PLAYER_COLORS := [2]rl.Color {
	{230, 90, 80, 255},
	{80, 150, 230, 255},
}

STATE_LABELS := [Fighter_State]cstring {
	.Idle     = "idle",
	.Walk     = "walk",
	.Run      = "run",
	.Airborne = "air",
	.Dash     = "dash",
	.Attack   = "attack",
	.Hitstun  = "hitstun",
}

MOVE_LABELS := [Move]cstring {
	.Jab             = "JAB",
	.Side_Strong     = "SIDE STRONG",
	.Neutral_Special = "NEUTRAL SPECIAL",
	.Forward_Aerial  = "FORWARD AERIAL",
	.Up_Aerial       = "UP AERIAL",
    .Down_Aerial     = "DOWN AERIAL"
}

render :: proc(game: Game) {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(BACKGROUND_COLOR)

	switch game.state {
	case .Title:
		draw_text_centered("FREEFORM CANVAS", 240, 72, rl.RAYWHITE)
		draw_text_centered("Press ENTER to start", 360, 28, rl.LIGHTGRAY)
	case .Match:
		draw_match(game)
	case .Results:
		draw_text_centered(rl.TextFormat("PLAYER %d WINS", game.winner + 1), 260, 64, PLAYER_COLORS[game.winner])
		draw_text_centered("Press ENTER to return to title", 360, 28, rl.LIGHTGRAY)
	}
}

draw_match :: proc(game: Game) {
	for p in game.stage.platforms {
		rl.DrawRectangleRec(p.rect, SOFT_PLATFORM_COLOR if p.soft else PLATFORM_COLOR)
	}

	for f, i in game.fighters {
		draw_fighter(f, PLAYER_COLORS[i])
	}

	// HUD
	for f, i in game.fighters {
		x := i32(40 + i * 900)
		rl.DrawText(rl.TextFormat("P%d", i + 1), x, 640, 30, PLAYER_COLORS[i])
		rl.DrawText(rl.TextFormat("%.0f%%   stocks: %d", f.damage, f.stocks), x + 50, 645, 22, rl.RAYWHITE)
		if f.time_scale != 1 {
			rl.DrawText(rl.TextFormat("SLOWED x%.2f", f.time_scale), x + 50, 675, 18, rl.SKYBLUE)
		}
	}
	rl.DrawText("F1: toggle Slow on P2 (debug)", 470, 690, 18, rl.GRAY)
}

draw_fighter :: proc(f: Fighter, color: rl.Color) {
	body := fighter_body(f)
	rl.DrawRectangleRec(body, color)

	// Eye on the facing side, so facing is visible on a plain rectangle.
	eye_x := body.x + body.width - 16 if f.facing > 0 else body.x + 6
	rl.DrawRectangleRec({eye_x, body.y + 14, 10, 10}, rl.RAYWHITE)

	if f.state == .Dash {
		rl.DrawRectangleLinesEx(body, 3, rl.RAYWHITE)
	}

	if box, active := attack_hitbox(f); active {
		rl.DrawRectangleRec(box, HITBOX_COLOR)
	}

	label := MOVE_LABELS[f.move] if f.state == .Attack else STATE_LABELS[f.state]
	rl.DrawText(label, i32(body.x), i32(body.y) - 22, 18, rl.LIGHTGRAY)
}

draw_text_centered :: proc(text: cstring, y: i32, size: i32, color: rl.Color) {
	width := rl.MeasureText(text, size)
	rl.DrawText(text, (SCREEN_WIDTH - width) / 2, y, size, color)
}
