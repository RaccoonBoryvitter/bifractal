package fractal

import "core:mem"

import "../palette"

Perpendicular_Params :: struct {
    max_iter:       i32,
    using palette:  palette.Palette,
    interior_color: [4]f32,
    resolution:     [2]f32,
    power:          f32,
    _pad:           f32,
}

Perpendicular_Uniform :: struct {
    center:       [2]f32,
    zoom:         f32,
    using params: Perpendicular_Params,
}

#assert(size_of(Perpendicular_Uniform) % 16 == 0)

perpendicular_make_uniform :: proc(
    base: ^Fractal_Base,
    data: ^Perpendicular_Data,
    dst: rawptr,
) -> (
    size: int,
    ok: bool,
) {
    cx := base.camera.view.center
    uniform := Perpendicular_Uniform {
        center = {f32(cx.x), f32(cx.y)},
        zoom = f32(base.camera.view.zoom),
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
