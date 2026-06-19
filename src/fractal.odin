package main

import "core:log"
import "core:math"

import sdl "vendor:sdl3"

// Types

FractalUniform :: struct {
    center :     [2]f32,
    zoom :       f32,
    max_iter :   i32,
    palette_a :  [3]f32,
    _pad_a :     f32,
    palette_b :  [3]f32,
    _pad_b :     f32,
    palette_c :  [3]f32,
    _pad_c :     f32,
    palette_d :  [3]f32,
    _pad_d :     f32,
    resolution : [2]f32,
}

FractalState :: struct {
    uniform :        FractalUniform,
    zoom_level :     f32,
    is_dragging :    bool,
    default_cursor : ^sdl.Cursor,
    move_cursor :    ^sdl.Cursor,
}

// Functions

screen_to_complex :: proc(
    screen_x, screen_y : f32,
    window_width, window_height : u32,
    center : [2]f32,
    zoom : f32,
) -> complex64 {
    w := f32(window_width)
    h := f32(window_height)
    return complex(
        (screen_x - w * 0.5) / (h * zoom) + center.x,
        (screen_y - h * 0.5) / (h * zoom) + center.y,
    )
}

reset_fractal_view :: proc(uniform : ^FractalUniform, zoom_level : ^f32) {
    uniform.zoom = FRACTAL_DEFAULT_ZOOM
    zoom_level^ = math.log2(uniform.zoom)
    uniform.center = {FRACTAL_DEFAULT_CENTER_X, FRACTAL_DEFAULT_CENTER_Y}
    uniform.max_iter = FRACTAL_DEFAULT_MAX_ITER
}

// State management

init_fractal_state :: proc(state : ^AppState) -> FractalState {
    zoom := FRACTAL_DEFAULT_ZOOM
    return FractalState {
        uniform = {
            center = {FRACTAL_DEFAULT_CENTER_X, FRACTAL_DEFAULT_CENTER_Y},
            zoom = FRACTAL_DEFAULT_ZOOM,
            max_iter = FRACTAL_DEFAULT_MAX_ITER,
            resolution = {f32(state.window_width), f32(state.window_height)},
            palette_a = {0.5, 0.5, 0.5},
            palette_b = {0.5, 0.5, 0.5},
            palette_c = {1.0, 1.0, 1.0},
            palette_d = {0.0, 0.10, 0.20},
        },
        zoom_level = math.log2(f32(zoom)),
        default_cursor = sdl.CreateSystemCursor(.DEFAULT),
        move_cursor = sdl.CreateSystemCursor(.MOVE),
    }
}

init_fractal_compute :: proc(state : ^AppState) -> bool {
    compute_pipeline := create_compute_pipeline(
        MANDELBROT_SHADER_PATH,
        state.gpu.device,
    )
    if compute_pipeline == nil {
        log.errorf("unable to create GPU compute pipeline: %s", sdl.GetError())
        return false
    }
    state.gpu.compute_pipeline = compute_pipeline

    state.gpu.texture = create_output_texture(
        state.gpu.device,
        state.window_width,
        state.window_height,
    )

    return true
}

// Input management

handle_fractal_events :: proc(
    event : ^sdl.Event,
    state : ^AppState,
) -> sdl.AppResult {
    #partial switch event.type {
        case .QUIT, .WINDOW_CLOSE_REQUESTED: return .SUCCESS
        case .KEY_DOWN: handle_fractal_keyboard_input(state, event.key.key)
        case .MOUSE_WHEEL: if state.ui_context.hover_root == nil {
                    handle_fractal_zoom(state, event)
                }
        case .MOUSE_BUTTON_UP: if event.button.button == sdl.BUTTON_LEFT {
                    return end_fractal_drag(state)
                }
        case .MOUSE_BUTTON_DOWN: if event.button.button == sdl.BUTTON_LEFT {
                    return start_fractal_drag(state)
                }
        case .MOUSE_MOTION: handle_fractal_drag(state, event)
        case .WINDOW_PIXEL_SIZE_CHANGED: handle_resize(event, state)
    }

    return .CONTINUE
}

@(private = "file")
handle_resize :: proc(event : ^sdl.Event, state : ^AppState) {
    event_window := event.window
    state.window_width = u32(event_window.data1)
    state.window_height = u32(event_window.data2)
    state.fractal.uniform.resolution = {
        f32(event_window.data1),
        f32(event_window.data2),
    }

    sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.texture)
    state.gpu.texture = create_output_texture(
        state.gpu.device,
        state.window_width,
        state.window_height,
    )
}

