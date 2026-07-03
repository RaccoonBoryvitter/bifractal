package main

import "base:runtime"
import "core:c"
import "core:log"

import mu "vendor:microui"
import sdl "vendor:sdl3"

@(export)
SDL_AppInit :: proc "c" (
    appstate: ^rawptr,
    argc: c.int,
    argv: [^]cstring,
) -> sdl.AppResult {
    context = runtime.default_context()
    state := init_app(context)
    if state == nil {
        return .FAILURE
    }

    appstate^ = rawptr(state)
    return .CONTINUE
}

@(export)
SDL_AppEvent :: proc "c" (
    appstate: rawptr,
    event: ^sdl.Event,
) -> sdl.AppResult {
    state := (^App_State)(appstate)
    context = state.ctx

    handle_ui_events(event, state)

    if event.type == .KEY_DOWN && event.key.key == sdl.K_F11 {
        window_flags := sdl.GetWindowFlags(state.window)
        is_fullscreen := .FULLSCREEN in window_flags
        sdl.SetWindowFullscreen(state.window, !is_fullscreen)
        return .CONTINUE
    }

    // Fractal input handling
    is_hover_active := state.ui_context.hover_root != nil
    fractal_result := handle_fractal_events(
        event,
        &state.fractal,
        state.gpu.device,
        &state.window_resolution,
        &state.gpu.texture,
        is_hover_active,
    )
    if fractal_result != .CONTINUE {
        return fractal_result
    }

    return .CONTINUE
}

fps_update :: proc(state: ^App_State) {
    state.fps_frame_count += 1
    now := sdl.GetTicks()
    elapsed := now - state.fps_last_ticks

    if elapsed >= FPS_INTERVAL_MS {
        state.fps_current =
            f32(state.fps_frame_count) / (f32(elapsed) / 1000.0)
        state.fps_frame_count = 0
        state.fps_last_ticks = now
    }
}

@(export)
SDL_AppIterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    state := (^App_State)(appstate)
    context = state.ctx
    defer free_all(context.temp_allocator)

    fps_update(state)
    create_ui(state)
    vertex_count := handle_mu_commands(state)

    return render_frame(state, vertex_count)
}

@(export)
SDL_AppQuit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
    state := (^App_State)(appstate)
    context = state.ctx

    sdl.DestroyCursor(state.fractal.move_cursor)
    sdl.DestroyCursor(state.fractal.default_cursor)

    sdl.ReleaseGPUBuffer(state.gpu.device, state.gpu.ui_vertex_buffer)
    sdl.ReleaseGPUTransferBuffer(
        state.gpu.device,
        state.gpu.ui_transfer_buffer,
    )
    sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.ui_font_texture)
    sdl.ReleaseGPUSampler(state.gpu.device, state.gpu.ui_font_sampler)
    sdl.ReleaseGPUGraphicsPipeline(state.gpu.device, state.gpu.ui_pipeline)

    sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.texture)
    sdl.ReleaseGPUComputePipeline(state.gpu.device, state.gpu.compute_pipeline)

    sdl.DestroyGPUDevice(state.gpu.device)
    sdl.DestroyWindow(state.window)
    sdl.Quit()

    log.destroy_console_logger(context.logger)
    free(state)
}
