package fractal

import "core:math"

import "../geom"
import "../palette"

init_fractal_state :: proc(
    kind: Fractal_Kind,
    resolution: geom.Extent_2D,
) -> Fractal {
    base := Fractal_Base {
        camera = {
            view = {
                center = {FRACTAL_DEFAULT_CENTER_X, FRACTAL_DEFAULT_CENTER_Y},
                zoom = FRACTAL_DEFAULT_ZOOM,
            },
            is_dragging = false,
            drag_start = geom.Vec2{0, 0},
        },
        max_iter = FRACTAL_DEFAULT_MAX_ITER,
        resolution = {f32(resolution.w), f32(resolution.h)},
        palette = palette.Palette {
            offset = {0.5, 0.5, 0.5, 0.0},
            amplitude = {0.5, 0.5, 0.5, 0.0},
            frequency = {1.0, 1.0, 1.0, 0.0},
            phase = {0.0, 0.10, 0.20, 0.0},
        },
        interior_color = {0.0, 0.0, 0.0, 1.0},
        zoom_level = math.log2(f32(FRACTAL_DEFAULT_ZOOM)),
    }

    switch kind {
    case .Mandelbrot:
        return Fractal {
            kind = .Mandelbrot,
            base = base,
            data = Mandelbrot_Data{power = 2.0},
        }
    case .Julia:
        return Fractal {
            kind = .Julia,
            base = base,
            data = Julia_Data{constant = complex(-0.8, 0.156)},
        }
    }
    return Fractal{}
}

fractal_uniform_size :: proc(fractal: ^Fractal) -> int {
    if _, ok := &fractal.data.(Mandelbrot_Data); ok {
        return size_of(Mandelbrot_Uniform)
    }
	if _, ok := &fractal.data.(Julia_Data); ok {
		return size_of(Julia_Uniform)
	}
    return 0
}

fractal_make_uniform :: proc(fractal: ^Fractal, dst: rawptr) -> bool {
    if d, ok := &fractal.data.(Mandelbrot_Data); ok {
        _, ok2 := mandelbrot_make_uniform(&fractal.base, d, dst)
        return ok2
    }
	if d, ok := &fractal.data.(Julia_Data); ok {
		_, ok2 := julia_make_uniform(&fractal.base, d, dst)
		return ok2
	}
    return false
}
