package main

import "base:runtime"
import "core:c"
import "core:log"

import sdl "vendor:sdl3"

import imgui "deps:imgui"
import imgui_impl_sdl3 "deps:imgui/imgui_impl_sdl3"
import imgui_impl_sdlgpu3 "deps:imgui/imgui_impl_sdlgpu3"

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

    appstate^ = rawptr(state)
    return .CONTINUE
}

@(export)
SDL_AppEvent :: proc "c" (
    appstate: rawptr,
    event: ^sdl.Event,
) -> sdl.AppResult {
    context = runtime.default_context()
    state := (^App_State)(appstate)

    imgui_impl_sdl3.ProcessEvent(event)

    if event.type == .KEY_DOWN && event.key.key == sdl.K_F11 {
        window_flags := sdl.GetWindowFlags(state.window)
        is_fullscreen := .FULLSCREEN in window_flags
        sdl.SetWindowFullscreen(state.window, !is_fullscreen)
        return .CONTINUE
    }

    io := imgui.GetIOImGuiContextPtr(state.imgui.ctx)
    is_mouse_captured := io.WantCaptureMouse || imgui.IsAnyItemHovered()
    fractal_result := handle_fractal_events(
        event,
        &state.fractal,
        state.gpu.device,
        &state.window_resolution,
        &state.gpu.texture,
        state.window,
        is_mouse_captured,
        io.WantCaptureKeyboard,
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
    context = runtime.default_context()
    defer free_all(context.temp_allocator)

    state := (^App_State)(appstate)

    fps_update(state)

    imgui_impl_sdl3.NewFrame()
    imgui_impl_sdlgpu3.NewFrame()
    imgui.NewFrame()

    create_imgui_ui(state)

    return render_frame(state)
}

@(export)
SDL_AppQuit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
    context = runtime.default_context()
    state := (^App_State)(appstate)

    imgui_impl_sdlgpu3.Shutdown()
    imgui_impl_sdl3.Shutdown()
    imgui.DestroyContext(state.imgui.ctx)

    sdl.DestroyCursor(state.fractal.move_cursor)
    sdl.DestroyCursor(state.fractal.default_cursor)

    // microui UI resources disabled
    // sdl.ReleaseGPUBuffer(state.gpu.device, state.gpu.ui_vertex_buffer)
    // sdl.ReleaseGPUTransferBuffer(
    //     state.gpu.device,
    //     state.gpu.ui_transfer_buffer,
    // )
    // sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.ui_font_texture)
    // sdl.ReleaseGPUSampler(state.gpu.device, state.gpu.ui_font_sampler)
    // sdl.ReleaseGPUGraphicsPipeline(state.gpu.device, state.gpu.ui_pipeline)

    sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.texture)
    sdl.ReleaseGPUComputePipeline(state.gpu.device, state.gpu.compute_pipeline)

    sdl.DestroyGPUDevice(state.gpu.device)
    sdl.DestroyWindow(state.window)
    sdl.Quit()

    log.destroy_console_logger(context.logger)
    free(state)
}
