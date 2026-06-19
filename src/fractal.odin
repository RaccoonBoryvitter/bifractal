package main

import "core:math"

PalettePreset :: struct {
    name:      string,
    a:         [3]f32,
    b:         [3]f32,
    c:         [3]f32,
    d:         [3]f32,
}

palette_presets := [?]PalettePreset{
    {
        name = "Electric",
        a = { 0.5, 0.5, 0.5 },
        b = { 0.5, 0.5, 0.5 },
        c = { 1.0, 1.0, 1.0 },
        d = { 0.0, 0.10, 0.20 },
    },
    {
        name = "Fire",
        a = { 0.5, 0.2, 0.1 },
        b = { 0.5, 0.4, 0.1 },
        c = { 1.0, 0.7, 0.4 },
        d = { 0.0, 0.15, 0.20 },
    },
    {
        name = "Ocean",
        a = { 0.2, 0.4, 0.6 },
        b = { 0.2, 0.3, 0.4 },
        c = { 1.0, 1.0, 1.0 },
        d = { 0.0, 0.10, 0.25 },
    },
    {
        name = "Grayscale",
        a = { 0.5, 0.5, 0.5 },
        b = { 0.5, 0.5, 0.5 },
        c = { 1.0, 1.0, 1.0 },
        d = { 0.0, 0.0, 0.0 },
    },
    {
        name = "Candy",
        a = { 0.5, 0.5, 0.5 },
        b = { 0.5, 0.5, 0.5 },
        c = { 1.0, 0.7, 0.4 },
        d = { 0.0, 0.15, 0.20 },
    },
    {
        name = "Sunset",
        a = { 0.8, 0.5, 0.4 },
        b = { 0.2, 0.4, 0.2 },
        c = { 2.0, 1.0, 1.0 },
        d = { 0.5, 0.25, 0.25 },
    },
    {
        name = "Neon",
        a = { 0.5, 0.5, 0.5 },
        b = { 0.5, 0.5, 0.5 },
        c = { 0.0, 0.33, 0.67 },
        d = { 0.0, 0.10, 0.20 },
    },
    {
        name = "Gold",
        a = { 0.5, 0.4, 0.1 },
        b = { 0.5, 0.3, 0.1 },
        c = { 1.0, 0.8, 0.3 },
        d = { 0.0, 0.10, 0.10 },
    },
}

apply_palette_preset :: proc(uniform: ^FractalUniform, preset: PalettePreset) {
    uniform.palette_a = preset.a
    uniform.palette_b = preset.b
    uniform.palette_c = preset.c
    uniform.palette_d = preset.d
}

screen_to_complex :: proc(
    screen_x, screen_y: f32,
    window_width, window_height: u32,
    center: [2]f32,
    zoom: f32
) -> complex64 {
    w := f32(window_width)
    h := f32(window_height)
    return complex(
        (screen_x - w * 0.5) / (h * zoom) + center.x,
        (screen_y - h * 0.5) / (h * zoom) + center.y
    )
}

cosine_palette_cpu :: proc(t: f32, a, b, c, d: [3]f32) -> [3]f32 {
    color := [3]f32{
        a.r + b.r * math.cos(2 * math.PI * (c.r * t + d.r)),
        a.g + b.g * math.cos(2 * math.PI * (c.g * t + d.g)),
        a.b + b.b * math.cos(2 * math.PI * (c.b * t + d.b)),
    }
    return {
        math.clamp(color.r, 0, 1),
        math.clamp(color.g, 0, 1),
        math.clamp(color.b, 0, 1),
    }
}

reset_fractal_view :: proc(uniform: ^FractalUniform, zoom_level: ^f32) {
    uniform.zoom = FRACTAL_DEFAULT_ZOOM
    zoom_level^ = math.log2(uniform.zoom)
    uniform.center = { FRACTAL_DEFAULT_CENTER_X, FRACTAL_DEFAULT_CENTER_Y }
    uniform.max_iter = FRACTAL_DEFAULT_MAX_ITER
}
