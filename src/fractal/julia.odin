package fractal

import "core:mem"

import "../palette"

Julia_Params :: struct {
    max_iter:       i32,
    using palette:  palette.Palette,
    interior_color: [4]f32,
    resolution:     [2]f32,
    constant:       complex64,
}

Julia_Uniform :: struct {
    center_hi:    [2]f32,
    center_lo:    [2]f32,
    zoom:         f32,
    _header_pad:  [2]f32,
    using params: Julia_Params,
}

#assert(size_of(Julia_Uniform) % 16 == 0)

julia_make_uniform :: proc(
    base: ^Fractal_Base,
    data: ^Julia_Data,
    dst: rawptr,
) -> (
    size: int,
    ok: bool,
) {
    cx := base.camera.view.center
    hi := [2]f32{f32(cx.x), f32(cx.y)}
    lo := [2]f32{f32(cx.x - f64(hi.x)), f32(cx.y - f64(hi.y))}
    uniform := Julia_Uniform {
        center_hi = hi,
        center_lo = lo,
        zoom = f32(base.camera.view.zoom),
        params = Julia_Params {
            max_iter = base.max_iter,
            palette = base.palette,
            interior_color = base.interior_color,
            resolution = base.resolution,
            constant = data.constant,
        },
    }
    size = size_of(Julia_Uniform)
    mem.copy(dst, &uniform, size)
    return size, true
}
