package main

import "core:math"

import sdl "vendor:sdl3"

// Functions

view_screen_to_complex :: proc(
    screen: [2]f32,
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

get_window_pixel_scale :: proc(window: ^sdl.Window) -> [2]f32 {
    logical_w, logical_h: i32
    pixel_w, pixel_h: i32
    sdl.GetWindowSize(window, &logical_w, &logical_h)
    sdl.GetWindowSizeInPixels(window, &pixel_w, &pixel_h)
    if logical_w <= 0 || logical_h <= 0 {
        return {1, 1}
    }
    return {f32(pixel_w) / f32(logical_w), f32(pixel_h) / f32(logical_h)}
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
            drag_start = {0, 0},
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

init_fractal_compute :: proc(
    device: ^sdl.GPUDevice,
    resolution: Extent_2D,
) -> (
    compute_pipeline: ^sdl.GPUComputePipeline,
    texture: ^sdl.GPUTexture,
    ok: bool,
) {
    compute_pipeline = create_compute_pipeline(device)
    if compute_pipeline == nil {
        sdl.LogError(
            i32(sdl.LogCategory.RENDER),
            "unable to create GPU compute pipeline: %s",
            sdl.GetError(),
        )
        return
    }

    texture = create_output_texture(device, resolution)
    ok = true
    return
}

// Input management

fractal_process_input :: proc(
    event: ^sdl.Event,
    fractal: ^Fractal,
    gpu_device: ^sdl.GPUDevice,
    resolution: ^Extent_2D,
    gpu_texture: ^^sdl.GPUTexture,
    window: ^sdl.Window,
    is_mouse_captured: bool,
    want_capture_keyboard: bool,
) -> sdl.AppResult {
    #partial switch event.type {
    case .QUIT, .WINDOW_CLOSE_REQUESTED:
        return .SUCCESS
    case .KEY_DOWN:
        if !want_capture_keyboard {
            handle_fractal_keyboard_input(
                &fractal.camera.view,
                &fractal.params,
                &fractal.zoom_level,
                event.key.key,
            )
        }
    case .MOUSE_WHEEL:
        if !is_mouse_captured {
            handle_fractal_zoom(fractal, event, resolution^, window)
        }
    case .MOUSE_BUTTON_UP:
        if event.button.button == sdl.BUTTON_LEFT {
            return end_fractal_drag(fractal)
        }
    case .MOUSE_BUTTON_DOWN:
        if event.button.button == sdl.BUTTON_LEFT {
            return start_fractal_drag(fractal, is_mouse_captured)
        }
    case .MOUSE_MOTION:
        handle_fractal_drag(
            fractal,
            event,
            window,
            is_mouse_captured,
            resolution^,
        )
    case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
        handle_resize(
            event,
            window,
            gpu_device,
            resolution,
            &fractal.params.resolution,
            gpu_texture,
        )
    }

    return .CONTINUE
}

@(private = "file")
handle_resize :: proc(
    event: ^sdl.Event,
    main_window: ^sdl.Window,
    device: ^sdl.GPUDevice,
    resolution: ^Extent_2D,
    uniform_resolution: ^[2]f32,
    texture: ^^sdl.GPUTexture,
) {
    if event.window.windowID != sdl.GetWindowID(main_window) {
        return
    }

    pixel_w, pixel_h: i32
    sdl.GetWindowSizeInPixels(main_window, &pixel_w, &pixel_h)

    resolution.w = u32(pixel_w)
    resolution.h = u32(pixel_h)
    uniform_resolution^ = {f32(pixel_w), f32(pixel_h)}

    sdl.ReleaseGPUTexture(device, texture^)
    texture^ = create_output_texture(device, resolution^)
}

@(private = "file")
handle_fractal_keyboard_input :: proc(
    view: ^Fractal_View,
    params: ^Fractal_Params,
    zoom_level: ^f32,
    keycode: sdl.Keycode,
) {
    switch keycode {
    case sdl.K_W:
        view.center.y -= FRACTAL_PAN_FACTOR / view.zoom
    case sdl.K_S:
        view.center.y += FRACTAL_PAN_FACTOR / view.zoom
    case sdl.K_A:
        view.center.x -= FRACTAL_PAN_FACTOR / view.zoom
    case sdl.K_D:
        view.center.x += FRACTAL_PAN_FACTOR / view.zoom
    case sdl.K_Q:
        params.max_iter -= FRACTAL_ITERATION_DECREASE_STEP
        if params.max_iter < FRACTAL_MIN_ITERATIONS {
            params.max_iter = FRACTAL_MIN_ITERATIONS
        }
    case sdl.K_E:
        params.max_iter += FRACTAL_ITERATION_STEP
        if params.max_iter > FRACTAL_MAX_ITERATIONS {
            params.max_iter = FRACTAL_MAX_ITERATIONS
        }
    case sdl.K_R:
        reset_fractal_view(view, params, zoom_level)
    }
}

@(private = "file")
handle_fractal_zoom :: proc(
    fractal: ^Fractal,
    event: ^sdl.Event,
    resolution: Extent_2D,
    window: ^sdl.Window,
) {
    mouse_x, mouse_y: f32
    _ = sdl.GetMouseState(&mouse_x, &mouse_y)
    scale := get_window_pixel_scale(window)
    mouse := [2]f32{mouse_x * scale.x, mouse_y * scale.y}

    mouse_complex := view_screen_to_complex(
        mouse,
        resolution,
        fractal.camera.view,
    )

    fractal.zoom_level += event.wheel.y * FRACTAL_ZOOM_SCROLL_FACTOR
    fractal.zoom_level = max(fractal.zoom_level, FRACTAL_MIN_ZOOM_LOG)
    fractal.camera.view.zoom = math.exp(fractal.zoom_level)

    new_mouse_complex := view_screen_to_complex(
        mouse,
        resolution,
        fractal.camera.view,
    )

    fractal.camera.view.center.x += real(mouse_complex) - real(new_mouse_complex)
    fractal.camera.view.center.y += imag(mouse_complex) - imag(new_mouse_complex)
}

@(private = "file")
handle_fractal_drag :: proc(
    fractal: ^Fractal,
    event: ^sdl.Event,
    window: ^sdl.Window,
    is_mouse_captured: bool,
    resolution: Extent_2D,
) {
    if !fractal.camera.is_dragging || is_mouse_captured {
        return
    }

    scale := get_window_pixel_scale(window)
    dx := f32(event.motion.xrel) * scale.x
    dy := f32(event.motion.yrel) * scale.y
    drag_scale :=
        FRACTAL_MOUSE_DRAG_SCALE / (f32(resolution.h) * fractal.camera.view.zoom)

    fractal.camera.view.center.x -= dx * drag_scale
    fractal.camera.view.center.y -= dy * drag_scale
}

@(private = "file")
start_fractal_drag :: proc(
    fractal: ^Fractal,
    is_mouse_captured: bool,
) -> sdl.AppResult {
    if is_mouse_captured {
        return .CONTINUE
    }

    fractal.camera.is_dragging = true
    ok := sdl.SetCursor(fractal.move_cursor)
    if !ok {
        sdl.LogError(
            i32(sdl.LogCategory.APPLICATION),
            "unable to set move cursor: %s",
            sdl.GetError(),
        )
        return .FAILURE
    }
    return .CONTINUE
}

@(private = "file")
end_fractal_drag :: proc(fractal: ^Fractal) -> sdl.AppResult {
    fractal.camera.is_dragging = false
    ok := sdl.SetCursor(fractal.default_cursor)
    if !ok {
        sdl.LogError(
            i32(sdl.LogCategory.APPLICATION),
            "unable to set default cursor: %s",
            sdl.GetError(),
        )
        return .FAILURE
    }
    return .CONTINUE
}
