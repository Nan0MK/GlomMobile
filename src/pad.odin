package main

import "core:c"
import rl "../raylib"
import "../../GlomRemastered/rules"

// The pad sits in screen space, in the width the 4:3 world does not use.
// Direction buttons are held. Pause matches Escape.

PAD_SLOTS :: 8

Pad :: struct {
	bounds: rl.Rectangle,
	left, right, up, down, pause: rl.Rectangle,
	hold_left, hold_right, hold_up, hold_down: bool,
	pause_pressed: bool,
}

prev_ids: [PAD_SLOTS]c.int
prev_n: int

layout_pad :: proc(screen_w, screen_h: f32) -> (pad: Pad, play: rl.Rectangle) {
	btn := screen_h * 0.16
	if btn < 64 {
		btn = 64
	}
	if btn > 140 {
		btn = 140
	}
	gap := btn * 0.18
	pad_w := btn*3 + gap*4
	max_w := screen_w * 0.38
	if pad_w > max_w {
		pad_w = max_w
		btn = (pad_w - gap*4) / 3
		if btn < 48 {
			btn = 48
		}
	}
	pad.bounds = {screen_w - pad_w, 0, pad_w, screen_h}
	cx := pad.bounds.x + pad_w*0.5
	cy := screen_h * 0.56
	pad.up = {cx - btn*0.5, cy - btn - gap, btn, btn}
	pad.down = {cx - btn*0.5, cy + gap, btn, btn}
	pad.left = {cx - btn*1.5 - gap, cy - btn*0.5, btn, btn}
	pad.right = {cx + btn*0.5 + gap, cy - btn*0.5, btn, btn}
	pw := btn * 1.8
	if pw > pad_w - gap*2 {
		pw = pad_w - gap*2
	}
	ph := btn * 0.62
	pad.pause = {pad.bounds.x + (pad_w-pw)*0.5, screen_h * 0.08, pw, ph}
	play = {0, 0, screen_w - pad_w, screen_h}
	return
}

fit_inside :: proc(area: rl.Rectangle) -> rl.Rectangle {
	if area.width < 1 || area.height < 1 {
		return {0, 0, f32(rules.WORLD_W), f32(rules.WORLD_H)}
	}
	scale := area.width / f32(rules.WORLD_W)
	sy := area.height / f32(rules.WORLD_H)
	if sy < scale {
		scale = sy
	}
	w := f32(rules.WORLD_W) * scale
	h := f32(rules.WORLD_H) * scale
	return {
		area.x + (area.width-w)*0.5,
		area.y + (area.height-h)*0.5,
		w,
		h,
	}
}

pad_contains :: proc(x, y: f32, r: rl.Rectangle) -> bool {
	return x >= r.x && y >= r.y && x < r.x+r.width && y < r.y+r.height
}

touch_is_new :: proc(id: c.int) -> bool {
	for i in 0..<prev_n {
		if prev_ids[i] == id {
			return false
		}
	}
	return true
}

remember_touches :: proc(ids: []c.int) {
	prev_n = len(ids)
	if prev_n > PAD_SLOTS {
		prev_n = PAD_SLOTS
	}
	for i in 0..<prev_n {
		prev_ids[i] = ids[i]
	}
}

// One finger can hold a direction. A new finger on Pause acts like Escape.
// A new finger on the picture is a menu click. Mouse is the stand-in when
// the device reports no touches, so the same shell can be tried on the desktop.
sample_pad :: proc(pad: ^Pad, dst: rl.Rectangle) -> (mouse: [2]f32, click: bool) {
	pad.hold_left = false
	pad.hold_right = false
	pad.hold_up = false
	pad.hold_down = false
	pad.pause_pressed = false
	mouse = {-1, -1}

	touches := int(rl.GetTouchPointCount())
	if touches > 0 {
		ids: [PAD_SLOTS]c.int
		n := touches
		if n > PAD_SLOTS {
			n = PAD_SLOTS
		}
		for i in 0..<n {
			id := rl.GetTouchPointId(c.int(i))
			ids[i] = id
			p := rl.GetTouchPosition(c.int(i))
			began := touch_is_new(id)
			if pad_contains(p.x, p.y, pad.left) {
				pad.hold_left = true
			} else if pad_contains(p.x, p.y, pad.right) {
				pad.hold_right = true
			} else if pad_contains(p.x, p.y, pad.up) {
				pad.hold_up = true
			} else if pad_contains(p.x, p.y, pad.down) {
				pad.hold_down = true
			} else if pad_contains(p.x, p.y, pad.pause) {
				if began {
					pad.pause_pressed = true
				}
			} else if pad_contains(p.x, p.y, dst) {
				mouse = world_mouse(dst, p)
				if began {
					click = true
				}
			}
		}
		remember_touches(ids[:n])
		return
	}

	remember_touches(nil)
	// No touches: a mouse drives the same pad, so this shell can be tried on Windows.
	// The cursor tracks the picture for menu hover. A click is only the press frame.
	down := rl.IsMouseButtonDown(.LEFT)
	pressed := rl.IsMouseButtonPressed(.LEFT)
	p := rl.GetMousePosition()
	if pad_contains(p.x, p.y, pad.left) {
		pad.hold_left = down
	} else if pad_contains(p.x, p.y, pad.right) {
		pad.hold_right = down
	} else if pad_contains(p.x, p.y, pad.up) {
		pad.hold_up = down
	} else if pad_contains(p.x, p.y, pad.down) {
		pad.hold_down = down
	} else if pad_contains(p.x, p.y, pad.pause) {
		pad.pause_pressed = pressed
	} else if pad_contains(p.x, p.y, dst) {
		mouse = world_mouse(dst, p)
		click = pressed
	}
	return
}

world_mouse :: proc(dst: rl.Rectangle, mp: rl.Vector2) -> (m: [2]f32) {
	if dst.width <= 0 || dst.height <= 0 {
		return {-1, -1}
	}
	m.x = (mp.x - dst.x) * f32(rules.WORLD_W) / dst.width
	m.y = (mp.y - dst.y) * f32(rules.WORLD_H) / dst.height
	if m.x < 0 || m.y < 0 || m.x >= f32(rules.WORLD_W) || m.y >= f32(rules.WORLD_H) {
		return {-1, -1}
	}
	return
}

draw_pad :: proc(pad: Pad) {
	rl.DrawRectangleRec(pad.bounds, rl.Color{12, 16, 14, 255})
	rl.DrawRectangleRec({pad.bounds.x, 0, 4, pad.bounds.height}, rl.Color{0, 70, 0, 255})
	draw_dir(pad.up, pad.hold_up, "U")
	draw_dir(pad.down, pad.hold_down, "D")
	draw_dir(pad.left, pad.hold_left, "L")
	draw_dir(pad.right, pad.hold_right, "R")
	draw_button(pad.pause, "Pause", pad.pause_pressed)
}

draw_dir :: proc(r: rl.Rectangle, hot: bool, label: cstring) {
	draw_button(r, label, hot)
}
