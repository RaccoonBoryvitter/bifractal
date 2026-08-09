package app

import "base:runtime"

import sdl "vendor:sdl3"

import im "deps:imgui"
import im_sdl "deps:imgui/imgui_impl_sdl3"

import "../events"
import "../fractal"
import "../geom"

SDL_AppEvent :: proc "c" (
    appstate: rawptr,
    event: ^sdl.Event,
) -> sdl.AppResult {
    context = runtime.default_context()
    state := (^App_Context)(appstate)
    context.logger = state.logger

    im_sdl.ProcessEvent(event)

    if event.type == .KEY_DOWN && event.key.key == sdl.K_F11 {
        window_flags := sdl.GetWindowFlags(state.window.handle)
        is_fullscreen := .FULLSCREEN in window_flags
        sdl.SetWindowFullscreen(state.window.handle, !is_fullscreen)
        return .CONTINUE
    }

    if event.type == .KEY_DOWN && event.key.key == sdl.K_S {
        mod := sdl.GetModState()
        if .LCTRL in mod || .RCTRL in mod {
            append(&state.events.queue, events.Image_Save_Requested{})
            return .CONTINUE
        }
    }

    if event.type == .QUIT || event.type == .WINDOW_CLOSE_REQUESTED {
        return .SUCCESS
    }

    if event.type == .WINDOW_RESIZED ||
       event.type == .WINDOW_PIXEL_SIZE_CHANGED {
        if event.window.windowID == sdl.GetWindowID(state.window.handle) {
            pixel_w, pixel_h: i32
            sdl.GetWindowSizeInPixels(state.window.handle, &pixel_w, &pixel_h)
            append(
                &state.events.queue,
                events.Window_Resized {
                    size = geom.Extent_2D{u32(pixel_w), u32(pixel_h)},
                },
            )
        }
        return .CONTINUE
    }

    io := im.GetIOImGuiContextPtr(state.ui.ctx)
    is_mouse_captured := io.WantCaptureMouse || im.IsAnyItemHovered()
    input := fractal.fractal_process_input(
        &state.fractal,
        event,
        state.window.handle,
        is_mouse_captured,
        io.WantCaptureKeyboard,
    )
    fractal.fractal_apply_command(&state.fractal, input, state.window.handle)
    sync_drag_cursor(state)

    return .CONTINUE
}
