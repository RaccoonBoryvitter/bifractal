#+feature dynamic-literals
package main

import "base:runtime"
import "core:math/rand"

import "core:fmt"

import im "deps:imgui"
import sdl "vendor:sdl3"

// Types

@(private = "file")
RGBA8 :: distinct [4]u8


create_imgui_ui :: proc(state: ^App_Context) {
    defer free_all(context.temp_allocator)

    im.SetNextWindowSize({360, 600}, .FirstUseEver)

    if !im.Begin("Sidebar", nil, {.NoSavedSettings}) {
        im.End()
        return
    }
    defer im.End()

    // Navigation
    if im.CollapsingHeader("Navigation", {.DefaultOpen}) {
        im.Text(
            fmt.ctprintf(
                "Zoom: %s",
                format_zoom(state.fractal.camera.view.zoom),
            ),
        )
        im.Text(
            fmt.ctprintf(
                "Center: %+.6f %+.6fi",
                state.fractal.camera.view.center.x,
                state.fractal.camera.view.center.y,
            ),
        )

        mouse_x, mouse_y: f32
        _ = sdl.GetMouseState(&mouse_x, &mouse_y)
        scale := get_window_pixel_scale(state.window.handle)
        state.ui.mouse_complex = view_screen_to_complex(
            {mouse_x * scale.x, mouse_y * scale.y},
            state.window.size,
            state.fractal.camera.view,
        )
        im.Text(
            fmt.ctprintf(
                "Mouse: %+.6f %+.6fi",
                real(state.ui.mouse_complex),
                imag(state.ui.mouse_complex),
            ),
        )

        im.SliderInt(
            "Iterations",
            &state.fractal.params.max_iter,
            FRACTAL_MIN_ITERATIONS,
            FRACTAL_MAX_ITERATIONS,
        )

        if im.Button("Reset View") {
            reset_fractal_view(
                &state.fractal.camera.view,
                &state.fractal.params,
                &state.fractal.zoom_level,
            )
        }
    }

    // Palette
    if im.CollapsingHeader("Palette", {.DefaultOpen}) {
        im.Checkbox("Banded", &state.palette.banded)

        draw_list := im.GetWindowDrawList()
        pos := im.GetCursorScreenPos()
        avail := im.GetContentRegionAvail()
        size := im.Vec2{avail.x, 40}
        im.Dummy(size)

        draw_gradient_swatch(
            draw_list,
            pos,
            size,
            state.palette.banded,
            &state.fractal.params,
        )

        if im.Button("Mirror") {
            mirror_palette(&state.fractal.params.palette)
        }
        im.SameLine()
        if im.Button("Randomize") {
            randomize_palette(
                &state.fractal.params.palette,
                rand.default_random_generator(&state.palette.rand_state),
            )
        }
        im.SameLine()
        if im.Button("Rotate") {
            rotate_palette(&state.fractal.params.palette, 0.05)
        }

        im.ColorEdit4(
            "Offset",
            &state.fractal.params.palette.offset,
            {.NoAlpha},
        )
        im.ColorEdit4(
            "Amplitude",
            &state.fractal.params.palette.amplitude,
            {.NoAlpha},
        )
        im.ColorEdit4(
            "Frequency",
            &state.fractal.params.palette.frequency,
            {.NoAlpha},
        )
        im.ColorEdit4(
            "Phase",
            &state.fractal.params.palette.phase,
            {.NoAlpha},
        )

        if im.CollapsingHeader("Presets", {}) {
            for preset in PALETTE_PRESETS {
                if im.Button(fmt.ctprintf(preset.name)) {
                    apply_palette_preset(&state.fractal.params.palette, preset)
                }
                im.SameLine()
                draw_preset_swatch(draw_list, preset)
            }
        }
    }

    // Stats
    if im.CollapsingHeader("Stats", {.DefaultOpen}) {
        im.Text(fmt.ctprintf("FPS: %.1f", state.time.current))
        im.Text(
            fmt.ctprintf(
                "Frame time: %.2f ms",
                1000.0 / max(state.time.current, 0.001),
            ),
        )
        im.Text(fmt.ctprintf("GPU: %s", state.gpu.name))
        im.Text(fmt.ctprintf("Graphics API: %s", state.gpu.driver))
        im.Text(
            fmt.ctprintf(
                "Resolution: %dx%d",
                state.window.size.w,
                state.window.size.h,
            ),
        )
    }
}

@(private = "file")
format_zoom :: proc(zoom: f32) -> string {
    if zoom > 1_000_000 || zoom < 0.000_001 {
        return fmt.tprintf("%e", zoom)
    }
    return fmt.tprintf("%.4f", zoom)
}

@(private = "file")
draw_gradient_swatch :: proc(
    draw_list: ^im.DrawList,
    pos: im.Vec2,
    size: im.Vec2,
    banded: bool,
    params: ^Fractal_Params,
) {
    if banded {
        bands := clamp(
            params.max_iter,
            FRACTAL_MIN_ITERATIONS,
            i32(PALETTE_SWATCH_STEPS),
        )
        step_w := size.x / f32(bands)
        for i in 0 ..< bands {
            t := f32(i) / f32(bands)
            color := cosine_palette_cpu(t, params.palette)
            col := im.ColorConvertFloat4ToU32({color.r, color.g, color.b, 1})
            x0 := pos.x + f32(i) * step_w
            x1 := x0 + step_w + 1
            im.DrawList_AddRectFilled(
                draw_list,
                {x0, pos.y},
                {x1, pos.y + size.y},
                col,
            )
        }
    }
     else {
        step_w := size.x / f32(PALETTE_SWATCH_STEPS)
        for i in 0 ..< PALETTE_SWATCH_STEPS {
            t := f32(i) / f32(PALETTE_SWATCH_STEPS - 1)
            color := cosine_palette_cpu(t, params.palette)
            col := im.ColorConvertFloat4ToU32({color.r, color.g, color.b, 1})
            x0 := pos.x + f32(i) * step_w
            x1 := x0 + step_w + 1
            im.DrawList_AddRectFilled(
                draw_list,
                {x0, pos.y},
                {x1, pos.y + size.y},
                col,
            )
        }
    }
}

@(private = "file")
draw_preset_swatch :: proc(draw_list: ^im.DrawList, preset: Palette_Preset) {
    pos := im.GetCursorScreenPos()
    avail := im.GetContentRegionAvail()
    size := im.Vec2{avail.x, im.GetFrameHeight()}
    im.Dummy(size)

    step_w := size.x / f32(PALETTE_PRESET_SWATCH_STEPS)
    for i in 0 ..< PALETTE_PRESET_SWATCH_STEPS {
        t := f32(i) / f32(PALETTE_PRESET_SWATCH_STEPS - 1)
        color := cosine_palette_cpu(t, preset.palette)
        col := im.ColorConvertFloat4ToU32({color.r, color.g, color.b, 1})
        x0 := pos.x + f32(i) * step_w
        x1 := x0 + step_w + 1
        im.DrawList_AddRectFilled(
            draw_list,
            {x0, pos.y},
            {x1, pos.y + size.y},
            col,
        )
    }
}
