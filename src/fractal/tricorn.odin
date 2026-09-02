package fractal

import "core:mem"

import "../palette"

Tricorn_Params :: struct {
    max_iter:       i32,
    using palette:  palette.Palette,
    interior_color: [4]f32,
    resolution:     [2]f32,
    power:          f32,
    _pad:           f32,
}

Tricorn_Uniform :: struct {
    center:       [2]f32,
    zoom:         f32,
    using params: Tricorn_Params,
}

#assert(size_of(Tricorn_Uniform) % 16 == 0)

tricorn_make_uniform :: proc(
    base: ^Fractal_Base,
    data: ^Tricorn_Data,
    dst: rawptr,
) -> (
    size: int,
    ok: bool,
) {
    uniform := Tricorn_Uniform {
        center = base.camera.view.center,
        zoom = base.camera.view.zoom,
        params = Tricorn_Params {
            max_iter = base.max_iter,
            palette = base.palette,
            interior_color = base.interior_color,
            resolution = base.resolution,
            power = data.power,
        },
    }
    size = size_of(Tricorn_Uniform)
    mem.copy(dst, &uniform, size)
    return size, true
}
