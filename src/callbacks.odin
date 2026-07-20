package main

import "base:runtime"
import "core:c"
import "core:log"

import sdl "vendor:sdl3"

import im "deps:imgui"
import im_sdl "deps:imgui/imgui_impl_sdl3"
import im_sdlgpu "deps:imgui/imgui_impl_sdlgpu3"

@(export)
SDL_AppInit :: proc "c" (
    appstate: ^rawptr,
    argc: c.int,
    argv: [^]cstring,
) -> sdl.AppResult {
    context = runtime.default_context()
    state := init_app()
    if state == nil {
        return .FAILURE
    }
    context.logger = state.logger

    appstate^ = rawptr(state)
    return .CONTINUE
}

@(export)
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
                Window_Resized{size = Extent_2D{u32(pixel_w), u32(pixel_h)}},
            )
        }
        return .CONTINUE
    }

    io := im.GetIOImGuiContextPtr(state.ui.ctx)
    is_mouse_captured := io.WantCaptureMouse || im.IsAnyItemHovered()
    input := fractal_process_input(
        &state.fractal,
        event,
        state.window.handle,
        is_mouse_captured,
        io.WantCaptureKeyboard,
    )
    fractal_apply_command(&state.fractal, input, state.window.handle)

    return .CONTINUE
}

fps_update :: proc(state: ^App_Context) {
    state.time.frame_count += 1
    now := sdl.GetTicks()
    elapsed := now - state.time.last_ticks

    if elapsed >= FPS_INTERVAL_MS {
        state.time.current =
            f32(state.time.frame_count) / (f32(elapsed) / 1000.0)
        state.time.frame_count = 0
        state.time.last_ticks = now
    }
}

@(export)
SDL_AppIterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    context = runtime.default_context()
    defer free_all(context.temp_allocator)

    state := (^App_Context)(appstate)
    context.logger = state.logger

    fps_update(state)

    im_sdl.NewFrame()
    im_sdlgpu.NewFrame()
    im.NewFrame()

    create_imgui_ui(state)
    app_dispatch_events(state)

    return render_present_frame(state)
}

@(export)
SDL_AppQuit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
    context = runtime.default_context()
    state := (^App_Context)(appstate)
    if state != nil {
        context.logger = state.logger
        destroy_app(state)
    }
}
