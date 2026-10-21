package main

import rl "vendor:raylib"

// Pass 2: drawing only. Everything here reads the game; nothing changes it.
// The loaded assets (font, sprites) are passed in read-only too.

// Training-stage look: mid grey with a light grid.
BACKGROUND_COLOR    :: rl.Color{110, 110, 125, 255}
GRID_COLOR          :: rl.Color{200, 200, 208, 255}
GRID_SPACING        :: 48 // screen px = 16 art px at 3x
PLATFORM_COLOR      :: rl.Color{48, 48, 62, 255}
PLATFORM_EDGE_COLOR :: rl.Color{230, 230, 238, 255}
SOFT_PLATFORM_COLOR :: rl.Color{70, 70, 88, 255}
SOFT_EDGE_COLOR     :: rl.Color{200, 200, 215, 255}
HUD_PANEL_COLOR     :: rl.Color{20, 20, 28, 170}
TEXT_SHADOW_COLOR   :: rl.Color{0, 0, 0, 200}
HITBOX_COLOR        :: rl.Color{255, 60, 60, 140}
BODY_BOX_COLOR      :: rl.Color{255, 255, 0, 160}

// Chosen to stay clear of Lucy's pink, teal, gold and dark purple.
// Provisional: change freely.
PLAYER_COLORS := [2]rl.Color {
	{70, 150, 255, 255}, // P1 blue
	{140, 220, 40, 255}, // P2 lime
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

// Which animation each attack uses.
MOVE_ANIMS := [Move]Anim {
	.Jab             = .Jab,
	.Side_Strong     = .Side_Strong,
	.Neutral_Special = .Neutral_Special,
	.Forward_Aerial  = .Forward_Aerial,
	.Up_Aerial       = .Up_Aerial,
	.Down_Aerial     = .Down_Aerial,
}

TEXT_SPACING :: 1

render :: proc(game: Game, assets: Assets) {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	draw_background()

	switch game.state {
	case .Title:
		draw_text_centered(assets, "FREEFORM CANVAS", 240, 72, rl.RAYWHITE)
		draw_text_centered(assets, "Press ENTER to start", 360, 28, rl.RAYWHITE)
	case .Match:
		draw_match(game, assets)
	case .Results:
		draw_text_centered(assets, rl.TextFormat("PLAYER %d WINS", game.winner + 1), 260, 64, PLAYER_COLORS[game.winner])
		draw_text_centered(assets, "Press ENTER to return to title", 360, 28, rl.RAYWHITE)
	}

	if game.reload_message_left > 0 {
		color := rl.GREEN if game.reload_message_good else rl.RED
		draw_text_centered(assets, game.reload_message, 16, 22, color)
	}
}

draw_background :: proc() {
	rl.ClearBackground(BACKGROUND_COLOR)
	for x: i32 = 0; x < SCREEN_WIDTH; x += GRID_SPACING {
		rl.DrawLine(x, 0, x, SCREEN_HEIGHT, GRID_COLOR)
	}
	for y: i32 = 0; y < SCREEN_HEIGHT; y += GRID_SPACING {
		rl.DrawLine(0, y, SCREEN_WIDTH, y, GRID_COLOR)
	}
}

draw_match :: proc(game: Game, assets: Assets) {
	for p in game.stage.platforms {
		fill := SOFT_PLATFORM_COLOR if p.soft else PLATFORM_COLOR
		edge := SOFT_EDGE_COLOR if p.soft else PLATFORM_EDGE_COLOR
		rl.DrawRectangleRec(p.rect, fill)
		// Bright top line so the standing surface reads clearly.
		rl.DrawRectangleRec({p.rect.x, p.rect.y, p.rect.width, 3}, edge)
	}

	for f, i in game.fighters {
		draw_fighter(f, i, assets, game.show_boxes)
	}

	// HUD, on dark panels so it reads on the grey background.
	for f, i in game.fighters {
		x := f32(40 + i * 900)
		rl.DrawRectangleRec({x - 12, 592, 300, 110}, HUD_PANEL_COLOR)
		name := rl.TextFormat("P%d %s", i + 1, f.character.display_name)
		draw_text(assets, name, x, 600, 30, PLAYER_COLORS[i])
		draw_text(assets, rl.TextFormat("%.0f%%   stocks: %d", f.damage, f.stocks), x, 640, 22, rl.RAYWHITE)
		if f.time_scale != 1 {
			draw_text(assets, rl.TextFormat("SLOWED x%.2f", f.time_scale), x, 670, 18, rl.SKYBLUE)
		}
	}
	draw_text_centered(assets, "F1: Slow on P2   F2: show boxes   F5: reload data   (debug)", 694, 16, rl.RAYWHITE)
}

draw_fighter :: proc(f: Fighter, player: int, assets: Assets, show_boxes: bool) {
	color := PLAYER_COLORS[player]
	body := fighter_body(f)

	// Real art if this character has this animation, else the placeholder.
	// Real art is full colour, so it is drawn untinted (WHITE = no change).
	anim := fighter_anim(f)
	art := assets.character_sprites[f.character.id][anim]
	if rl.IsTextureValid(art.texture) {
		draw_sprite(art, anim_frame(f, anim, art.frame_count), f.pos, f.facing, rl.WHITE)
	} else {
		draw_sprite(assets.fighter_sprite, 0, f.pos, f.facing, color)
	}

	if show_boxes {
		rl.DrawRectangleLinesEx(body, 2, BODY_BOX_COLOR)
		if box, active := attack_hitbox(f); active {
			rl.DrawRectangleRec(box, HITBOX_COLOR)
		}
		// Debug state label under the feet, out of the way of the tag.
		label := MOVE_LABELS[f.move] if f.state == .Attack else STATE_LABELS[f.state]
		width := rl.MeasureTextEx(assets.font, label, 16, TEXT_SPACING).x
		draw_text(assets, label, f.pos.x - width / 2, f.pos.y + 6, 16, rl.RAYWHITE)
	}
	if f.state == .Dash {
		rl.DrawRectangleLinesEx(body, 3, rl.RAYWHITE)
	}

	// P1 / P2 tag above the head, always on.
	tag := rl.TextFormat("P%d", player + 1)
	tag_width := rl.MeasureTextEx(assets.font, tag, 22, TEXT_SPACING).x
	draw_text(assets, tag, f.pos.x - tag_width / 2, body.y - 30, 22, color)
}

// Which animation a fighter's current state shows.
fighter_anim :: proc(f: Fighter) -> Anim {
	switch f.state {
	case .Idle:     return .Idle
	case .Walk:     return .Walk
	case .Run:      return .Run
	case .Airborne: return .Jump_Rise if f.vel.y < 0 else .Jump_Fall
	case .Dash:     return .Dash
	case .Attack:   return MOVE_ANIMS[f.move]
	case .Hitstun:  return .Hitstun
	}
	return .Idle
}

// Which art frame to show. Attacks follow their frame data: frame 0 during
// startup, frame 1 while the hitbox is active, the rest spread over recovery,
// so changing a move's timing in data never desyncs the art. Everything else
// loops at the animation's ticks_per_frame from the character file.
anim_frame :: proc(f: Fighter, anim: Anim, frame_count: i32) -> i32 {
	if frame_count <= 1 do return 0

	if f.state == .Attack {
		a := f.character.moves[f.move]
		t := f.state_frame
		if t < a.startup do return 0
		if t < a.startup + a.active || frame_count == 2 do return 1
		recovery_frames := int(frame_count) - 2
		into_recovery := t - a.startup - a.active
		frame := 2 + into_recovery * recovery_frames / max(a.recovery, 1)
		return i32(min(frame, int(frame_count) - 1))
	}

	ticks := f.character.animations[anim].ticks_per_frame
	if ticks <= 0 do ticks = DEFAULT_TICKS_PER_FRAME
	return i32((f.state_frame / ticks) % int(frame_count))
}

// Text with a small drop shadow so it reads on any background.
draw_text :: proc(assets: Assets, text: cstring, x, y, size: f32, color: rl.Color) {
	rl.DrawTextEx(assets.font, text, {x + 2, y + 2}, size, TEXT_SPACING, TEXT_SHADOW_COLOR)
	rl.DrawTextEx(assets.font, text, {x, y}, size, TEXT_SPACING, color)
}

draw_text_centered :: proc(assets: Assets, text: cstring, y, size: f32, color: rl.Color) {
	width := rl.MeasureTextEx(assets.font, text, size, TEXT_SPACING).x
	draw_text(assets, text, (SCREEN_WIDTH - width) / 2, y, size, color)
}

// Draws one frame of a sprite so its feet row lands on `feet` and its
// horizontal centre on feet.x, mirrored when the fighter faces the opposite
// way to the art. Rows below the feet row (down-aerial legs) hang below.
draw_sprite :: proc(s: Sprite, frame: i32, feet: Vec2, facing: f32, tint: rl.Color) {
	fw, fh := sprite_frame_size(s)
	source := rl.Rectangle{f32(frame) * fw, 0, fw, fh}
	art_facing: f32 = 1 if s.faces_right else -1
	if facing != art_facing do source.width = -fw // negative width = mirrored

	w, h := fw * s.scale, fh * s.scale
	top := feet.y - f32(s.feet_row + 1) * s.scale
	dest := rl.Rectangle{feet.x - w / 2, top, w, h}
	rl.DrawTexturePro(s.texture, source, dest, {0, 0}, 0, tint)
}
