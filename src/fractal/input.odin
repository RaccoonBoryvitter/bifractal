package fractal

import "core:math"

import sdl "vendor:sdl3"

import "../geom"

fractal_process_input :: proc(
    fractal: ^Fractal,
    event: ^sdl.Event,
    pixel_scale: geom.Vec2,
    ui_wants_mouse: bool,
    ui_wants_keyboard: bool,
) -> Fractal_Input {
    #partial switch event.type {
    case .KEY_DOWN:
        if ui_wants_keyboard {
            return Fractal_Input{}
        }
        pan := FRACTAL_PAN_FACTOR / fractal.base.camera.view.zoom
        switch event.key.key {
        case sdl.K_W:
            return Fractal_Input{cmd = .Pan, delta = geom.Vec2{0, -pan}}
        case sdl.K_S:
            return Fractal_Input{cmd = .Pan, delta = geom.Vec2{0, pan}}
        case sdl.K_A:
            return Fractal_Input{cmd = .Pan, delta = geom.Vec2{-pan, 0}}
        case sdl.K_D:
            return Fractal_Input{cmd = .Pan, delta = geom.Vec2{pan, 0}}
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
        return Fractal_Input {
            cmd = .Zoom,
            pos = geom.Vec2{mouse_x * pixel_scale.x, mouse_y * pixel_scale.y},
            delta = geom.Vec2{0, f32(event.wheel.y)},
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
        if ui_wants_mouse || !fractal.base.camera.is_dragging {
            return Fractal_Input{}
        }
        dx := f32(event.motion.xrel) * pixel_scale.x
        dy := f32(event.motion.yrel) * pixel_scale.y
        drag_scale :=
            FRACTAL_MOUSE_DRAG_SCALE /
            (fractal.base.resolution.y * fractal.base.camera.view.zoom)
        return Fractal_Input {
            cmd = .Pan,
            delta = geom.Vec2{-dx * drag_scale, -dy * drag_scale},
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
        fractal.base.camera.view.center.x += input.delta.x
        fractal.base.camera.view.center.y += input.delta.y
    case .Zoom:
        mouse_complex := view_screen_to_complex(
            input.pos,
            geom.Extent_2D {
                u32(fractal.base.resolution.x),
                u32(fractal.base.resolution.y),
            },
            fractal.base.camera.view,
        )

        fractal.base.zoom_level += input.delta.y * FRACTAL_ZOOM_SCROLL_FACTOR
        fractal.base.zoom_level = max(
            fractal.base.zoom_level,
            FRACTAL_MIN_ZOOM_LOG,
        )
        fractal.base.camera.view.zoom = math.exp(fractal.base.zoom_level)

        new_mouse_complex := view_screen_to_complex(
            input.pos,
            geom.Extent_2D {
                u32(fractal.base.resolution.x),
                u32(fractal.base.resolution.y),
            },
            fractal.base.camera.view,
        )

        fractal.base.camera.view.center.x +=
            real(mouse_complex) - real(new_mouse_complex)
        fractal.base.camera.view.center.y +=
            imag(mouse_complex) - imag(new_mouse_complex)
    case .Reset_View:
        reset_fractal_view(&fractal.base)
    case .Increase_Iter:
        fractal.base.max_iter += FRACTAL_ITERATION_STEP
        if fractal.base.max_iter > FRACTAL_MAX_ITERATIONS {
            fractal.base.max_iter = FRACTAL_MAX_ITERATIONS
        }
    case .Decrease_Iter:
        fractal.base.max_iter -= FRACTAL_ITERATION_DECREASE_STEP
        if fractal.base.max_iter < FRACTAL_MIN_ITERATIONS {
            fractal.base.max_iter = FRACTAL_MIN_ITERATIONS
        }
    case .Drag_Start:
        if fractal.base.camera.is_dragging {
            return
        }
        fractal.base.camera.is_dragging = true
    case .Drag_End:
        if !fractal.base.camera.is_dragging {
            return
        }
        fractal.base.camera.is_dragging = false
    }
}
