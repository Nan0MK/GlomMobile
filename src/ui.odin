package main

import "core:c"
import rl "../raylib"
import "../../GlomRemastered/rules"

Ui_Action :: enum {
	None,
	Play,
	Help,
	Back,
	Quit,
	Resume,
	Pause_Open,
	Menu,
	Retry,
	OK,
}

Button :: struct {
	Rect: rl.Rectangle,
	Label: cstring,
	Action: Ui_Action,
}

ui_index: int
ui_mouse: [2]f32
ui_mouse_valid: bool

ui_reset :: proc() {
	ui_index = 0
	ui_mouse_valid = false
}

draw_text :: proc(text: cstring, x, y, size: f32, col: rl.Color) {
	if font_custom {
		rl.DrawTextEx(ui_font, text, {x, y}, size, 1, col)
		return
	}
	rl.DrawText(text, c.int(x), c.int(y), c.int(size), col)
}

draw_text_center :: proc(text: cstring, cx, cy, size: f32, col: rl.Color) {
	if font_custom {
		dim := rl.MeasureTextEx(ui_font, text, size, 1)
		rl.DrawTextEx(ui_font, text, {cx - dim.x*0.5, cy - dim.y*0.5}, size, 1, col)
		return
	}
	w := rl.MeasureText(text, c.int(size))
	rl.DrawText(text, c.int(cx)-w/2, c.int(cy-size*0.5), c.int(size), col)
}

draw_button :: proc(r: rl.Rectangle, label: cstring, hot: bool) {
	shadow := r
	shadow.x += 4
	shadow.y += 4
	rl.DrawRectangleRec(shadow, rl.Color{0, 0, 0, 110})
	face := rl.Color{36, 78, 42, 255}
	if hot {
		face = rl.Color{78, 138, 62, 255}
	}
	rl.DrawRectangleRec(r, face)
	rl.DrawRectangleRec({r.x, r.y, r.width, 4}, rl.Color{186, 224, 156, 255})
	edge := rl.Color{12, 28, 14, 255}
	if hot {
		edge = rl.Color{255, 220, 70, 255}
	}
	rl.DrawRectangleLinesEx(r, 3, edge)
	draw_text_center(label, r.x+r.width*0.5, r.y+r.height*0.5+1, 26, rl.WHITE)
}

draw_panel :: proc(r: rl.Rectangle) {
	rl.DrawRectangleRec(r, rl.Color{12, 22, 14, 235})
	rl.DrawRectangleLinesEx(r, 4, rl.Color{0, 128, 0, 255})
}

draw_banner :: proc(r: rl.Rectangle, title: cstring, sub: cstring, has_sub: bool) {
	rl.DrawRectangleRec(r, rl.Color{0, 128, 0, 255})
	rl.DrawRectangleLinesEx(r, 4, rl.Color{190, 255, 170, 255})
	cream := rl.Color{255, 255, 220, 255}
	if has_sub {
		draw_text_center(title, r.x+r.width*0.5, r.y+34, 40, cream)
		draw_text_center(sub, r.x+r.width*0.5, r.y+70, 22, rl.Color{230, 255, 210, 255})
	} else {
		draw_text_center(title, r.x+r.width*0.5, r.y+r.height*0.5, 36, cream)
	}
}

point_in :: proc(p: [2]f32, r: rl.Rectangle) -> bool {
	return p.x >= r.x && p.y >= r.y && p.x < r.x+r.width && p.y < r.y+r.height
}

ui_buttons :: proc(buttons: []Button, mouse: [2]f32, click: bool) -> Ui_Action {
	n := len(buttons)
	if n <= 0 {
		return .None
	}
	if ui_index < 0 || ui_index >= n {
		ui_index = 0
	}

	hovered := -1
	for b, i in buttons {
		if point_in(mouse, b.Rect) {
			hovered = i
		}
	}
	moved := !ui_mouse_valid || mouse != ui_mouse
	ui_mouse = mouse
	ui_mouse_valid = true
	if hovered >= 0 && moved {
		ui_index = hovered
	}

	if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) || rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.A) {
		ui_index = (ui_index + n - 1) % n
	}
	if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) || rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.D) {
		ui_index = (ui_index + 1) % n
	}

	rl.SetMouseCursor(.DEFAULT)
	if hovered >= 0 {
		rl.SetMouseCursor(.POINTING_HAND)
	}

	for b, i in buttons {
		draw_button(b.Rect, b.Label, i == ui_index)
	}

	if click && hovered >= 0 {
		ui_index = hovered
		return buttons[hovered].Action
	}
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		return buttons[ui_index].Action
	}
	return .None
}

