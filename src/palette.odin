package main

import "core:math"

// Types

PalettePreset :: struct {
    name : string,
    a :    [3]f32,
    b :    [3]f32,
    c :    [3]f32,
    d :    [3]f32,
}

// Functions

apply_palette_preset :: proc(
    uniform : ^FractalUniform,
    preset : PalettePreset,
) {
    uniform.palette_a = preset.a
    uniform.palette_b = preset.b
    uniform.palette_c = preset.c
    uniform.palette_d = preset.d
}

cosine_palette_cpu :: proc(t : f32, a, b, c, d : [3]f32) -> [3]f32 {
    color := [3]f32 {
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
