package main

import "core:fmt"
import rl "../raylib"
import "../../GlomRemastered/rules"

VOICE_CAP :: 4

Voices :: struct {
	base: rl.Sound,
	alias: [VOICE_CAP]rl.Sound,
	count: int,
	next: int,
}

asset_root: string
font_custom: bool
ui_font: rl.Font

tex_bg: rl.Texture2D
tex_glom: rl.Texture2D
tex_glom_shadow: rl.Texture2D
tex_troll: rl.Texture2D
tex_troll_shadow: rl.Texture2D
tex_explode: rl.Texture2D
tex_candy: [rules.Candy_Kind]rl.Texture2D

eat_voices: Voices
bounce_voices: Voices
explode_voices: Voices
click_voices: Voices

find_asset_root :: proc() -> string {
	when ODIN_PLATFORM_SUBTARGET == .Android {
		// Raylib reads these through the APK asset manager. The path is
		// relative to assets/, not a directory on disk.
		return ""
	} else {
		return find_asset_root_desktop()
	}
}

asset_cpath :: proc(rel: string) -> cstring {
	if len(asset_root) == 0 {
		return fmt.caprintf("%s", rel)
	}
	return fmt.caprintf("%s/%s", asset_root, rel)
}

load_texture :: proc(rel: string, mipmaps: bool) -> rl.Texture2D {
	path := asset_cpath(rel)
	defer delete(path)
	img := rl.LoadImage(path)
	if img.data == nil {
		fmt.eprintf("missing image %s\n", rel)
		return {}
	}
	rl.ImageFormat(&img, .UNCOMPRESSED_R8G8B8A8)
	tex := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	if tex.id == 0 {
		fmt.eprintf("could not upload %s\n", rel)
		return {}
	}
	if mipmaps {
		rl.GenTextureMipmaps(&tex)
		rl.SetTextureFilter(tex, .TRILINEAR)
	} else {
		rl.SetTextureFilter(tex, .BILINEAR)
	}
	return tex
}

load_window_icon :: proc() {
	path := asset_cpath("resources/glom.png")
	defer delete(path)
	img := rl.LoadImage(path)
	if img.data == nil {
		return
	}
	rl.ImageFormat(&img, .UNCOMPRESSED_R8G8B8A8)
	rl.SetWindowIcon(img)
	rl.UnloadImage(img)
}

init_textures :: proc() {
	tex_bg = load_texture("resources/bg.png", false)
	tex_glom = load_texture("resources/glom.png", true)
	tex_glom_shadow = load_texture("resources/glom_shadow.png", true)
	tex_troll = load_texture("resources/troll.png", true)
	tex_troll_shadow = load_texture("resources/troll_shadow.png", true)
	tex_explode = load_texture("resources/explosion/explode.png", false)
	tex_candy[.Red] = load_texture("resources/candy_red.png", true)
	tex_candy[.Blue] = load_texture("resources/candy_blue.png", true)
	tex_candy[.Green] = load_texture("resources/candy_green.png", true)
	tex_candy[.Yellow] = load_texture("resources/candy_yellow.png", true)
	tex_candy[.Peppermint] = load_texture("resources/candy_peppermint.png", true)
	tex_candy[.Chocolate] = load_texture("resources/candy_chocolate.png", true)
}

unload_tex :: proc(tex: ^rl.Texture2D) {
	if tex.id != 0 {
		rl.UnloadTexture(tex^)
		tex^ = {}
	}
}

shutdown_textures :: proc() {
	unload_tex(&tex_bg)
	unload_tex(&tex_glom)
	unload_tex(&tex_glom_shadow)
	unload_tex(&tex_troll)
	unload_tex(&tex_troll_shadow)
	unload_tex(&tex_explode)
	for kind in rules.Candy_Kind {
		unload_tex(&tex_candy[kind])
	}
}

init_font :: proc() {
	// Same face on the desktop and in the APK. The file is packed with the
	// other resources; it is not a Windows font.
	path := asset_cpath("resources/RDF-Regular.ttf")
	defer delete(path)
	ui_font = rl.LoadFontEx(path, 64, nil, 0)
	default_font := rl.GetFontDefault()
	if ui_font.texture.id != 0 && ui_font.texture.id != default_font.texture.id {
		rl.SetTextureFilter(ui_font.texture, .BILINEAR)
		font_custom = true
		return
	}
	fmt.eprintf("missing font resources/RDF-Regular.ttf\n")
	font_custom = false
}

shutdown_font :: proc() {
	if font_custom && ui_font.texture.id != 0 {
		rl.UnloadFont(ui_font)
		ui_font = {}
		font_custom = false
	}
}

load_voices :: proc(rel: string, n: int) -> Voices {
	v: Voices
	path := asset_cpath(rel)
	defer delete(path)
	v.base = rl.LoadSound(path)
	if !rl.IsSoundValid(v.base) {
		fmt.eprintf("missing sound %s\n", rel)
		return v
	}
	count := n
	if count > VOICE_CAP {
		count = VOICE_CAP
	}
	if count < 1 {
		count = 1
	}
	for i in 0..<count {
		v.alias[i] = rl.LoadSoundAlias(v.base)
	}
	v.count = count
	return v
}

play_voices :: proc(v: ^Voices) {
	if v.count <= 0 {
		return
	}
	for i in 0..<v.count {
		if !rl.IsSoundPlaying(v.alias[i]) {
			rl.PlaySound(v.alias[i])
			return
		}
	}
	rl.PlaySound(v.alias[v.next])
	v.next += 1
	if v.next >= v.count {
		v.next = 0
	}
}

unload_voices :: proc(v: ^Voices) {
	for i in 0..<v.count {
		rl.UnloadSoundAlias(v.alias[i])
	}
	v.count = 0
	if rl.IsSoundValid(v.base) {
		rl.UnloadSound(v.base)
		v.base = {}
	}
}

init_audio :: proc() {
	rl.InitAudioDevice()
	if !rl.IsAudioDeviceReady() {
		fmt.eprintf("audio device failed\n")
		return
	}
	eat_voices = load_voices("resources/sounds/eat.wav", 4)
	bounce_voices = load_voices("resources/sounds/bounce.wav", 2)
	explode_voices = load_voices("resources/sounds/explode.wav", 1)
	click_voices = load_voices("resources/sounds/click.wav", 1)
}

shutdown_audio :: proc() {
	unload_voices(&eat_voices)
	unload_voices(&bounce_voices)
	unload_voices(&explode_voices)
	unload_voices(&click_voices)
	if rl.IsAudioDeviceReady() {
		rl.CloseAudioDevice()
	}
}