draw_menu :: proc(mouse: [2]f32, click: bool) -> Ui_Action {
	draw_backdrop()
	draw_sprite(tex_candy[.Red], 40, 128, 56, 56, 0, rl.WHITE)
	draw_sprite(tex_candy[.Yellow], 40, 196, 56, 56, 0, rl.WHITE)
	draw_sprite(tex_candy[.Peppermint], 40, 470, 56, 56, 0, rl.WHITE)
	draw_sprite(tex_candy[.Blue], 704, 128, 56, 56, 0, rl.WHITE)
	draw_sprite(tex_candy[.Green], 704, 196, 56, 56, 0, rl.WHITE)
	draw_sprite(tex_candy[.Chocolate], 704, 264, 56, 56, 0, rl.WHITE)
	draw_sprite(tex_glom_shadow, 330, 134, 160, 160, 0, rl.WHITE)
	draw_sprite(tex_glom, 320, 124, 160, 160, 0, rl.WHITE)
	draw_sprite(tex_troll_shadow, 640, 440, 110, 110, 0, rl.WHITE)
	draw_sprite(tex_troll, 630, 430, 110, 110, 0, rl.WHITE)

	draw_banner({70, 16, 660, 96}, "Glom Remastered", "The Ugly Creature", true)
	rl.DrawRectangleRec({140, 300, 520, 64}, rl.Color{0, 0, 0, 130})
	draw_text_center("Eat the candies before you explode.", 400, 318, 20, rl.WHITE)
	draw_text_center("W A S D to move", 400, 346, 18, rl.Color{230, 230, 190, 255})

	buttons := [3]Button{
		{{280, 378, 240, 52}, "Play", .Play},
		{{280, 438, 240, 52}, "Help", .Help},
		{{280, 498, 240, 52}, "Quit", .Quit},
	}
	return ui_buttons(buttons[:], mouse, click)
}

draw_help :: proc(mouse: [2]f32, click: bool) -> Ui_Action {
	draw_backdrop()
	draw_banner({50, 16, 700, 72}, "@___Help___@", "", false)
	rl.DrawRectangleRec({32, 100, 736, 400}, rl.Color{0, 0, 0, 145})

	lines := [?]cstring{
		"You are Glom The Ugly Creature.",
		"You must eat as many candies as possible before",
		"Your timer runs out, or you will explode.",
		"There is a troll trying to eat you and your candies.",
		"If you are bigger than the troll you can eat it, but",
		"if the troll is bigger than you it can eat you.",
		"If you eat the troll, you win!",
		"",
		"Chocolate makes your time go down, and you get smaller.",
		"Peppermint makes your time go down a little, but you get bigger.",
		"Other candies make you bigger and add time.",
		"",
		"Move with W A S D. Esc pauses.",
	}
	y: f32 = 114
	ink := rl.Color{255, 255, 230, 255}
	for line in lines {
		if len(string(line)) > 0 {
			draw_text(line, 48, y, 20, ink)
		}
		y += 22
	}

	draw_sprite(tex_candy[.Red], 48, 430, 48, 48, 0, rl.WHITE)
	draw_text("more time", 104, 444, 18, ink)
	draw_sprite(tex_candy[.Chocolate], 280, 430, 48, 48, 0, rl.WHITE)
	draw_text("smaller", 336, 444, 18, ink)
	draw_sprite(tex_candy[.Peppermint], 500, 430, 48, 48, 0, rl.WHITE)
	draw_text("bigger, less time", 556, 444, 18, ink)

	buttons := [1]Button{
		{{280, 516, 240, 52}, "Back", .Back},
	}
	return ui_buttons(buttons[:], mouse, click)
}

draw_pause :: proc(mouse: [2]f32, click: bool) -> Ui_Action {
	rl.DrawRectangleRec({0, 0, f32(rules.WORLD_W), f32(rules.WORLD_H)}, rl.Color{0, 0, 0, 150})
	draw_panel({180, 120, 440, 360})
	draw_text_center("Paused", 400, 170, 40, rl.Color{255, 255, 220, 255})
	buttons := [3]Button{
		{{280, 220, 240, 52}, "Resume", .Resume},
		{{280, 284, 240, 52}, "Help", .Help},
		{{280, 348, 240, 52}, "Main Menu", .Menu},
	}
	return ui_buttons(buttons[:], mouse, click)
}

draw_result :: proc(kind: rules.Result_Kind, mouse: [2]f32, click: bool) -> Ui_Action {
	rl.DrawRectangleRec({0, 0, f32(rules.WORLD_W), f32(rules.WORLD_H)}, rl.Color{0, 0, 0, 140})
	draw_panel({110, 145, 580, 300})

	caption: cstring = ""
	message: cstring = ""
	primary: cstring = "OK"
	primary_action := Ui_Action.OK
	show_menu := true
	color := rl.WHITE
	switch kind {
	case .Win:
		caption = "LOL"
		message = "YOU WINNED"
		primary = "OK"
		primary_action = .OK
		color = rl.Color{130, 255, 130, 255}
	case .Died_Troll:
		caption = "ERROR!!"
		message = "YOU DIED FROM TROLL"
		primary = "Retry"
		primary_action = .Retry
		color = rl.Color{255, 96, 88, 255}
	case .Died_Explode:
		caption = "ERROR!!"
		message = "YOU DIED FROM EXPLODE"
		primary = "Retry"
		primary_action = .Retry
		color = rl.Color{255, 170, 50, 255}
	case .Tie:
		caption = "Cat"
		message = "TIE"
		primary = "OK"
		primary_action = .OK
		show_menu = false
		color = rl.Color{255, 230, 120, 255}
	case .None:
		show_menu = false
	}

	draw_text_center(caption, 400, 190, 22, rl.Color{220, 255, 200, 255})
	draw_text_center(message, 400, 255, 32, color)
	if show_menu {
		buttons := [2]Button{
			{{150, 330, 220, 52}, primary, primary_action},
			{{430, 330, 220, 52}, "Main Menu", .Menu},
		}
		return ui_buttons(buttons[:], mouse, click)
	}
	buttons := [1]Button{
		{{290, 330, 220, 52}, primary, primary_action},
	}
	return ui_buttons(buttons[:], mouse, click)
}
