package main

import "core:math"
import "core:math/rand"

// Functions

apply_palette_preset :: proc(
    palette: ^Palette,
    preset: Palette_Preset,
) {
    palette^ = preset.palette
}

mirror_palette :: proc(palette: ^Palette) {
    palette.phase.xyz = 1.0 - palette.phase.xyz
}

rotate_palette :: proc(palette: ^Palette, k: f32) {
    for i in 0 ..< 3 {
        rotated := palette.phase[i] + k
        palette.phase[i] = rotated - math.floor(rotated)
    }
}

randomize_palette :: proc(palette: ^Palette, gen: rand.Generator) {
    for i in 0 ..< 3 {
        palette.offset[i] = rand.float32_range(0.0, 1.0, gen)
        palette.amplitude[i] = rand.float32_range(0.0, 1.0, gen)
        palette.frequency[i] = rand.float32_range(0.0, 2.0, gen)
        palette.phase[i] = rand.float32_range(0.0, 1.0, gen)
    }
    palette.offset.a = 0.0
    palette.amplitude.a = 0.0
    palette.frequency.a = 0.0
    palette.phase.a = 0.0
}

cosine_palette_cpu :: proc(t: f32, palette: Palette) -> [3]f32 {
    color := [3]f32 {
        palette.offset.r +
        palette.amplitude.r *
        math.cos(2 * math.PI * (palette.frequency.r * t + palette.phase.r)),
        palette.offset.g +
        palette.amplitude.g *
        math.cos(2 * math.PI * (palette.frequency.g * t + palette.phase.g)),
        palette.offset.b +
        palette.amplitude.b *
        math.cos(2 * math.PI * (palette.frequency.b * t + palette.phase.b)),
    }
    return {
        math.clamp(color.r, 0, 1),
        math.clamp(color.g, 0, 1),
        math.clamp(color.b, 0, 1),
    }
}
