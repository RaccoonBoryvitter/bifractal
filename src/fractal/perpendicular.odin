package fractal

import "core:mem"

import "../palette"

Perpendicular_Params :: struct {
    max_iter:       i32,
    using palette:  palette.Palette,
    interior_color: [4]f32,
    resolution:     [2]f32,
    power:          f32,
}

Perpendicular_Uniform :: struct {
    center:       [2]f32,
    zoom:         f32,
    using params: Perpendicular_Params,
}

perpendicular_make_uniform :: proc(
    base: ^Fractal_Base,
    data: ^Perpendicular_Data,
    dst: rawptr,
) -> (
    size: int,
    ok: bool,
) {
    uniform := Perpendicular_Uniform {
        center = base.camera.view.center,
        zoom = base.camera.view.zoom,
        params = Perpendicular_Params {
            max_iter = base.max_iter,
            palette = base.palette,
            interior_color = base.interior_color,
            resolution = base.resolution,
            power = data.power,
        },
    }
    size = size_of(Perpendicular_Uniform)
    mem.copy(dst, &uniform, size)
    return size, true
}
