package main

import "core:log"
import "core:math"

import sdl "vendor:sdl3"

// Functions

screen_to_complex :: proc(
    screen_x, screen_y : f32,
    resolution : Resolution,
    center : [2]f32,
    zoom : f32,
) -> complex64 {
    w := f32(resolution.w)
    h := f32(resolution.h)
    return complex(
        (screen_x - w * 0.5) / (h * zoom) + center.x,
        (screen_y - h * 0.5) / (h * zoom) + center.y,
    )
}

reset_fractal_view :: proc(uniform : ^Fractal_Uniform, zoom_level : ^f32) {
    uniform.zoom = FRACTAL_DEFAULT_ZOOM
    zoom_level^ = math.log2(uniform.zoom)
    uniform.center = {FRACTAL_DEFAULT_CENTER_X, FRACTAL_DEFAULT_CENTER_Y}
    uniform.max_iter = FRACTAL_DEFAULT_MAX_ITER
}

// State management

init_fractal_state :: proc(
    resolution : Resolution,
) -> Fractal_State {
    zoom := FRACTAL_DEFAULT_ZOOM
    return Fractal_State {
        uniform = {
            center = {FRACTAL_DEFAULT_CENTER_X, FRACTAL_DEFAULT_CENTER_Y},
            zoom = FRACTAL_DEFAULT_ZOOM,
            max_iter = FRACTAL_DEFAULT_MAX_ITER,
            resolution = {f32(resolution.w), f32(resolution.h)},
            palette_a = {0.5, 0.5, 0.5, 0.0},
            palette_b = {0.5, 0.5, 0.5, 0.0},
            palette_c = {1.0, 1.0, 1.0, 0.0},
            palette_d = {0.0, 0.10, 0.20, 0.0},
        },
        zoom_level = math.log2(f32(zoom)),
        default_cursor = sdl.CreateSystemCursor(.DEFAULT),
        move_cursor = sdl.CreateSystemCursor(.MOVE),
    }
}

init_fractal_compute :: proc(
    device : ^sdl.GPUDevice,
    resolution : Resolution,
) -> (
    compute_pipeline : ^sdl.GPUComputePipeline,
    texture : ^sdl.GPUTexture,
    ok : bool,
) {
    compute_pipeline = create_compute_pipeline(device, "mandelbrot")
    if compute_pipeline == nil {
        log.errorf("unable to create GPU compute pipeline: %s", sdl.GetError())
        return
    }

    texture = create_output_texture(device, resolution)
    ok = true
    return
}

// Input management

handle_fractal_events :: proc(
    event : ^sdl.Event,
    fractal : ^Fractal_State,
    gpu_device : ^sdl.GPUDevice,
    resolution : ^Resolution,
    gpu_texture : ^^sdl.GPUTexture,
    is_hover_active : bool,
) -> sdl.AppResult {
    #partial switch event.type {
        case .QUIT, .WINDOW_CLOSE_REQUESTED: return .SUCCESS
        case .KEY_DOWN:
            handle_fractal_keyboard_input(
                    &fractal.uniform,
                    &fractal.zoom_level,
                    event.key.key,
                )
        case .MOUSE_WHEEL: if !is_hover_active {
                    handle_fractal_zoom(
                        fractal,
                        event,
                        resolution^,
                    )
                }
        case .MOUSE_BUTTON_UP: if event.button.button == sdl.BUTTON_LEFT {
                    return end_fractal_drag(fractal)
                }
        case .MOUSE_BUTTON_DOWN: if event.button.button == sdl.BUTTON_LEFT {
                    return start_fractal_drag(fractal, is_hover_active)
                }
        case .MOUSE_MOTION:
            handle_fractal_drag(
                    fractal,
                    event,
                    is_hover_active,
                    resolution^,
                )
        case .WINDOW_PIXEL_SIZE_CHANGED:
            handle_resize(
                    event,
                    gpu_device,
                    resolution,
                    &fractal.uniform.resolution,
                    gpu_texture,
                )
    }

    return .CONTINUE
}

