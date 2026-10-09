package main

import "core:fmt"
import rl "../raylib"
import "../../GlomRemastered/rules"

draw_sprite :: proc(tex: rl.Texture2D, x, y, w, h, rotation: f32, tint: rl.Color) {
	if tex.id == 0 || w <= 0 || h <= 0 {
		return
	}
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	dst := rl.Rectangle{x + w*0.5, y + h*0.5, w, h}
	origin := rl.Vector2{w*0.5, h*0.5}
	rl.DrawTexturePro(tex, src, dst, origin, rotation, tint)
}

draw_backdrop :: proc() {
	rl.ClearBackground(rl.Color{0, 0, 255, 255})
	draw_sprite(tex_bg, 0, 0, f32(rules.WORLD_W), f32(rules.WORLD_H), 0, rl.WHITE)
}

draw_actor :: proc(tex, shadow: rl.Texture2D, a: rules.Actor, fallback: rl.Color) {
	if !a.Alive || a.W <= 0 || a.H <= 0 {
		return
	}
	w := f32(a.W)
	h := f32(a.H)
	draw_sprite(shadow, a.X+10, a.Y+10, w, h, a.Rotation, rl.WHITE)
	if tex.id == 0 {
		rl.DrawRectangleRec({a.X, a.Y, w, h}, fallback)
		return
	}
	draw_sprite(tex, a.X, a.Y, w, h, a.Rotation, rl.WHITE)
}

candy_fallback :: proc(kind: rules.Candy_Kind) -> rl.Color {
	switch kind {
	case .Red:
		return rl.Color{220, 30, 30, 255}
	case .Blue:
		return rl.Color{30, 80, 220, 255}
	case .Green:
		return rl.Color{30, 180, 50, 255}
	case .Yellow:
		return rl.Color{230, 200, 20, 255}
	case .Peppermint:
		return rl.Color{230, 80, 110, 255}
	case .Chocolate:
		return rl.Color{120, 60, 20, 255}
	}
	return rl.WHITE
}

draw_world :: proc(g: ^rules.Game) {
	draw_backdrop()
	for c in g.Candies {
		if !c.Alive {
			continue
		}
		tex := tex_candy[c.Kind]
		if tex.id == 0 {
			rl.DrawRectangleRec({c.X, c.Y, rules.CANDY_SIZE, rules.CANDY_SIZE}, candy_fallback(c.Kind))
		} else {
			draw_sprite(tex, c.X, c.Y, rules.CANDY_SIZE, rules.CANDY_SIZE, 0, rl.WHITE)
		}
	}
	draw_actor(tex_glom, tex_glom_shadow, g.Player, rl.Color{40, 160, 40, 255})
	draw_actor(tex_troll, tex_troll_shadow, g.Troll, rl.WHITE)
	if g.Exploded {
		draw_explosion(g.Player.X, g.Player.Y)
	}
	if g.Player.X < 9000 {
		draw_timer(g.Player)
	}
}

draw_explosion :: proc(x, y: f32) {
	if tex_explode.id == 0 {
		rl.DrawRectangleRec({x - 80, y - 80, 200, 200}, rl.Color{255, 140, 0, 255})
		return
	}
	draw_sprite(tex_explode, x-200, y-200, f32(tex_explode.width), f32(tex_explode.height), 0, rl.WHITE)
}

draw_timer :: proc(a: rules.Actor) {
	label := fmt.ctprintf("%d", a.Time)
	size :: f32(40)
	// Sit above Glom when there is room. At the top of the wall, sit to the right
	// so the number does not cover the sprite.
	x := a.X
	y := a.Y - size - 6
	if y < 8 {
		x = a.X + f32(a.W) + 8
		y = a.Y
	}
	est := size * 0.62 * f32(len(string(label)))
	if est < size {
		est = size
	}
	if x < 8 {
		x = 8
	}
	if y < 8 {
		y = 8
	}
	limit_x := f32(rules.WORLD_W) - est - 8
	if x > limit_x {
		x = limit_x
	}
	limit_y := f32(rules.WORLD_H) - size - 8
	if y > limit_y {
		y = limit_y
	}
	draw_text(label, x+2, y+2, size, rl.BLACK)
	draw_text(label, x, y, size, rl.Color{0, 255, 0, 255})
}
