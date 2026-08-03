package app

import "base:runtime"

import sdl "vendor:sdl3"

import im "deps:imgui"
import im_sdl "deps:imgui/imgui_impl_sdl3"
import im_sdlgpu "deps:imgui/imgui_impl_sdlgpu3"

import "../fractal"
import "../render"
import "../ui"

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

SDL_AppIterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    context = runtime.default_context()
    defer free_all(context.temp_allocator)

    state := (^App_Context)(appstate)
    context.logger = state.logger

    fps_update(state)

    im_sdl.NewFrame()
    im_sdlgpu.NewFrame()
    im.NewFrame()

    ui_view := ui.Ui_View {
        ui_state      = &state.ui,
        fractal       = &state.fractal,
        palette_state = &state.palette,
        events        = &state.events,
        window_size   = state.window.size,
        pixel_scale   = fractal.get_window_pixel_scale(state.window.handle),
        gpu_name      = state.gpu.name,
        gpu_driver    = state.gpu.driver,
        fps           = state.time.current,
        frame_time_ms = 1000.0 / max(state.time.current, 0.001),
    }
    ui.create_imgui_ui(&ui_view)

    app_dispatch_events(state)

    render_view := render.Render_View {
        gpu         = &state.gpu,
        fractal     = &state.fractal,
        kind        = state.fractal.kind,
        window      = state.window.handle,
        window_size = state.window.size,
    }
    return render.render_present_frame(&render_view)
}
