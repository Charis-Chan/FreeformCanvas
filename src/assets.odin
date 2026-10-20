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
	Hit, // played once hits exist (collision week)
	KO,
}

SOUND_FILES := [Sound_Id]cstring {
	.Jump = "assets/sounds/jump.ogg",
	.Hit  = "assets/sounds/hit.ogg",
	.KO   = "assets/sounds/ko.ogg",
}

// A spritesheet: frames of equal size side by side in one row.
// Draw it white/light grey so render can tint it per player.
Sprite :: struct {
	texture:     rl.Texture2D,
	frame_count: i32,
	faces_right: bool, // which way the art faces; mirrored when the fighter faces the other way
	scale:       f32,  // art pixels -> screen pixels (whole numbers keep pixels sharp)
}

// Placeholder until the real character art exists (Task 5).
FIGHTER_SPRITE_FILE :: "assets/sprites/placeholder/hero.png"
FIGHTER_SPRITE_FRAMES :: 1
FIGHTER_SPRITE_FACES_RIGHT :: true
FIGHTER_SPRITE_SCALE :: 5

Assets :: struct {
	font:   rl.Font,
	sounds: [Sound_Id]rl.Sound,
	// One texture shared by both fighters; render tints it per player.
	fighter_sprite: Sprite,
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
	}

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
	}
	return a, true
}

assets_unload :: proc(a: ^Assets) {
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
		if .KO in f.events do play_sound(assets, .KO)
		f.events = {}
	}
}

// Plays nothing when running without an audio device.
play_sound :: proc(assets: Assets, id: Sound_Id) {
	if rl.IsSoundValid(assets.sounds[id]) do rl.PlaySound(assets.sounds[id])
}
