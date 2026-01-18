package main

import "core:math"
import "core:math/rand"
import "core:fmt"
import "core:time"
import "core:log"
import "core:strconv"
import "core:os"
import rl "vendor:raylib"

State :: struct {
  sim_time: f32,
  time_scale: f32,
  hours: f32,
  brightness: f32,
  debug: bool,
  speed: f32, //hours per second
}

Room :: struct {
  light_on: bool,
  tv_on: bool,
}

Dweller :: struct {
  room_number: uint,

  // Thresholds
  turn_on_threshold: f32,
  turn_off_threshold: f32,

  // TV
  has_tv: bool,
  tv_on_hour: f32,
  tv_off_hour: f32,
}

tv_colors := []rl.Color{
    {120, 140, 200, 255},  // cool blue (night scene)
    {150, 170, 220, 255},  // lighter blue
    {200, 200, 220, 255},  // blue-white (bright scene)
    {180, 150, 200, 255},  // purple tint (dramatic scene)
    {140, 160, 180, 255},  // muted blue-gray
    {160, 140, 160, 255},  // dim purple
}

make_dweller :: proc(room_number: uint) -> Dweller {
    turn_on := 0.2 + rand.float32() * 0.4  // 0.2 to 0.6 darkness to turn on

    // turn off when it's brighter than when they turned on
    // add a small gap (hysteresis) so no flicker
    turn_off := (1 - turn_on) + 0.05 + rand.float32() * 0.1

    return Dweller {
        turn_on_threshold = turn_on,
        turn_off_threshold = turn_off,
        room_number = room_number,
    }
}

calculate_background :: proc(state: ^State) -> rl.Color {
    t := state.hours / 24.0
    value: f32 = 0.575 + 0.375 * math.cos((t - 0.5) * 2 * math.PI)
    return rl.ColorFromHSV(210.0, 0.3, value)
}

hours_elapsed :: proc(from, to: f32) -> f32 {
    diff := to - from
    if diff < 0 do diff += 24  // crossed midnight
    return diff
}


SUNRISE :: 6.0
NOON    :: 12.0
SUNSET  :: 20.0

MORNING_DURATION :: NOON - SUNRISE      // 6 hours
EVENING_DURATION :: SUNSET - NOON       // 8 hours

get_brightness :: proc(hour: f32) -> f32 {
    if hour < SUNRISE || hour >= SUNSET do return 0.0
    if hour < NOON do return (hour - SUNRISE) / MORNING_DURATION
    return (SUNSET - hour) / EVENING_DURATION
}

draw_debug :: proc(state: ^State) {
  x:f32 = cast(f32)rl.GetScreenWidth() - 115
  hours_text := fmt.ctprintf("Hour: %d", cast(int)state.hours)
  hours_position := rl.Vector2 { x, 25}
  rl.DrawTextEx(rl.GetFontDefault(), hours_text, hours_position, 14, 1, rl.WHITE)

  brightness_text := fmt.ctprintf("Brightness: %v", state.brightness)
  brightness_position := rl.Vector2 { x, 45}
  rl.DrawTextEx(rl.GetFontDefault(), brightness_text, brightness_position, 14, 1, rl.WHITE)

  speed_text := fmt.ctprintf("speed: %v", state.speed)
  speed_position := rl.Vector2 { x, 65}
  rl.DrawTextEx(rl.GetFontDefault(), speed_text, speed_position, 14, 1, rl.WHITE)
}

BUILDING_HEIGHT :: 630
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

draw_building :: proc(state: ^State, background: rl.Color, rooms: []Room) {
  building_rect := rl.Rectangle {
    x = cast(f32)rl.GetScreenWidth() / 4,
    y = cast(f32)rl.GetScreenHeight() - BUILDING_HEIGHT,
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
        y = start_y + cast(f32)(row * (ROOM_HEIGHT + ROOM_PAD) - ROOM_PAD),
        width = ROOM_WIDTH,
        height = ROOM_HEIGHT,
      }

      room_index := row * ROOMS + col
      if rooms[room_index].light_on {
        rl.DrawRectangleRec(room_rect, LIGHT_ON_1)
      } else if rooms[room_index].tv_on {
        // Quantize time into "buckets" to slow down changes
        bucket := int(state.hours * 0.7)  // tweak multiplier for speed
        index := (bucket + room_index * 7) % len(tv_colors)
        color := tv_colors[index]
        rl.DrawRectangleRec(room_rect, color)
      } else {
        rl.DrawRectangleRec(room_rect, room_color)
      }

     }
  }
}

