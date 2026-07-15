package main

import "core:math"
import "core:math/rand"

// Functions

apply_palette_preset :: proc(
    uniform: ^Fractal_Params,
    preset: Palette_Preset,
) {
    uniform.palette_a = preset.a
    uniform.palette_b = preset.b
    uniform.palette_c = preset.c
    uniform.palette_d = preset.d
}

mirror_palette :: proc(uniform: ^Fractal_Params) {
    uniform.palette_d.xyz = 1.0 - uniform.palette_d.xyz
}

rotate_palette :: proc(uniform: ^Fractal_Params, k: f32) {
    for i in 0 ..< 3 {
        rotated := uniform.palette_d[i] + k
        uniform.palette_d[i] = rotated - math.floor(rotated)
    }
}

randomize_palette :: proc(uniform: ^Fractal_Params, gen: rand.Generator) {
    for i in 0 ..< 3 {
        uniform.palette_a[i] = rand.float32_range(0.0, 1.0, gen)
        uniform.palette_b[i] = rand.float32_range(0.0, 1.0, gen)
        uniform.palette_c[i] = rand.float32_range(0.0, 2.0, gen)
        uniform.palette_d[i] = rand.float32_range(0.0, 1.0, gen)
    }
    uniform.palette_a.a = 0.0
    uniform.palette_b.a = 0.0
    uniform.palette_c.a = 0.0
    uniform.palette_d.a = 0.0
}

cosine_palette_cpu :: proc(t: f32, a, b, c, d: [4]f32) -> [3]f32 {
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
