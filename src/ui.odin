#+feature dynamic-literals
package main

import "base:runtime"
import "core:math/rand"

import "core:fmt"

import imgui "deps:imgui"
import sdl "vendor:sdl3"

// Types

@(private = "file")
RGBA8 :: distinct [4]u8


create_imgui_ui :: proc(state: ^App_State) {
    defer free_all(context.temp_allocator)

    imgui.SetNextWindowSize({360, 600}, .FirstUseEver)

    if !imgui.Begin("Sidebar", nil, {.NoSavedSettings}) {
        imgui.End()
        return
    }
    defer imgui.End()

    // Navigation
    if imgui.CollapsingHeader("Navigation", {.DefaultOpen}) {
        imgui.Text(fmt.ctprintf("Zoom: %s", format_zoom(state.fractal.uniform.zoom)))
        imgui.Text(
            fmt.ctprintf(
                "Center: %+.6f %+.6fi",
                state.fractal.uniform.center.x,
                state.fractal.uniform.center.y,
            ),
        )

        mouse_x, mouse_y: f32
        _ = sdl.GetMouseState(&mouse_x, &mouse_y)
        scale := get_window_pixel_scale(state.window)
        state.mouse_complex = screen_to_complex(
            mouse_x * scale.x,
            mouse_y * scale.y,
            state.window_resolution,
            state.fractal.uniform.center,
            state.fractal.uniform.zoom,
        )
        imgui.Text(
            fmt.ctprintf(
                "Mouse: %+.6f %+.6fi",
                real(state.mouse_complex),
                imag(state.mouse_complex),
            ),
        )

        imgui.SliderInt(
            "Iterations",
            &state.fractal.uniform.max_iter,
            FRACTAL_MIN_ITERATIONS,
            FRACTAL_MAX_ITERATIONS,
        )

        if imgui.Button("Reset View") {
            reset_fractal_view(
                &state.fractal.uniform,
                &state.fractal.zoom_level,
            )
        }
    }

    // Palette
    if imgui.CollapsingHeader("Palette", {.DefaultOpen}) {
        imgui.Checkbox("Banded", &state.palette_banded)

        draw_list := imgui.GetWindowDrawList()
        pos := imgui.GetCursorScreenPos()
        avail := imgui.GetContentRegionAvail()
        size := imgui.Vec2{avail.x, 40}
        imgui.Dummy(size)

        draw_gradient_swatch(
            draw_list,
            pos,
            size,
            state.palette_banded,
            &state.fractal.uniform,
        )

        if imgui.Button("Mirror") {
            mirror_palette(&state.fractal.uniform)
        }
        imgui.SameLine()
        if imgui.Button("Randomize") {
            randomize_palette(
                &state.fractal.uniform,
                rand.default_random_generator(&state.rand_state),
            )
        }
        imgui.SameLine()
        if imgui.Button("Rotate") {
            rotate_palette(&state.fractal.uniform, 0.05)
        }

        imgui.ColorEdit4("a", &state.fractal.uniform.palette_a, {.NoAlpha})
        imgui.ColorEdit4("b", &state.fractal.uniform.palette_b, {.NoAlpha})
        imgui.ColorEdit4("c", &state.fractal.uniform.palette_c, {.NoAlpha})
        imgui.ColorEdit4("d", &state.fractal.uniform.palette_d, {.NoAlpha})

        if imgui.CollapsingHeader("Presets", {}) {
            for preset in palette_presets {
                if imgui.Button(fmt.ctprintf(preset.name)) {
                    apply_palette_preset(&state.fractal.uniform, preset)
                }
                imgui.SameLine()
                draw_preset_swatch(draw_list, preset)
            }
        }
    }

    // Stats
    if imgui.CollapsingHeader("Stats", {.DefaultOpen}) {
        imgui.Text(fmt.ctprintf("FPS: %.1f", state.fps_current))
        imgui.Text(
            fmt.ctprintf(
                "Frame time: %.2f ms",
                1000.0 / max(state.fps_current, 0.001),
            ),
        )
        imgui.Text(fmt.ctprintf("GPU: %s", state.gpu_name))
        imgui.Text(fmt.ctprintf("Graphics API: %s", state.gpu_driver))
        imgui.Text(
            fmt.ctprintf(
                "Resolution: %dx%d",
                state.window_resolution.w,
                state.window_resolution.h,
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
    draw_list: ^imgui.DrawList,
    pos: imgui.Vec2,
    size: imgui.Vec2,
    banded: bool,
    uniform: ^Fractal_Uniform,
) {
    if banded {
        bands := clamp(uniform.max_iter, FRACTAL_MIN_ITERATIONS, i32(PALETTE_SWATCH_STEPS))
        step_w := size.x / f32(bands)
        for i in 0 ..< bands {
            t := f32(i) / f32(bands)
            color := cosine_palette_cpu(t, uniform.palette_a, uniform.palette_b, uniform.palette_c, uniform.palette_d)
            col := imgui.ColorConvertFloat4ToU32({color.r, color.g, color.b, 1})
            x0 := pos.x + f32(i) * step_w
            x1 := x0 + step_w + 1
            imgui.DrawList_AddRectFilled(draw_list, {x0, pos.y}, {x1, pos.y + size.y}, col)
        }
    } else {
        step_w := size.x / f32(PALETTE_SWATCH_STEPS)
        for i in 0 ..< PALETTE_SWATCH_STEPS {
            t := f32(i) / f32(PALETTE_SWATCH_STEPS - 1)
            color := cosine_palette_cpu(t, uniform.palette_a, uniform.palette_b, uniform.palette_c, uniform.palette_d)
            col := imgui.ColorConvertFloat4ToU32({color.r, color.g, color.b, 1})
            x0 := pos.x + f32(i) * step_w
            x1 := x0 + step_w + 1
            imgui.DrawList_AddRectFilled(draw_list, {x0, pos.y}, {x1, pos.y + size.y}, col)
        }
    }
}

@(private = "file")
draw_preset_swatch :: proc(draw_list: ^imgui.DrawList, preset: Palette_Preset) {
    pos := imgui.GetCursorScreenPos()
    avail := imgui.GetContentRegionAvail()
    size := imgui.Vec2{avail.x, imgui.GetFrameHeight()}
    imgui.Dummy(size)

    step_w := size.x / f32(PALETTE_PRESET_SWATCH_STEPS)
    for i in 0 ..< PALETTE_PRESET_SWATCH_STEPS {
        t := f32(i) / f32(PALETTE_PRESET_SWATCH_STEPS - 1)
        color := cosine_palette_cpu(t, preset.a, preset.b, preset.c, preset.d)
        col := imgui.ColorConvertFloat4ToU32({color.r, color.g, color.b, 1})
        x0 := pos.x + f32(i) * step_w
        x1 := x0 + step_w + 1
        imgui.DrawList_AddRectFilled(draw_list, {x0, pos.y}, {x1, pos.y + size.y}, col)
    }
}
