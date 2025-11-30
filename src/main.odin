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
  time_scale: f32,
}

Room :: struct {
  number: uint,
  light_on: bool,
}

calculate_background :: proc(hours: f32) -> rl.Color {
    t := hours / 24.0
    value: f32 = 0.575 + 0.375 * math.cos((t - 0.5) * 2 * math.PI)
    return rl.ColorFromHSV(210.0, 0.3, value)
}

draw_time :: proc(hours: f32) {
  hours_text := fmt.ctprintf("Hour: %d", cast(int)hours)
  hours_position := rl.Vector2 { SCREEN_WIDTH - 65, 25}
  rl.DrawTextEx(rl.GetFontDefault(), hours_text, hours_position, 14, 1, rl.WHITE)
}

BUILDING_HEIGHT :: 600
BUILDING_WIDTH :: 200
BUILDING_COLOR :: rl.Color{180, 175, 165, 255}

FLOORS :: 15
ROOMS :: 5
ROOM_PAD :: 10
ROOM_WIDTH :: 25
ROOM_HEIGHT :: 30

LIGHT_ON_1 :: rl.Color{240, 210, 160, 255}  // gentle warm light
LIGHT_ON_2 :: rl.Color{255, 220, 150, 255}  // warm yellow glow
LIGHT_ON_3 :: rl.Color{255, 200, 120, 255}  // warmer, more orange

draw_building :: proc(background: rl.Color, rooms: [ROOMS * FLOORS]Room) {
  building_rect := rl.Rectangle {
    x = SCREEN_WIDTH / 4,
    y = SCREEN_HEIGHT - BUILDING_HEIGHT,
    width = BUILDING_WIDTH,
    height = BUILDING_HEIGHT,
  }
  rl.DrawRectangleRec(building_rect, BUILDING_COLOR)

  room_color := rl.ColorBrightness(background, -0.2)

  // Calculate total grid size to center it
  grid_width := cast(f32)(ROOMS * ROOM_WIDTH + (ROOMS - 1) * ROOM_PAD)
  grid_height := cast(f32)(FLOORS * ROOM_HEIGHT + (FLOORS - 1) * ROOM_PAD)
  start_x := building_rect.x + (BUILDING_WIDTH - grid_width) / 2
  start_y := building_rect.y + (BUILDING_HEIGHT - grid_height) / 2

  for col := 0; col < ROOMS; col += 1 {
     for row := 0; row < FLOORS; row += 1 {
      room_rect := rl.Rectangle {
        x = start_x + cast(f32)(col * (ROOM_WIDTH + ROOM_PAD)),
        y = start_y + cast(f32)(row * (ROOM_HEIGHT + ROOM_PAD)),
        width = ROOM_WIDTH,
        height = ROOM_HEIGHT,
      }

      if rooms[col*row].light_on {
        rl.DrawRectangleRec(room_rect, LIGHT_ON_1)
      } else {
        rl.DrawRectangleRec(room_rect, room_color)
      }
     }
  }
}

main :: proc() {

  rl.SetConfigFlags({
    .WINDOW_HIGHDPI,
  })

  state: State
  state.time_scale = 24 * 240 // 24 hours every

  rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "The Building")
  defer rl.CloseWindow()


  // Initialize rooms
  rooms := [ROOMS * FLOORS]Room{}
  for i in 0..<len(rooms) {
    rooms[i] = Room { number = cast(uint)i+1, light_on = false}
  }

  rl.SetTargetFPS(30)

  for !rl.WindowShouldClose() {
    state.sim_time = state.sim_time + rl.GetFrameTime()
    rl.BeginDrawing()

    sim_time_scaled := state.sim_time * state.time_scale
    hours := math.mod_f32((sim_time_scaled / 3600), 24.0)

    background := calculate_background(hours)
    rl.ClearBackground(background)

    draw_time(hours)
    draw_building(background, rooms)

    rl.EndDrawing()
  }

}