draw_ground :: proc(background: rl.Color) {
    ground_y : i32 = rl.GetScreenHeight() - 100
    ground_color := rl.ColorBrightness(background, -0.3)
    rl.DrawRectangle(0, ground_y, rl.GetScreenWidth(), BUILDING_HEIGHT, ground_color)
}

draw :: proc(state: ^State, rooms: []Room) {
  background := calculate_background(state)
  rl.ClearBackground(background)

  ground_color := rl.ColorBrightness(background, -0.3)
  draw_ground(ground_color)

  if state.debug {
    draw_debug(state)
  }

  draw_building(state, background, rooms)
}

process_events :: proc(state: ^State) {
  if rl.IsKeyPressed(rl.KeyboardKey.DOWN) && state.speed > 1 {
    state.speed -= 1
    state.time_scale = 24 * (state.speed * 60)

  } else if rl.IsKeyPressed(rl.KeyboardKey.UP)  {
    state.speed += 1
    state.time_scale = 24 * (state.speed * 60)
  }

  if rl.IsKeyPressed(rl.KeyboardKey.D) {
    state.debug = !state.debug
  }
}

update :: proc(state: ^State, rooms: []Room, dwellers: []Dweller) {
  state.sim_time = (state.sim_time + rl.GetFrameTime() * state.time_scale)
  state.hours = math.mod((state.sim_time/ 3600), 24.0)
  state.brightness = get_brightness(state.hours)
  darkness := 1.0 - state.brightness

  for &dweller in dwellers {
    room_index := dweller.room_number-1

    // If the light hasn't been turned on yet, decide if we want to turn it on.
    // Otherwise the light is already on and we need to decide if we want to turn it off.
    if !rooms[room_index].light_on  {
      should_turn_on := darkness > dweller.turn_on_threshold
      if should_turn_on {
        rooms[room_index].light_on = true
      }
    } else {
      should_turn_off := state.brightness > dweller.turn_off_threshold
      if should_turn_off {
        rooms[room_index].light_on = false
      }
    }

    if dweller.has_tv {
      if dweller.tv_on_hour < dweller.tv_off_hour {
        // Normal case: e.g., 14:00 to 18:00
        rooms[room_index].tv_on = state.hours >= dweller.tv_on_hour && state.hours < dweller.tv_off_hour
      } else {
        // Wrap-around case: e.g., 22:00 to 02:00
        rooms[room_index].tv_on = state.hours >= dweller.tv_on_hour || state.hours < dweller.tv_off_hour
      }
    }
  }
}

main :: proc() {
  context.logger = log.create_console_logger()

  rl.SetConfigFlags({
    .WINDOW_HIGHDPI,
    .WINDOW_MAXIMIZED,
    .WINDOW_RESIZABLE,
  })

  state: State
  state.speed = 1
  state.time_scale = 24 * (state.speed * 60)

  rl.InitWindow(1200, 800, "The Building")
  defer rl.CloseWindow()

  // Initialize rooms
  rooms := [ROOMS * FLOORS]Room{}
  for i in 0..<len(rooms) {
    rooms[i] = Room { light_on = false}
  }

  dwellers := [?]Dweller{
    make_dweller(1),
    make_dweller(15),
    make_dweller(8),
    make_dweller(22),
    make_dweller(35),
    make_dweller(41),
    make_dweller(53),
    make_dweller(67),

    // TV Maniac
    Dweller {
      has_tv = true,
      tv_on_hour = 19.0,
      tv_off_hour = 3.0,
      room_number = 27,

      // Never turns on the light
      turn_on_threshold = 1.0,
    },
  }

  rl.SetTargetFPS(30)

  for !rl.WindowShouldClose() {
    process_events(&state)
    update(&state, rooms[:], dwellers[:])

    rl.BeginDrawing()
    draw(&state, rooms[:])
    rl.EndDrawing()
  }
}
