package main

import "base:runtime"
import "core:fmt"
import "core:time"
import rl "../raylib"
import "../../GlomRemastered/rules"

SIM_DT :: f32(1) / 60
MAX_FRAME :: f32(0.05)

// Wide enough that the 4:3 world and the right-hand pad both fit.
// Raylib on Android draws in this screen space and scales it onto the phone.
VIEW_W :: i32(1280)
VIEW_H :: i32(720)

Mode :: enum {
	Menu,
	Help,
	Play,
	Pause,
	Result,
}

mode: Mode
help_back: Mode
result: rules.Result_Kind
game: rules.Game
sim_acc: f32
running: bool

main :: proc() {
	rl.SetConfigFlags({})
	rl.InitWindow(VIEW_W, VIEW_H, "Glom Remastered")
	if !rl.IsWindowReady() {
		fmt.eprintln("Glom Remastered could not open a window.")
		return
	}

	asset_root = find_asset_root()
	defer delete(asset_root)
	defer rl.CloseWindow()

	rl.SetExitKey(.KEY_NULL)
	when ODIN_PLATFORM_SUBTARGET != .Android {
		rl.SetWindowMinSize(960, 540)
		load_window_icon()
	}

	target := rl.LoadRenderTexture(rules.WORLD_W, rules.WORLD_H)
	if target.texture.id != 0 {
		rl.SetTextureFilter(target.texture, .BILINEAR)
	}
	defer rl.UnloadRenderTexture(target)

	init_audio()
	defer shutdown_audio()
	init_font()
	defer shutdown_font()
	init_textures()
	defer shutdown_textures()

	rl.SetTargetFPS(60)
	fmt.eprintf("Glom Remastered mobile\nassets: %s\n", asset_root)
	runtime.free_all(context.temp_allocator)

	mode = .Menu
	help_back = .Menu
	running = true

	for running && !rl.WindowShouldClose() {
		// Screen pixels, same space as the mouse and the touch points.
		// The world is fit inside the area left of the pad, uniform scale.
		screen_w := f32(rl.GetScreenWidth())
		screen_h := f32(rl.GetScreenHeight())
		pad, play := layout_pad(screen_w, screen_h)
		dst := fit_inside(play)
		mouse, click := sample_pad(&pad, dst)

		if mode == .Play {
			dt := rl.GetFrameTime()
			if dt > MAX_FRAME {
				dt = MAX_FRAME
			}
			if dt < 0 {
				dt = 0
			}
			sim_acc += dt
			steps := 0
			for sim_acc >= SIM_DT && steps < 3 {
				sim_acc -= SIM_DT
				steps += 1
				keys := rules.Step_Input{
					Left = rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) || pad.hold_left,
					Right = rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) || pad.hold_right,
					Up = rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) || pad.hold_up,
					Down = rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) || pad.hold_down,
				}
				ev := rules.Step(&game, keys)
				play_step_sounds(ev)
				if ev.Result != .None {
					result = ev.Result
					mode = .Result
					ui_reset()
					break
				}
			}
		} else {
			sim_acc = 0
		}

		rl.SetMouseCursor(.DEFAULT)
		action := Ui_Action.None
		rl.BeginTextureMode(target)
		switch mode {
		case .Menu:
			action = draw_menu(mouse, click)
		case .Help:
			action = draw_help(mouse, click)
		case .Play:
			draw_world(&game)
		case .Pause:
			draw_world(&game)
			action = draw_pause(mouse, click)
		case .Result:
			draw_world(&game)
			action = draw_result(result, mouse, click)
		}
		rl.EndTextureMode()

		if action == .None && (pad.pause_pressed || rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.BACK)) {
			switch mode {
			case .Help:
				action = .Back
			case .Pause:
				action = .Resume
			case .Play:
				action = .Pause_Open
			case .Result:
				action = .Menu
			case .Menu:
			}
		}
		apply_action(action)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		src := rl.Rectangle{0, 0, f32(target.texture.width), -f32(target.texture.height)}
		rl.DrawTexturePro(target.texture, src, dst, {}, 0, rl.WHITE)
		draw_pad(pad)
		rl.EndDrawing()

		runtime.free_all(context.temp_allocator)
	}
}

play_step_sounds :: proc(ev: rules.Step_Events) {
	if ev.Bounced {
		play_voices(&bounce_voices)
	}
	n := ev.Ate
	if n > 4 {
		n = 4
	}
	for _ in 0..<n {
		play_voices(&eat_voices)
	}
	if ev.Chomp {
		play_voices(&eat_voices)
	}
	if ev.Result == .Died_Explode {
		play_voices(&explode_voices)
	}
}

apply_action :: proc(action: Ui_Action) {
	if action == .None {
		return
	}
	play_voices(&click_voices)
	ui_reset()
	switch action {
	case .None:
	case .Play, .Retry:
		game = rules.New_Game(u64(time.to_unix_nanoseconds(time.now())))
		sim_acc = 0
		result = .None
		mode = .Play
	case .Help:
		help_back = .Menu
		if mode == .Pause {
			help_back = .Pause
		}
		mode = .Help
	case .Back:
		mode = help_back
	case .Quit:
		running = false
	case .Resume:
		mode = .Play
	case .Pause_Open:
		mode = .Pause
	case .Menu:
		result = .None
		mode = .Menu
	case .OK:
		next := rules.After_Dialog(&game)
		if next != .None {
			result = next
			mode = .Result
			if next == .Died_Explode {
				play_voices(&explode_voices)
			}
		} else {
			result = .None
			mode = .Play
		}
	}
}
