package app

import "base:runtime"

import sdl "vendor:sdl3"

import im "deps:imgui"
import im_sdl "deps:imgui/imgui_impl_sdl3"
import im_sdlgpu "deps:imgui/imgui_impl_sdlgpu3"

import "../fractal"
import "../render"
import "../settings"
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

update_mouse_complex :: proc(state: ^App_Context) {
    mouse_x, mouse_y: f32
    _ = sdl.GetMouseState(&mouse_x, &mouse_y)
    state.ui.mouse_complex = fractal.view_screen_to_complex(
        {
            mouse_x * state.window.pixel_scale.x,
            mouse_y * state.window.pixel_scale.y,
        },
        state.window.size,
        state.fractal.base.camera.view,
    )
}

SDL_AppIterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    context = runtime.default_context()
    defer free_all(context.temp_allocator)

    state := (^App_Context)(appstate)
    context.logger = state.logger

    fps_update(state)
    update_mouse_complex(state)

    im_sdl.NewFrame()
    im_sdlgpu.NewFrame()
    im.NewFrame()

    _ = render.tick_toast(&state.save, sdl.GetTicks())

    ui_view := ui.Ui_View {
        ui_state      = &state.ui,
        fractal       = &state.fractal,
        palette_state = &state.palette,
        events        = &state.events,
        settings      = state.settings.settings,
        toast         = render.get_toast(&state.save),
        window_size   = state.window.size,
        pixel_scale   = state.window.pixel_scale,
        gpu_name      = state.gpu.name,
        gpu_driver    = state.gpu.driver,
        fps           = state.time.current,
        frame_time_ms = 1000.0 / max(state.time.current, 0.001),
    }
    ui.create_imgui_ui(&ui_view)
    ui.draw_hud(&ui_view)
    ui.draw_toast(&ui_view)

    if ui_view.settings_changed {
        state.settings.settings = ui_view.settings
        state.settings.dirty = true
        ui_view.settings_changed = false
    }

    if ui_view.settings_save {
        ui_view.settings_save = false
        _ = settings.save(&state.settings)
    }

    app_dispatch_events(state)

    render_view := render.Render_View {
        gpu         = &state.gpu,
        fractal     = &state.fractal,
        kind        = state.fractal.kind,
        window      = state.window.handle,
        window_size = state.window.size,
    }
    result := render.render_present_frame(&render_view)

    _ = render.process_save(&state.save, &state.gpu, state.window.size)

    return result
}
