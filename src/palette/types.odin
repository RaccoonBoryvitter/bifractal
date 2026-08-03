package palette

import "core:math/rand"

Palette :: struct {
	offset, amplitude, frequency, phase: [4]f32,
}

Palette_Preset :: struct {
	name:          string,
	using palette: Palette,
}

Palette_State :: struct {
	banded:     bool,
	snapshot:   Maybe(Palette_Preset),
	rand_state: rand.Default_Random_State,
}

Palette_Color_Kind :: enum {
	Offset,
	Amplitude,
	Frequency,
	Phase,
}
