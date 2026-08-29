package events

import "../fractal"
import "../geom"
import "../palette"

View_Reset :: struct {}

Max_Iter_Changed :: struct {
    value: i32,
}

Window_Resized :: struct {
    size: geom.Extent_2D,
}

Palette_Banded_Changed :: struct {
    banded: bool,
}

Palette_Mirrored :: struct {}

Palette_Rotated :: struct {
    delta: f32,
}

Palette_Randomized :: struct {}

Palette_Preset_Applied :: struct {
    preset: palette.Palette_Preset,
}

Palette_Color_Changed :: struct {
    kind:  palette.Palette_Color_Kind,
    value: [4]f32,
}

Interior_Color_Changed :: struct {
    value: [3]f32,
}

Fractal_Kind_Changed :: struct {
    value: fractal.Fractal_Kind,
}

Mandelbrot_Power_Changed :: struct {
    value: f32,
}

Julia_Constant_Changed :: struct {
    value: complex64,
}

Burning_Ship_Power_Changed :: struct {
    value: f32,
}

Settings_Reset :: struct {}

Image_Save_Requested :: struct {}

App_Event :: union {
    View_Reset,
    Max_Iter_Changed,
    Window_Resized,
    Palette_Banded_Changed,
    Palette_Mirrored,
    Palette_Rotated,
    Palette_Randomized,
    Palette_Preset_Applied,
    Palette_Color_Changed,
    Interior_Color_Changed,
    Fractal_Kind_Changed,
    Mandelbrot_Power_Changed,
    Julia_Constant_Changed,
    Burning_Ship_Power_Changed,
    Settings_Reset,
    Image_Save_Requested,
}

App_Events :: struct {
    queue: [dynamic]App_Event,
}
