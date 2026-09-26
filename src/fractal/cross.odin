package fractal

import "core:mem"

import "../palette"

Cross_Params :: struct {
    max_iter:       i32,
    using palette:  palette.Palette,
    interior_color: [4]f32,
    resolution:     [2]f32,
    power:          f32,
    _pad:           f32,
}

Cross_Uniform :: struct {
    center:       [2]f32,
    zoom:         f32,
    using params: Cross_Params,
}

#assert(size_of(Cross_Uniform) % 16 == 0)

cross_make_uniform :: proc(
    base: ^Fractal_Base,
    data: ^Cross_Data,
    dst: rawptr,
) -> (
    size: int,
    ok: bool,
) {
    cx := base.camera.view.center
    uniform := Cross_Uniform {
        center = {f32(cx.x), f32(cx.y)},
        zoom = f32(base.camera.view.zoom),
        params = Cross_Params {
            max_iter = base.max_iter,
            palette = base.palette,
            interior_color = base.interior_color,
            resolution = base.resolution,
            power = data.power,
        },
    }
    size = size_of(Cross_Uniform)
    mem.copy(dst, &uniform, size)
    return size, true
}
