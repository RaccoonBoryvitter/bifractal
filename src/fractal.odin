package main

import "core:math"

import sdl "vendor:sdl3"

// Functions

view_screen_to_complex :: proc(
    screen: Vec2,
    size: Extent_2D,
    view: Fractal_View,
) -> complex64 {
    w := f32(size.w)
    h := f32(size.h)
    return complex(
        (screen.x - w * 0.5) / (h * view.zoom) + view.center.x,
        (screen.y - h * 0.5) / (h * view.zoom) + view.center.y,
    )
}

get_window_pixel_scale :: proc(window: ^sdl.Window) -> Vec2 {
    logical_w, logical_h: i32
    pixel_w, pixel_h: i32
    sdl.GetWindowSize(window, &logical_w, &logical_h)
    sdl.GetWindowSizeInPixels(window, &pixel_w, &pixel_h)
    if logical_w <= 0 || logical_h <= 0 {
        return Vec2{1, 1}
    }
    return Vec2{f32(pixel_w) / f32(logical_w), f32(pixel_h) / f32(logical_h)}
}

reset_fractal_view :: proc(
    view: ^Fractal_View,
    params: ^Fractal_Params,
    zoom_level: ^f32,
) {
    view.zoom = FRACTAL_DEFAULT_ZOOM
    zoom_level^ = math.log2(view.zoom)
    view.center = {FRACTAL_DEFAULT_CENTER_X, FRACTAL_DEFAULT_CENTER_Y}
    params.max_iter = FRACTAL_DEFAULT_MAX_ITER
}

fractal_make_uniform :: proc(fractal: ^Fractal) -> Fractal_Uniform {
    return Fractal_Uniform {
        center = fractal.camera.view.center,
        zoom = fractal.camera.view.zoom,
        params = fractal.params,
    }
}

// State management

init_fractal_state :: proc(resolution: Extent_2D) -> Fractal {
    zoom := FRACTAL_DEFAULT_ZOOM
    return Fractal {
        camera = {
            view = {
                center = {FRACTAL_DEFAULT_CENTER_X, FRACTAL_DEFAULT_CENTER_Y},
                zoom = FRACTAL_DEFAULT_ZOOM,
            },
            is_dragging = false,
            drag_start = Vec2{0, 0},
        },
        params = {
            max_iter = FRACTAL_DEFAULT_MAX_ITER,
            resolution = {f32(resolution.w), f32(resolution.h)},
            palette = {
                offset = {0.5, 0.5, 0.5, 0.0},
                amplitude = {0.5, 0.5, 0.5, 0.0},
                frequency = {1.0, 1.0, 1.0, 0.0},
                phase = {0.0, 0.10, 0.20, 0.0},
            },
        },
        zoom_level = math.log2(f32(zoom)),
        default_cursor = sdl.CreateSystemCursor(.DEFAULT),
        move_cursor = sdl.CreateSystemCursor(.MOVE),
    }
}

// Input management

