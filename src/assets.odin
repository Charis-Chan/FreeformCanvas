package main

import "core:fmt"
import rl "vendor:raylib"

// Every file the game loads from assets/. Each is loaded exactly once at
// startup into one Assets value, shared by reference with whatever needs it
// (render for the font, the audio pass for sounds), and unloaded once at exit.
// Rename your files to match these paths, or change the paths here.

FONT_FILE :: "assets/fonts/main.ttf"
FONT_LOAD_SIZE :: 64 // pixel size the font is rasterised at; drawn smaller looks sharp

Sound_Id :: enum {
	Jump,
	Hit,
	KO,
}

SOUND_FILES := [Sound_Id]cstring {
	.Jump = "assets/sounds/jump.ogg",
	.Hit  = "assets/sounds/hit.ogg",
	.KO   = "assets/sounds/ko.ogg",
}

SOUND_VOLUMES := [Sound_Id]f32 {
	.Jump = 1,
	.Hit  = 0.5,
	.KO   = 0.75,
}

// A spritesheet: frames of equal size side by side in one row.
// Draw it white/light grey so render can tint it per player.
Sprite :: struct {
	texture:     rl.Texture2D,
	frame_count: i32,
	faces_right: bool, // which way the art faces; mirrored when the fighter faces the other way
	scale:       f32,  // art pixels -> screen pixels (whole numbers keep pixels sharp)
	feet_row:    i32,  // pixel row (0 = top) holding the lowest foot pixel; drawn at the fighter's feet
}

// Character art (see docs/sprite_spec.md): one PNG per animation, 64x64
// frames in one row, shown at 3x, facing right, lowest foot pixel on row 51.
ART_FRAME_SIZE :: 64
ART_SCALE :: 3
ART_FEET_ROW :: 51

// Every animation a character can have. A missing file falls back to the
// placeholder, so art can be added one animation at a time.
Anim :: enum {
	Idle,
	Walk,
	Run,
	Run_Turnaround,
	Jump_Squat,
	Jump_Rise,
	Jump_Fall,
	Double_Jump,
	Dash,
	Shield,
	Jab,
	Side_Strong,
	Neutral_Special,
	Forward_Aerial,
	Up_Aerial,
	Down_Aerial,
	Hitstun,
	Stunned,
}

// File names inside assets/sprites/<character>/.
ANIM_FILES := [Anim]string {
	.Idle            = "idle",
	.Walk            = "walk",
	.Run             = "run",
	.Run_Turnaround  = "run_turnaround",
	.Jump_Squat      = "jump_squat",
	.Jump_Rise       = "jump_rise",
	.Jump_Fall       = "jump_fall",
	.Double_Jump     = "double_jump",
	.Dash            = "dash",
	.Shield          = "shield",
	.Jab             = "jab",
	.Side_Strong     = "side_strong",
	.Neutral_Special = "neutral_special",
	.Forward_Aerial  = "forward_aerial",
	.Up_Aerial       = "up_aerial",
	.Down_Aerial     = "down_aerial",
	.Hitstun         = "hitstun",
	.Stunned         = "stunned",
}

CHARACTER_FOLDERS := [Character_Id]string {
	.Lucy  = "lucy",
	.David = "david",
}

// Placeholder for any animation that has no art yet.
FIGHTER_SPRITE_FILE :: "assets/sprites/placeholder/hero.png"
FIGHTER_SPRITE_FRAMES :: 1
FIGHTER_SPRITE_FACES_RIGHT :: true
FIGHTER_SPRITE_SCALE :: 5
FIGHTER_SPRITE_FEET_ROW :: 15 // placeholder is 16 px tall, feet on its last row; real art uses 51

Assets :: struct {
	font:   rl.Font,
	sounds: [Sound_Id]rl.Sound,
	// Placeholder shared by everyone; render tints it per player.
	fighter_sprite: Sprite,
	// Real art, loaded once and shared by every fighter using that character.
	// A sprite with an invalid texture means "no art yet, use the placeholder".
	character_sprites: [Character_Id][Anim]Sprite,
}

sprite_frame_size :: proc(s: Sprite) -> (w, h: f32) {
	return f32(s.texture.width / s.frame_count), f32(s.texture.height)
}

