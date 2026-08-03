package fractal

import "core:mem"

import "../palette"

Mandelbrot_Params :: struct {
	max_iter:       i32,
	using palette:  palette.Palette,
	interior_color: [4]f32,
	resolution:     [2]f32,
	power:          f32,
}

Mandelbrot_Uniform :: struct {
	center:       [2]f32,
	zoom:         f32,
	using params: Mandelbrot_Params,
}

mandelbrot_make_uniform :: proc(
	base: ^Fractal_Base,
	data: ^Mandelbrot_Data,
	dst: rawptr,
) -> (size: int, ok: bool) {
	uniform := Mandelbrot_Uniform {
		center = base.camera.view.center,
		zoom   = base.camera.view.zoom,
		params = Mandelbrot_Params {
			max_iter       = base.max_iter,
			palette        = base.palette,
			interior_color = base.interior_color,
			resolution     = base.resolution,
			power          = data.power,
		},
	}
	size = size_of(Mandelbrot_Uniform)
	mem.copy(dst, &uniform, size)
	return size, true
}