@(private = "file")
handle_resize :: proc(
    event : ^sdl.Event,
    device : ^sdl.GPUDevice,
    resolution : ^Resolution,
    uniform_resolution : ^[2]f32,
    texture : ^^sdl.GPUTexture,
) {
    event_window := event.window
    resolution.w = u32(event_window.data1)
    resolution.h = u32(event_window.data2)
    uniform_resolution^ = {f32(event_window.data1), f32(event_window.data2)}

    sdl.ReleaseGPUTexture(device, texture^)
    texture^ = create_output_texture(device, resolution^)
}

@(private = "file")
handle_fractal_keyboard_input :: proc(
    uniform : ^Fractal_Uniform,
    zoom_level : ^f32,
    keycode : sdl.Keycode,
) {
    switch keycode {
        case sdl.K_W: uniform.center.y -= FRACTAL_PAN_FACTOR / uniform.zoom
        case sdl.K_S: uniform.center.y += FRACTAL_PAN_FACTOR / uniform.zoom
        case sdl.K_A: uniform.center.x -= FRACTAL_PAN_FACTOR / uniform.zoom
        case sdl.K_D: uniform.center.x += FRACTAL_PAN_FACTOR / uniform.zoom
        case sdl.K_Q:
            uniform.max_iter -= FRACTAL_ITERATION_DECREASE_STEP
            if uniform.max_iter < FRACTAL_MIN_ITERATIONS {
                uniform.max_iter = FRACTAL_MIN_ITERATIONS
            }
        case sdl.K_E:
            uniform.max_iter += FRACTAL_ITERATION_STEP
            if uniform.max_iter > FRACTAL_MAX_ITERATIONS {
                uniform.max_iter = FRACTAL_MAX_ITERATIONS
            }
        case sdl.K_R: reset_fractal_view(uniform, zoom_level)
    }
}

@(private = "file")
handle_fractal_zoom :: proc(
    fractal : ^Fractal_State,
    event : ^sdl.Event,
    resolution : Resolution,
) {
    mouse_x, mouse_y : f32
    _ = sdl.GetMouseState(&mouse_x, &mouse_y)

    w := f32(resolution.w)
    h := f32(resolution.h)
    mouse_complex := [2]f32 {
        (mouse_x - w * 0.5) / (h * fractal.uniform.zoom) +
        fractal.uniform.center.x,
        (mouse_y - h * 0.5) / (h * fractal.uniform.zoom) +
        fractal.uniform.center.y,
    }

    fractal.zoom_level += event.wheel.y * FRACTAL_ZOOM_SCROLL_FACTOR
    fractal.uniform.zoom = math.exp(fractal.zoom_level)

    new_mouse_complex := [2]f32 {
        (mouse_x - w * 0.5) / (h * fractal.uniform.zoom) +
        fractal.uniform.center.x,
        (mouse_y - h * 0.5) / (h * fractal.uniform.zoom) +
        fractal.uniform.center.y,
    }

    fractal.uniform.center.x += mouse_complex.x - new_mouse_complex.x
    fractal.uniform.center.y += mouse_complex.y - new_mouse_complex.y
}

@(private = "file")
handle_fractal_drag :: proc(
    fractal : ^Fractal_State,
    event : ^sdl.Event,
    is_hover_active : bool,
    resolution : Resolution,
) {
    if !fractal.is_dragging || is_hover_active {
        return
    }

    dx := f32(event.motion.xrel)
    dy := f32(event.motion.yrel)
    scale :=
        FRACTAL_MOUSE_DRAG_SCALE / (f32(resolution.h) * fractal.uniform.zoom)

    fractal.uniform.center.x -= dx * scale
    fractal.uniform.center.y -= dy * scale
}

@(private = "file")
start_fractal_drag :: proc(
    fractal : ^Fractal_State,
    is_hover_active : bool,
) -> sdl.AppResult {
    if is_hover_active {
        return .CONTINUE
    }

    fractal.is_dragging = true
    ok := sdl.SetCursor(fractal.move_cursor)
    if !ok {
        log.errorf("unable to set move cursor: %s", sdl.GetError())
        return .FAILURE
    }
    return .CONTINUE
}

@(private = "file")
end_fractal_drag :: proc(fractal : ^Fractal_State) -> sdl.AppResult {
    fractal.is_dragging = false
    ok := sdl.SetCursor(fractal.default_cursor)
    if !ok {
        log.errorf("unable to set default cursor: %s", sdl.GetError())
        return .FAILURE
    }
    return .CONTINUE
}
