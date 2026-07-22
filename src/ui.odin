package main

import "base:runtime"
import "core:fmt"

import im "deps:imgui"
import sdl "vendor:sdl3"

create_imgui_ui :: proc(state: ^App_Context) {
    defer free_all(context.temp_allocator)

    im.SetNextWindowSize({360, 600}, .FirstUseEver)

    if !im.Begin("Sidebar", nil, {.NoSavedSettings}) {
        im.End()
        return
    }
    defer im.End()

    // View
    if im.CollapsingHeader("View", {.DefaultOpen}) {
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
            Vec2{mouse_x * scale.x, mouse_y * scale.y},
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

        if im.Button("Reset View") {
            append(&state.events.queue, View_Reset{})
        }
    }

    // Fractal
    if im.CollapsingHeader("Fractal", {.DefaultOpen}) {
        max_iter := state.fractal.params.max_iter
        if im.SliderInt(
            "Iterations",
            &max_iter,
            FRACTAL_MIN_ITERATIONS,
            FRACTAL_MAX_ITERATIONS,
        ) {
            append(&state.events.queue, Max_Iter_Changed{value = max_iter})
        }

        power := state.fractal.params.power
        if im.SliderFloat("Power", &power, 1.5, 6.0) {
            append(
                &state.events.queue,
                Mandelbrot_Power_Changed{value = power}
            )
        }
    }

    // Palette
    if im.CollapsingHeader("Palette", {.DefaultOpen}) {
        if draw_channel_button(
            "Red Channel",
            im.Vec4{1, 0, 0, 1},
        ) {
            state.ui.selected_channel = .Red
        }

        im.SameLine()
        if draw_channel_button(
            "Green Channel",
            im.Vec4{0, 1, 0, 1},
        ) {
            state.ui.selected_channel = .Green
        }

        im.SameLine()
        if draw_channel_button(
            "Blue Channel",
            im.Vec4{0, 0, 1, 1},
        ) {
            state.ui.selected_channel = .Blue
        }

        offset := state.fractal.params.palette.offset
        if draw_palette_params_slider(
            "Offset",
            &offset,
            state.ui.selected_channel,
        ) {
            append(
                &state.events.queue,
                Palette_Color_Changed {
                    kind = .Offset,
                    value = offset,
                },
            )
        }

        amplitude := state.fractal.params.palette.amplitude
        if draw_palette_params_slider(
            "Amplitude",
            &amplitude,
            state.ui.selected_channel,
        ) {
            append(
                &state.events.queue,
                Palette_Color_Changed {
                    kind = .Amplitude,
                    value = amplitude,
                },
            )
        }

        frequency := state.fractal.params.palette.frequency
        if draw_palette_params_slider(
            "Frequency",
            &frequency,
            state.ui.selected_channel,
        ) {
            append(
                &state.events.queue,
                Palette_Color_Changed {
                    kind = .Frequency,
                    value = frequency,
                },
            )
        }

        phase := state.fractal.params.palette.phase
        if draw_palette_params_slider(
            "Phase",
            &phase,
            state.ui.selected_channel,
        ) {
            append(
                &state.events.queue,
                Palette_Color_Changed {
                    kind = .Phase,
                    value = phase,
                },
            )
        }

        draw_list := im.GetWindowDrawList()

        draw_palette_waveform(
            state.fractal.params.palette,
            state.ui.selected_channel,
            draw_list,
            context.temp_allocator,
        )

        banded := state.palette.banded
        if im.Checkbox("Banded", &banded) {
            append(
                &state.events.queue,
                Palette_Banded_Changed{banded = banded},
            )
        }

        pos := im.GetCursorScreenPos()
        avail := im.GetContentRegionAvail()
        size := im.Vec2{avail.x, 40}
        im.Dummy(size)

        if (state.palette.banded) {
            draw_banded_gradient_swatch(
                draw_list,
                pos,
                size,
                &state.fractal.params,
            )
        }
         else {
            draw_gradient_swatch(draw_list, pos, size, &state.fractal.params)
        }

        if im.Button("Mirror") {
            append(&state.events.queue, Palette_Mirrored{})
        }
        im.SameLine()
        if im.Button("Randomize") {
            append(&state.events.queue, Palette_Randomized{})
        }
        im.SameLine()
        if im.Button("Rotate") {
            append(&state.events.queue, Palette_Rotated{delta = 0.05})
        }

        if im.CollapsingHeader("Presets", {}) {
            for preset in PALETTE_PRESETS {
                if im.Button(fmt.ctprintf(preset.name)) {
                    append(
                        &state.events.queue,
                        Palette_Preset_Applied{preset = preset},
                    )
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
    params: ^Fractal_Params,
) {
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

@(private = "file")
draw_banded_gradient_swatch :: proc(
    draw_list: ^im.DrawList,
    pos: im.Vec2,
    size: im.Vec2,
    params: ^Fractal_Params,
) {
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

@(private = "file")
PALETTE_WAVEFORM_SAMPLES :: 200

@(private = "file")
draw_palette_waveform :: proc(
    palette: Palette,
    selected_channel: Channel,
    draw_list: ^im.DrawList,
    allocator: runtime.Allocator,
) {
    samples := palette_create_samples(
        palette,
        PALETTE_WAVEFORM_SAMPLES,
        allocator,
    )

    pos := im.GetCursorScreenPos()
    avail := im.GetContentRegionAvail()
    plot_size := im.Vec2{avail.x, 100}

    r_points := make([]im.Vec2, PALETTE_WAVEFORM_SAMPLES, allocator)
    g_points := make([]im.Vec2, PALETTE_WAVEFORM_SAMPLES, allocator)
    b_points := make([]im.Vec2, PALETTE_WAVEFORM_SAMPLES, allocator)

    for sample, i in samples {
        t := f32(i) / f32(PALETTE_WAVEFORM_SAMPLES)
        x := pos.x + t * plot_size.x
        r_points[i] = {x, pos.y + (1.0 - sample.r) * plot_size.y}
        g_points[i] = {x, pos.y + (1.0 - sample.g) * plot_size.y}
        b_points[i] = {x, pos.y + (1.0 - sample.b) * plot_size.y}
    }

    im.Dummy(plot_size)

    red := im.GetColorU32ImVec4(im.Vec4{1, 0, 0, 1})
    im.DrawList_AddPolyline(
        draw_list,
        raw_data(r_points),
        i32(PALETTE_WAVEFORM_SAMPLES),
        red,
        selected_channel == .Red ? 3.0 : 1.0,
    )

    green := im.GetColorU32ImVec4(im.Vec4{0, 1, 0, 1})
    im.DrawList_AddPolyline(
        draw_list,
        raw_data(g_points),
        i32(PALETTE_WAVEFORM_SAMPLES),
        green,
        selected_channel == .Green ? 3.0 : 1.0,
    )

    blue := im.GetColorU32ImVec4(im.Vec4{0, 0, 1, 1})
    im.DrawList_AddPolyline(
        draw_list,
        raw_data(b_points),
        i32(PALETTE_WAVEFORM_SAMPLES),
        blue,
        selected_channel == .Blue ? 3.0 : 1.0,
    )
}

@(private = "file")
draw_channel_button :: proc(
    label: cstring,
    border_color: im.Vec4,
) -> bool {
    im.PushStyleVar(.FrameBorderSize, 1.0)
    defer im.PopStyleVar()

    im.PushStyleColor(.Border, im.GetColorU32ImVec4(border_color))
    defer im.PopStyleColor()

    return im.Button(label)
}

@(private = "file")
draw_palette_params_slider :: proc(
    label: cstring,
    palette_param: ^[4]f32,
    selected_channel: Channel,
) -> bool {
    switch selected_channel {
    case .Red:
        return im.SliderFloat(
            label,
            &palette_param.r,
            0.0,
            1.0,
            "%.3f",
            {.ClampOnInput},
        )
    case .Green:
        return im.SliderFloat(
            label,
            &palette_param.g,
            0.0,
            1.0,
            "%.3f",
            {.ClampOnInput},
        )
    case .Blue:
        return im.SliderFloat(
            label,
            &palette_param.b,
            0.0,
            1.0,
            "%.3f",
            {.ClampOnInput},
        )
    }
    return false
}
