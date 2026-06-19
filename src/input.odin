#+feature dynamic-literals
package main

import "core:log"
import "core:math"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

import mu "vendor:microui"
import sdl "vendor:sdl3"

KEY_MAP := map[sdl.Keycode]mu.Key {
    sdl.K_LSHIFT    = .SHIFT,
    sdl.K_RSHIFT    = .SHIFT,
    sdl.K_LCTRL     = .CTRL,
    sdl.K_RCTRL     = .CTRL,
    sdl.K_LGUI      = .CTRL,
    sdl.K_RGUI      = .CTRL,
    sdl.K_LALT      = .ALT,
    sdl.K_RALT      = .ALT,
    sdl.K_BACKSPACE = .BACKSPACE,
    sdl.K_DELETE    = .DELETE,
    sdl.K_RETURN    = .RETURN,
    sdl.K_LEFT      = .LEFT,
    sdl.K_RIGHT     = .RIGHT,
    sdl.K_HOME      = .HOME,
    sdl.K_END       = .END,
    sdl.K_A         = .A,
    sdl.K_X         = .X,
    sdl.K_C         = .C,
    sdl.K_V         = .V,
}

on_microui_text_input :: proc(event : ^sdl.Event, state : ^AppState) {
    c_text := event.text.text
    if c_text == nil {
        return
    }

    text, err := strings.clone_from_cstring(c_text, context.temp_allocator)
    if err != .None {
        return
    }
    defer delete(text, context.temp_allocator)

    ch, size := utf8.decode_rune(text)
    if len(text) == size && unicode.is_print(ch) {
        mu.input_text(&state.ui_context, text)
    }
}

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

end_fractal_drag :: proc(state : ^AppState) -> sdl.AppResult {
    state.fractal.is_dragging = false
    ok := sdl.SetCursor(state.fractal.default_cursor)
    if !ok {
        log.errorf("unable to set default cursor: %s", sdl.GetError())
        return .FAILURE
    }
    return .CONTINUE
}