// Needs the window and audio device to exist already.
assets_load :: proc() -> (a: Assets, ok: bool) {
	a.font = rl.LoadFontEx(FONT_FILE, FONT_LOAD_SIZE, nil, 0)
	if !rl.IsFontValid(a.font) || a.font.texture.id == rl.GetFontDefault().texture.id {
		fmt.eprintln("Could not load font", FONT_FILE)
		assets_unload(&a)
		return
	}

	tex := rl.LoadTexture(FIGHTER_SPRITE_FILE)
	if !rl.IsTextureValid(tex) {
		fmt.eprintln("Could not load sprite", FIGHTER_SPRITE_FILE)
		assets_unload(&a)
		return
	}
	rl.SetTextureFilter(tex, .POINT) // keep pixel art sharp when scaled up
	a.fighter_sprite = Sprite {
		texture     = tex,
		frame_count = FIGHTER_SPRITE_FRAMES,
		faces_right = FIGHTER_SPRITE_FACES_RIGHT,
		scale       = FIGHTER_SPRITE_SCALE,
		feet_row    = FIGHTER_SPRITE_FEET_ROW,
	}

	for folder, id in CHARACTER_FOLDERS {
		for file, anim in ANIM_FILES {
			path := fmt.ctprintf("assets/sprites/%s/%s_%s.png", folder, folder, file)
			if !rl.FileExists(path) do continue // not drawn yet: placeholder
			sprite, loaded := load_art_sprite(path)
			if !loaded {
				assets_unload(&a)
				return
			}
			a.character_sprites[id][anim] = sprite
		}
	}
	free_all(context.temp_allocator) // the formatted paths above

	// No audio device (broken drivers, no speakers) is not fatal: the game
	// runs silently. A missing or broken sound file is, so typos get noticed.
	if !rl.IsAudioDeviceReady() {
		fmt.eprintln("No audio device available - running without sound")
		return a, true
	}
	for path, id in SOUND_FILES {
		a.sounds[id] = rl.LoadSound(path)
		if !rl.IsSoundValid(a.sounds[id]) {
			fmt.eprintln("Could not load sound", path)
			assets_unload(&a)
			return
		}
		rl.SetSoundVolume(a.sounds[id], SOUND_VOLUMES[id])
	}
	return a, true
}

// Loads one animation strip that follows the sprite spec.
load_art_sprite :: proc(path: cstring) -> (s: Sprite, ok: bool) {
	tex := rl.LoadTexture(path)
	if !rl.IsTextureValid(tex) {
		fmt.eprintln("Could not load sprite", path)
		return
	}
	if tex.height != ART_FRAME_SIZE || tex.width % ART_FRAME_SIZE != 0 {
		fmt.eprintf("%s is %dx%d; expected %d px tall and a multiple of %d wide (see docs/sprite_spec.md)\n",
			path, tex.width, tex.height, ART_FRAME_SIZE, ART_FRAME_SIZE)
		rl.UnloadTexture(tex)
		return
	}
	rl.SetTextureFilter(tex, .POINT)
	return Sprite {
		texture     = tex,
		frame_count = tex.width / ART_FRAME_SIZE,
		faces_right = true,
		scale       = ART_SCALE,
		feet_row    = ART_FEET_ROW,
	}, true
}

assets_unload :: proc(a: ^Assets) {
	for &anims in a.character_sprites {
		for s in anims do if rl.IsTextureValid(s.texture) do rl.UnloadTexture(s.texture)
	}
	if rl.IsTextureValid(a.fighter_sprite.texture) do rl.UnloadTexture(a.fighter_sprite.texture)
	for sound in a.sounds {
		if rl.IsSoundValid(sound) do rl.UnloadSound(sound)
	}
	if rl.IsFontValid(a.font) && a.font.texture.id != rl.GetFontDefault().texture.id {
		rl.UnloadFont(a.font)
	}
	a^ = {}
}

// Audio pass: runs once per screen frame after update. Plays a sound for
// each event the fighters recorded during this frame's ticks, then clears
// them, so a sound plays once even if several ticks ran this frame.
play_fighter_sounds :: proc(game: ^Game, assets: Assets) {
	for &f in game.fighters {
		if .Jumped in f.events do play_sound(assets, .Jump)
		if .Hit in f.events do play_sound(assets, .Hit)
		if .KO in f.events do play_sound(assets, .KO)
		f.events = {}
	}
}

// Plays nothing when running without an audio device.
play_sound :: proc(assets: Assets, id: Sound_Id) {
	if rl.IsSoundValid(assets.sounds[id]) do rl.PlaySound(assets.sounds[id])
}
