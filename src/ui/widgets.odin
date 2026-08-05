package ui

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:reflect"

import im "deps:imgui"

import "../events"
import "../fractal"
import "../palette"

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
    p: palette.Palette,
) {
    step_w := size.x / f32(palette.PALETTE_SWATCH_STEPS)
    for i in 0 ..< palette.PALETTE_SWATCH_STEPS {
        t := f32(i) / f32(palette.PALETTE_SWATCH_STEPS - 1)
        color := palette.cosine_palette_cpu(t, p)
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
    p: palette.Palette,
) {
    bands := clamp(
        max_iter,
        fractal.FRACTAL_MIN_ITERATIONS,
        i32(palette.PALETTE_SWATCH_STEPS),
    )
    step_w := size.x / f32(bands)
    for i in 0 ..< bands {
        t := f32(i) / f32(bands)
        color := palette.cosine_palette_cpu(t, p)
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
draw_preset_swatch :: proc(
    draw_list: ^im.DrawList,
    preset: palette.Palette_Preset,
) {
    pos := im.GetCursorScreenPos()
    avail := im.GetContentRegionAvail()
    size := im.Vec2{avail.x, im.GetFrameHeight()}
    im.Dummy(size)

    step_w := size.x / f32(palette.PALETTE_PRESET_SWATCH_STEPS)
    for i in 0 ..< palette.PALETTE_PRESET_SWATCH_STEPS {
        t := f32(i) / f32(palette.PALETTE_PRESET_SWATCH_STEPS - 1)
        color := palette.cosine_palette_cpu(t, preset.palette)
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
    p: palette.Palette,
    selected_channel: Channel,
    draw_list: ^im.DrawList,
    allocator: runtime.Allocator,
) {
    samples := palette.palette_create_samples(
        p,
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

draw_palette_tab :: proc(view: ^Ui_View) {
    interior_color := view.fractal.base.interior_color.rgb
    if im.ColorEdit3("Interior", &interior_color) {
        append(
            &view.events.queue,
            events.Interior_Color_Changed{value = interior_color},
        )
    }

    new_channel := draw_channels_radio_buttons(view.ui_state.selected_channel)
    if new_channel != nil {
        view.ui_state.selected_channel = new_channel.(Channel)
    }

    offset := view.fractal.base.palette.offset
    if draw_palette_params_slider(
        "Offset",
        &offset,
        view.ui_state.selected_channel,
    ) {
        append(
            &view.events.queue,
            events.Palette_Color_Changed{kind = .Offset, value = offset},
        )
    }

    amplitude := view.fractal.base.palette.amplitude
    if draw_palette_params_slider(
        "Amplitude",
        &amplitude,
        view.ui_state.selected_channel,
    ) {
        append(
            &view.events.queue,
            events.Palette_Color_Changed{kind = .Amplitude, value = amplitude},
        )
    }

    frequency := view.fractal.base.palette.frequency
    if draw_palette_params_slider(
        "Frequency",
        &frequency,
        view.ui_state.selected_channel,
    ) {
        append(
            &view.events.queue,
            events.Palette_Color_Changed{kind = .Frequency, value = frequency},
        )
    }

    phase := view.fractal.base.palette.phase
    if draw_palette_params_slider(
        "Phase",
        &phase,
        view.ui_state.selected_channel,
    ) {
        append(
            &view.events.queue,
            events.Palette_Color_Changed{kind = .Phase, value = phase},
        )
    }

    draw_list := im.GetWindowDrawList()

    draw_palette_waveform(
        view.fractal.base.palette,
        view.ui_state.selected_channel,
        draw_list,
        context.temp_allocator,
    )

    banded := view.palette_state.banded
    if im.Checkbox("Banded", &banded) {
        append(
            &view.events.queue,
            events.Palette_Banded_Changed{banded = banded},
        )
    }

    pos := im.GetCursorScreenPos()
    avail := im.GetContentRegionAvail()
    size := im.Vec2{avail.x, 40}
    im.Dummy(size)

    if view.palette_state.banded {
        draw_banded_gradient_swatch(
            draw_list,
            pos,
            size,
            view.fractal.base.max_iter,
            view.fractal.base.palette,
        )
    }
     else {
        draw_gradient_swatch(draw_list, pos, size, view.fractal.base.palette)
    }

    if im.Button("Mirror") {
        append(&view.events.queue, events.Palette_Mirrored{})
    }
    im.SameLine()
    if im.Button("Randomize") {
        append(&view.events.queue, events.Palette_Randomized{})
    }
    im.SameLine()
    if im.Button("Rotate") {
        append(&view.events.queue, events.Palette_Rotated{delta = 0.05})
    }

    if im.CollapsingHeader("Presets", {}) {
        for preset in palette.PALETTE_PRESETS {
            if im.Button(fmt.ctprintf(preset.name)) {
                append(
                    &view.events.queue,
                    events.Palette_Preset_Applied{preset = preset},
                )
            }
            im.SameLine()
            draw_preset_swatch(draw_list, preset)
        }
    }
}

draw_enum_slider :: proc(
    label: cstring,
    value: ^$T,
) -> (
    changed: bool,
) where intrinsics.type_is_enum(T) {
    values := reflect.enum_field_values(T)
    n := i32(len(values))
    if n == 0 do return false

    cursor: i32
    if reflect.enum_value_has_name(value^) {
        current := reflect.Type_Info_Enum_Value(value^)
        for v, i in values {
            if v == current {
                cursor = i32(i);
                break;
            }
        }
    }

    im.PushIDStr(label, nil)
    defer im.PopID()

    im.Text("%s:", label)

    im.SameLine()
    if im.ArrowButton("##arrowleft", .Left) {
        cursor = ((cursor - 1) %n + n) % n
        value^ = T(values[cursor])
        changed = true
    }
    
    im.SameLine()
    name := reflect.enum_name_from_value(value^) or_else "?"
    // defer delete(name)
    im.Text("%s", name)

    im.SameLine()
    if im.ArrowButton("##arrowright", .Right) {
        cursor = (cursor + 1) % n
        value^ = T(values[cursor])
        changed = true
    }

    return changed
}
