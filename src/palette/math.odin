package palette

import "base:runtime"
import "core:math"

cosine_palette_cpu :: proc(t: f32, p: Palette) -> [3]f32 {
	color := [3]f32 {
		p.offset.r +
		p.amplitude.r *
			math.cos(
				2 * math.PI * (p.frequency.r * t + p.phase.r),
			),
		p.offset.g +
		p.amplitude.g *
			math.cos(
				2 * math.PI * (p.frequency.g * t + p.phase.g),
			),
		p.offset.b +
		p.amplitude.b *
			math.cos(
				2 * math.PI * (p.frequency.b * t + p.phase.b),
			),
	}
	return {
		math.clamp(color.r, 0, 1),
		math.clamp(color.g, 0, 1),
		math.clamp(color.b, 0, 1),
	}
}

palette_create_samples :: proc(
	p: Palette,
	num_samples: u32,
	allocator: runtime.Allocator,
) -> [][3]f32 {
	samples := make([][3]f32, num_samples, allocator)

	for i in 0 ..< num_samples {
		t := f32(i) / f32(num_samples)
		samples[i] = cosine_palette_cpu(t, p)
	}

	return samples
}