@(private = "file")
handle_fractal_keyboard_input :: proc(
    state : ^AppState,
    keycode : sdl.Keycode,
) {
    switch keycode {
        case sdl.K_W:
            state.fractal.uniform.center.y -=
                    FRACTAL_PAN_FACTOR / state.fractal.uniform.zoom
        case sdl.K_S:
            state.fractal.uniform.center.y +=
                    FRACTAL_PAN_FACTOR / state.fractal.uniform.zoom
        case sdl.K_A:
            state.fractal.uniform.center.x -=
                    FRACTAL_PAN_FACTOR / state.fractal.uniform.zoom
        case sdl.K_D:
            state.fractal.uniform.center.x +=
                    FRACTAL_PAN_FACTOR / state.fractal.uniform.zoom
        case sdl.K_Q:
            state.fractal.uniform.max_iter -= FRACTAL_ITERATION_DECREASE_STEP
            if state.fractal.uniform.max_iter < FRACTAL_MIN_ITERATIONS {
                state.fractal.uniform.max_iter = FRACTAL_MIN_ITERATIONS
            }
        case sdl.K_E:
            state.fractal.uniform.max_iter += FRACTAL_ITERATION_STEP
            if state.fractal.uniform.max_iter > FRACTAL_MAX_ITERATIONS {
                state.fractal.uniform.max_iter = FRACTAL_MAX_ITERATIONS
            }
        case sdl.K_R:
            reset_fractal_view(
                    &state.fractal.uniform,
                    &state.fractal.zoom_level,
                )
    }
}

@(private = "file")
handle_fractal_zoom :: proc(state : ^AppState, event : ^sdl.Event) {
    mouse_x, mouse_y : f32
    _ = sdl.GetMouseState(&mouse_x, &mouse_y)

    w := f32(state.window_width)
    h := f32(state.window_height)
    mouse_complex := [2]f32 {
        (mouse_x - w * 0.5) / (h * state.fractal.uniform.zoom) +
        state.fractal.uniform.center.x,
        (mouse_y - h * 0.5) / (h * state.fractal.uniform.zoom) +
        state.fractal.uniform.center.y,
    }

    state.fractal.zoom_level += event.wheel.y * FRACTAL_ZOOM_SCROLL_FACTOR
    state.fractal.uniform.zoom = math.exp(state.fractal.zoom_level)

    new_mouse_complex := [2]f32 {
        (mouse_x - w * 0.5) / (h * state.fractal.uniform.zoom) +
        state.fractal.uniform.center.x,
        (mouse_y - h * 0.5) / (h * state.fractal.uniform.zoom) +
        state.fractal.uniform.center.y,
    }

    state.fractal.uniform.center.x += mouse_complex.x - new_mouse_complex.x
    state.fractal.uniform.center.y += mouse_complex.y - new_mouse_complex.y
}

@(private = "file")
handle_fractal_drag :: proc(state : ^AppState, event : ^sdl.Event) {
    if !state.fractal.is_dragging || state.ui_context.hover_root != nil {
        return
    }

    dx := f32(event.motion.xrel)
    dy := f32(event.motion.yrel)
    scale :=
        FRACTAL_MOUSE_DRAG_SCALE /
        (f32(state.window_height) * state.fractal.uniform.zoom)

    state.fractal.uniform.center.x -= dx * scale
    state.fractal.uniform.center.y -= dy * scale
}

@(private = "file")
start_fractal_drag :: proc(state : ^AppState) -> sdl.AppResult {
    if state.ui_context.hover_root != nil {
        return .CONTINUE
    }

    state.fractal.is_dragging = true
    ok := sdl.SetCursor(state.fractal.move_cursor)
    if !ok {
        log.errorf("unable to set move cursor: %s", sdl.GetError())
        return .FAILURE
    }
    return .CONTINUE
}

@(private = "file")
end_fractal_drag :: proc(state : ^AppState) -> sdl.AppResult {
    state.fractal.is_dragging = false
    ok := sdl.SetCursor(state.fractal.default_cursor)
    if !ok {
        log.errorf("unable to set default cursor: %s", sdl.GetError())
        return .FAILURE
    }
    return .CONTINUE
}
