package fractal

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
    case .Burning_Ship:
        return Fractal {
            kind = .Burning_Ship,
            base = base,
            data = Burning_Ship_Data{power = 2.0},
        }
    case .Tricorn:
        return Fractal {
            kind = .Tricorn,
            base = base,
            data = Tricorn_Data{power = 2.0},
        }
    case .Celtic:
        return Fractal {
            kind = .Celtic,
            base = base,
            data = Celtic_Data{power = 2.0},
        }
    case .Buffalo:
        return Fractal {
            kind = .Buffalo,
            base = base,
            data = Buffalo_Data{power = 2.0},
        }
    case .Cross:
        return Fractal {
            kind = .Cross,
            base = base,
            data = Cross_Data{power = 2.0},
        }
    case .Heart:
        return Fractal {
            kind = .Heart,
            base = base,
            data = Heart_Data{power = 2.0},
        }
    case .Perpendicular:
        return Fractal {
            kind = .Perpendicular,
            base = base,
            data = Perpendicular_Data{power = 2.0},
        }
    }
    return Fractal{}
}

fractal_uniform_size :: proc(fractal: ^Fractal) -> int {
    impl := FRACTAL_REGISTRY[fractal.kind]
    if impl.uniform_size != nil {
        return impl.uniform_size(fractal)
    }
    return 0
}

fractal_make_uniform :: proc(fractal: ^Fractal, dst: rawptr) -> bool {
    impl := FRACTAL_REGISTRY[fractal.kind]
    if impl.make_uniform != nil {
        return impl.make_uniform(fractal, dst)
    }
    return false
}
