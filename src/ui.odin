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

    if im.BeginTabBar("SidebarTabs") {
        if im.BeginTabItem("View") {
            draw_view_tab(state)
            im.EndTabItem()
        }

        if im.BeginTabItem("Fractal") {
            draw_fractal_tab(state)
            im.EndTabItem()
        }

        if im.BeginTabItem("Palette") {
            draw_palette_tab(state)
            im.EndTabItem()
        }

        if im.BeginTabItem("Stats") {
            draw_stats_tab(state)
            im.EndTabItem()
        }

        im.EndTabBar()
    }
}

@(private = "file")
draw_view_tab :: proc(state: ^App_Context) {
    im.Text(
        fmt.ctprintf(
            "Zoom: %s",
            format_zoom(state.fractal.base.camera.view.zoom),
        ),
    )
    im.Text(
        fmt.ctprintf(
            "Center: %+.6f %+.6fi",
            state.fractal.base.camera.view.center.x,
            state.fractal.base.camera.view.center.y,
        ),
    )

    mouse_x, mouse_y: f32
    _ = sdl.GetMouseState(&mouse_x, &mouse_y)
    scale := get_window_pixel_scale(state.window.handle)
    state.ui.mouse_complex = view_screen_to_complex(
        {mouse_x * scale.x, mouse_y * scale.y},
        state.window.size,
        state.fractal.base.camera.view,
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

@(private = "file")
draw_fractal_tab :: proc(state: ^App_Context) {
    max_iter := state.fractal.base.max_iter
    if im.SliderInt(
        "Iterations",
        &max_iter,
        FRACTAL_MIN_ITERATIONS,
        FRACTAL_MAX_ITERATIONS,
    ) {
        append(&state.events.queue, Max_Iter_Changed{value = max_iter})
    }

    switch d in state.fractal.data {
    case Mandelbrot_Data:
        power := d.power
        if im.SliderFloat("Power", &power, 1.5, 6.0) {
            append(
                &state.events.queue,
                Mandelbrot_Power_Changed{value = power},
            )
        }
    }
}

@(private = "file")
draw_palette_tab :: proc(state: ^App_Context) {
    interior_color := state.fractal.base.interior_color.rgb
    if im.ColorEdit3("Interior", &interior_color) {
        append(
            &state.events.queue,
            Interior_Color_Changed{value = interior_color},
        )
    }

    new_channel := draw_channels_radio_buttons(state.ui.selected_channel)
    if new_channel != nil {
        state.ui.selected_channel = new_channel.(Channel)
    }

    offset := state.fractal.base.palette.offset
    if draw_palette_params_slider(
        "Offset",
        &offset,
        state.ui.selected_channel,
    ) {
        append(
            &state.events.queue,
            Palette_Color_Changed{kind = .Offset, value = offset},
        )
    }

    amplitude := state.fractal.base.palette.amplitude
    if draw_palette_params_slider(
        "Amplitude",
        &amplitude,
        state.ui.selected_channel,
    ) {
        append(
            &state.events.queue,
            Palette_Color_Changed{kind = .Amplitude, value = amplitude},
        )
    }

    frequency := state.fractal.base.palette.frequency
    if draw_palette_params_slider(
        "Frequency",
        &frequency,
        state.ui.selected_channel,
    ) {
        append(
            &state.events.queue,
            Palette_Color_Changed{kind = .Frequency, value = frequency},
        )
    }

    phase := state.fractal.base.palette.phase
    if draw_palette_params_slider("Phase", &phase, state.ui.selected_channel) {
        append(
            &state.events.queue,
            Palette_Color_Changed{kind = .Phase, value = phase},
        )
    }

    draw_list := im.GetWindowDrawList()

    draw_palette_waveform(
        state.fractal.base.palette,
        state.ui.selected_channel,
        draw_list,
        context.temp_allocator,
    )

    banded := state.palette.banded
    if im.Checkbox("Banded", &banded) {
        append(&state.events.queue, Palette_Banded_Changed{banded = banded})
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
            state.fractal.base.max_iter,
            state.fractal.base.palette,
        )
    }
     else {
        draw_gradient_swatch(draw_list, pos, size, state.fractal.base.palette)
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

@(private = "file")
draw_stats_tab :: proc(state: ^App_Context) {
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
    palette: Palette,
) {
    step_w := size.x / f32(PALETTE_SWATCH_STEPS)
    for i in 0 ..< PALETTE_SWATCH_STEPS {
        t := f32(i) / f32(PALETTE_SWATCH_STEPS - 1)
        color := cosine_palette_cpu(t, palette)
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
    max_iter: i32,
    palette: Palette,
) {
    bands := clamp(max_iter, FRACTAL_MIN_ITERATIONS, i32(PALETTE_SWATCH_STEPS))
    step_w := size.x / f32(bands)
    for i in 0 ..< bands {
        t := f32(i) / f32(bands)
        color := cosine_palette_cpu(t, palette)
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
channel_to_vec4 :: proc(channel: Channel) -> im.Vec4 {
    switch channel {
    case .Red:
        return im.Vec4{1, 0, 0, 1}
    case .Green:
        return im.Vec4{0, 1, 0, 1}
    case .Blue:
        return im.Vec4{0, 0, 1, 1}
    }
    return im.Vec4{0, 0, 0, 0}
}

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

    red := im.GetColorU32ImVec4(channel_to_vec4(.Red))
    im.DrawList_AddPolyline(
        draw_list,
        raw_data(r_points),
        i32(PALETTE_WAVEFORM_SAMPLES),
        red,
        selected_channel == .Red ? 3.0 : 1.0,
    )

    green := im.GetColorU32ImVec4(channel_to_vec4(.Green))
    im.DrawList_AddPolyline(
        draw_list,
        raw_data(g_points),
        i32(PALETTE_WAVEFORM_SAMPLES),
        green,
        selected_channel == .Green ? 3.0 : 1.0,
    )

    blue := im.GetColorU32ImVec4(channel_to_vec4(.Blue))
    im.DrawList_AddPolyline(
        draw_list,
        raw_data(b_points),
        i32(PALETTE_WAVEFORM_SAMPLES),
        blue,
        selected_channel == .Blue ? 3.0 : 1.0,
    )
}

@(private = "file")
draw_channels_radio_buttons :: proc(
    selected_channel: Channel,
) -> Maybe(Channel) {
    im.BeginGroup()
    defer im.EndGroup()

    im.Text("Channels")

    new_channel: Maybe(Channel) = nil

    im.PushStyleColorImVec4(.CheckMark, channel_to_vec4(.Red))
    if im.RadioButton(
        fmt.ctprintf("%s", Channel.Red),
        selected_channel == .Red,
    ) {
        new_channel = .Red
    }
    im.PopStyleColor()

    im.SameLine()
    im.PushStyleColorImVec4(.CheckMark, channel_to_vec4(.Green))
    if im.RadioButton(
        fmt.ctprintf("%s", Channel.Green),
        selected_channel == .Green,
    ) {
        new_channel = .Green
    }
    im.PopStyleColor()

    im.SameLine()
    im.PushStyleColorImVec4(.CheckMark, channel_to_vec4(.Blue))
    if im.RadioButton(
        fmt.ctprintf("%s", Channel.Blue),
        selected_channel == .Blue,
    ) {
        new_channel = .Blue
    }
    im.PopStyleColor()

    return new_channel
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
