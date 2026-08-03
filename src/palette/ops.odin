package palette

import "core:math"
import "core:math/rand"

apply_palette_preset :: proc(p: ^Palette, preset: Palette_Preset) {
	p^ = preset.palette
}

mirror_palette :: proc(p: ^Palette) {
	p.phase.xyz = 1.0 - p.phase.xyz
}

rotate_palette :: proc(p: ^Palette, k: f32) {
	for i in 0 ..< 3 {
		rotated := p.phase[i] + k
		p.phase[i] = rotated - math.floor(rotated)
	}
}

randomize_palette :: proc(p: ^Palette, gen: rand.Generator) {
	for i in 0 ..< 3 {
		p.offset[i] = rand.float32_range(0.0, 1.0, gen)
		p.amplitude[i] = rand.float32_range(0.0, 1.0, gen)
		p.frequency[i] = rand.float32_range(0.0, 2.0, gen)
		p.phase[i] = rand.float32_range(0.0, 1.0, gen)
	}
	p.offset.a = 0.0
	p.amplitude.a = 0.0
	p.frequency.a = 0.0
	p.phase.a = 0.0
}
