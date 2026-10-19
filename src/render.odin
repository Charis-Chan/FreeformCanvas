package main

import rl "vendor:raylib"

// Pass 2: drawing only. Everything here reads the game; nothing changes it.
// The loaded assets (font) are passed in read-only too.

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
	.Down_Aerial     = "DOWN AERIAL",
}

TEXT_SPACING :: 1

render :: proc(game: Game, assets: Assets) {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(BACKGROUND_COLOR)

	switch game.state {
	case .Title:
		draw_text_centered(assets, "FREEFORM CANVAS", 240, 72, rl.RAYWHITE)
		draw_text_centered(assets, "Press ENTER to start", 360, 28, rl.LIGHTGRAY)
	case .Match:
		draw_match(game, assets)
	case .Results:
		draw_text_centered(assets, rl.TextFormat("PLAYER %d WINS", game.winner + 1), 260, 64, PLAYER_COLORS[game.winner])
		draw_text_centered(assets, "Press ENTER to return to title", 360, 28, rl.LIGHTGRAY)
	}

	if game.reload_message_left > 0 {
		color := rl.GREEN if game.reload_message_good else rl.RED
		draw_text_centered(assets, game.reload_message, 16, 22, color)
	}
}

draw_match :: proc(game: Game, assets: Assets) {
	for p in game.stage.platforms {
		rl.DrawRectangleRec(p.rect, SOFT_PLATFORM_COLOR if p.soft else PLATFORM_COLOR)
	}

	for f, i in game.fighters {
		draw_fighter(f, PLAYER_COLORS[i], assets)
	}

	// HUD
	for f, i in game.fighters {
		x := f32(40 + i * 900)
		name := rl.TextFormat("P%d %s", i + 1, f.character.display_name)
		draw_text(assets, name, x, 600, 30, PLAYER_COLORS[i])
		draw_text(assets, rl.TextFormat("%.0f%%   stocks: %d", f.damage, f.stocks), x, 640, 22, rl.RAYWHITE)
		if f.time_scale != 1 {
			draw_text(assets, rl.TextFormat("SLOWED x%.2f", f.time_scale), x, 670, 18, rl.SKYBLUE)
		}
	}
	draw_text_centered(assets, "F1: toggle Slow on P2   F5: reload data (debug)", 690, 18, rl.GRAY)
}

draw_fighter :: proc(f: Fighter, color: rl.Color, assets: Assets) {
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
	draw_text(assets, label, body.x, body.y - 22, 18, rl.LIGHTGRAY)
}

draw_text :: proc(assets: Assets, text: cstring, x, y, size: f32, color: rl.Color) {
	rl.DrawTextEx(assets.font, text, {x, y}, size, TEXT_SPACING, color)
}

draw_text_centered :: proc(assets: Assets, text: cstring, y, size: f32, color: rl.Color) {
	width := rl.MeasureTextEx(assets.font, text, size, TEXT_SPACING).x
	draw_text(assets, text, (SCREEN_WIDTH - width) / 2, y, size, color)
}
