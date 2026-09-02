package fractal

import "core:mem"

import "../palette"

Burning_Ship_Params :: struct {
    max_iter:       i32,
    using palette:  palette.Palette,
    interior_color: [4]f32,
    resolution:     [2]f32,
    power:          f32,
    _pad:           f32,
}

Burning_Ship_Uniform :: struct {
    center_hi:    [2]f32,
    center_lo:    [2]f32,
    zoom:         f32,
    _header_pad:  [2]f32,
    using params: Burning_Ship_Params,
}

#assert(size_of(Burning_Ship_Uniform) % 16 == 0)

burning_ship_make_uniform :: proc(
    base: ^Fractal_Base,
    data: ^Burning_Ship_Data,
    dst: rawptr,
) -> (
    size: int,
    ok: bool,
) {
    cx := base.camera.view.center
    hi := [2]f32{f32(cx.x), f32(cx.y)}
    lo := [2]f32{f32(cx.x - f64(hi.x)), f32(cx.y - f64(hi.y))}
    uniform := Burning_Ship_Uniform {
        center_hi = hi,
        center_lo = lo,
        zoom = f32(base.camera.view.zoom),
        params = Burning_Ship_Params {
            max_iter = base.max_iter,
            palette = base.palette,
            interior_color = base.interior_color,
            resolution = base.resolution,
            power = data.power,
        },
    }
    size = size_of(Burning_Ship_Uniform)
    mem.copy(dst, &uniform, size)
    return size, true
}