fractal_process_input :: proc(
    fractal: ^Fractal,
    event: ^sdl.Event,
    window: ^sdl.Window,
    ui_wants_mouse: bool,
    ui_wants_keyboard: bool,
) -> Fractal_Input {
    #partial switch event.type {
    case .KEY_DOWN:
        if ui_wants_keyboard {
            return Fractal_Input{}
        }
        pan := FRACTAL_PAN_FACTOR / fractal.camera.view.zoom
        switch event.key.key {
        case sdl.K_W:
            return Fractal_Input{cmd = .Pan, delta = Vec2{0, -pan}}
        case sdl.K_S:
            return Fractal_Input{cmd = .Pan, delta = Vec2{0, pan}}
        case sdl.K_A:
            return Fractal_Input{cmd = .Pan, delta = Vec2{-pan, 0}}
        case sdl.K_D:
            return Fractal_Input{cmd = .Pan, delta = Vec2{pan, 0}}
        case sdl.K_Q:
            return Fractal_Input{cmd = .Decrease_Iter}
        case sdl.K_E:
            return Fractal_Input{cmd = .Increase_Iter}
        case sdl.K_R:
            return Fractal_Input{cmd = .Reset_View}
        case:
            return Fractal_Input{}
        }
    case .MOUSE_WHEEL:
        if ui_wants_mouse {
            return Fractal_Input{}
        }
        mouse_x, mouse_y: f32
        _ = sdl.GetMouseState(&mouse_x, &mouse_y)
        scale := get_window_pixel_scale(window)
        return Fractal_Input {
            cmd = .Zoom,
            pos = Vec2{mouse_x * scale.x, mouse_y * scale.y},
            delta = Vec2{0, f32(event.wheel.y)},
        }
    case .MOUSE_BUTTON_DOWN:
        if ui_wants_mouse || event.button.button != sdl.BUTTON_LEFT {
            return Fractal_Input{}
        }
        return Fractal_Input{cmd = .Drag_Start}
    case .MOUSE_BUTTON_UP:
        if event.button.button != sdl.BUTTON_LEFT {
            return Fractal_Input{}
        }
        return Fractal_Input{cmd = .Drag_End}
    case .MOUSE_MOTION:
        if ui_wants_mouse || !fractal.camera.is_dragging {
            return Fractal_Input{}
        }
        scale := get_window_pixel_scale(window)
        dx := f32(event.motion.xrel) * scale.x
        dy := f32(event.motion.yrel) * scale.y
        drag_scale :=
            FRACTAL_MOUSE_DRAG_SCALE /
            (fractal.params.resolution.y * fractal.camera.view.zoom)
        return Fractal_Input {
            cmd = .Pan,
            delta = Vec2{-dx * drag_scale, -dy * drag_scale},
        }
    }

    return Fractal_Input{}
}

fractal_apply_command :: proc(
    fractal: ^Fractal,
    input: Fractal_Input,
    window: ^sdl.Window,
) {
    switch input.cmd {
    case .None:
        return
    case .Pan:
        fractal.camera.view.center.x += input.delta.x
        fractal.camera.view.center.y += input.delta.y
    case .Zoom:
        mouse_complex := view_screen_to_complex(
            input.pos,
            Extent_2D {
                u32(fractal.params.resolution.x),
                u32(fractal.params.resolution.y),
            },
            fractal.camera.view,
        )

        fractal.zoom_level += input.delta.y * FRACTAL_ZOOM_SCROLL_FACTOR
        fractal.zoom_level = max(fractal.zoom_level, FRACTAL_MIN_ZOOM_LOG)
        fractal.camera.view.zoom = math.exp(fractal.zoom_level)

        new_mouse_complex := view_screen_to_complex(
            input.pos,
            Extent_2D {
                u32(fractal.params.resolution.x),
                u32(fractal.params.resolution.y),
            },
            fractal.camera.view,
        )

        fractal.camera.view.center.x +=
            real(mouse_complex) - real(new_mouse_complex)
        fractal.camera.view.center.y +=
            imag(mouse_complex) - imag(new_mouse_complex)
    case .Reset_View:
        reset_fractal_view(
            &fractal.camera.view,
            &fractal.params,
            &fractal.zoom_level,
        )
    case .Increase_Iter:
        fractal.params.max_iter += FRACTAL_ITERATION_STEP
        if fractal.params.max_iter > FRACTAL_MAX_ITERATIONS {
            fractal.params.max_iter = FRACTAL_MAX_ITERATIONS
        }
    case .Decrease_Iter:
        fractal.params.max_iter -= FRACTAL_ITERATION_DECREASE_STEP
        if fractal.params.max_iter < FRACTAL_MIN_ITERATIONS {
            fractal.params.max_iter = FRACTAL_MIN_ITERATIONS
        }
    case .Drag_Start:
        if fractal.camera.is_dragging {
            return
        }
        fractal.camera.is_dragging = true
        if !sdl.SetCursor(fractal.move_cursor) {
            sdl.LogError(
                i32(sdl.LogCategory.APPLICATION),
                "unable to set move cursor: %s",
                sdl.GetError(),
            )
        }
    case .Drag_End:
        if !fractal.camera.is_dragging {
            return
        }
        fractal.camera.is_dragging = false
        if !sdl.SetCursor(fractal.default_cursor) {
            sdl.LogError(
                i32(sdl.LogCategory.APPLICATION),
                "unable to set default cursor: %s",
                sdl.GetError(),
            )
        }
    }
}
