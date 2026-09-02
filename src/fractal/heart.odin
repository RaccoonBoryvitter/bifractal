package fractal

import "core:mem"

import "../palette"

Heart_Params :: struct {
    max_iter:       i32,
    using palette:  palette.Palette,
    interior_color: [4]f32,
    resolution:     [2]f32,
    power:          f32,
    _pad:           f32,
}

Heart_Uniform :: struct {
    center_hi:    [2]f32,
    center_lo:    [2]f32,
    zoom:         f32,
    _header_pad:  [2]f32,
    using params: Heart_Params,
}

#assert(size_of(Heart_Uniform) % 16 == 0)

heart_make_uniform :: proc(
    base: ^Fractal_Base,
    data: ^Heart_Data,
    dst: rawptr,
) -> (
    size: int,
    ok: bool,
) {
    cx := base.camera.view.center
    hi := [2]f32{f32(cx.x), f32(cx.y)}
    lo := [2]f32{f32(cx.x - f64(hi.x)), f32(cx.y - f64(hi.y))}
    uniform := Heart_Uniform {
        center_hi = hi,
        center_lo = lo,
        zoom = f32(base.camera.view.zoom),
        params = Heart_Params {
            max_iter = base.max_iter,
            palette = base.palette,
            interior_color = base.interior_color,
            resolution = base.resolution,
            power = data.power,
        },
    }
    size = size_of(Heart_Uniform)
    mem.copy(dst, &uniform, size)
    return size, true
}
