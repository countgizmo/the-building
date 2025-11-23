package main

import "core:math"
import "core:fmt"
import "core:time"
import "core:log"
import "core:strconv"
import "core:os"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1200
SCREEN_HEIGHT :: 800


State :: struct {
  sim_time: f32,
  time_scale: f32
}

calculate_background :: proc(hours: f32) -> rl.Color {
    t := hours / 24.0
    value: f32 = 0.575 + 0.375 * math.cos((t - 0.5) * 2 * math.PI)
    return rl.ColorFromHSV(210.0, 0.3, value)
}

draw_time :: proc(hours: f32) {
  hours_text := fmt.ctprintf("%v", hours)
  hours_position := rl.Vector2 { SCREEN_WIDTH - 100, SCREEN_HEIGHT - 100}
  rl.DrawTextEx(rl.GetFontDefault(), hours_text, hours_position, 14, 1, rl.WHITE)

  t:= hours / 24.0
  t_text := fmt.ctprintf("%v", t)
  t_position := rl.Vector2 { hours_position.x, hours_position.y - 200}
  rl.DrawTextEx(rl.GetFontDefault(), t_text, t_position, 14, 1, rl.WHITE)
}

main :: proc() {

  rl.SetConfigFlags({
    .WINDOW_HIGHDPI,
  })

  state: State
  state.time_scale = 24 * 60 // 24 hours every 2 minutes

  rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "The Building")
  defer rl.CloseWindow()


  rl.SetTargetFPS(30)

  for !rl.WindowShouldClose() {
    state.sim_time = state.sim_time + rl.GetFrameTime()
    rl.BeginDrawing()

    sim_time_scaled := state.sim_time * state.time_scale
    hours := math.mod_f32((sim_time_scaled / 3600), 24.0)

    background := calculate_background(hours)
    rl.ClearBackground(background)

    draw_time(hours)

    rl.EndDrawing()
  }

}
