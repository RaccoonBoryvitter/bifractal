package fractal

import "core:mem"

import "../palette"

Buffalo_Params :: struct {
    max_iter:       i32,
    using palette:  palette.Palette,
    interior_color: [4]f32,
    resolution:     [2]f32,
    power:          f32,
    _pad:           f32,
}

Buffalo_Uniform :: struct {
    center:       [2]f32,
    zoom:         f32,
    using params: Buffalo_Params,
}

#assert(size_of(Buffalo_Uniform) % 16 == 0)

buffalo_make_uniform :: proc(
    base: ^Fractal_Base,
    data: ^Buffalo_Data,
    dst: rawptr,
) -> (
    size: int,
    ok: bool,
) {
    uniform := Buffalo_Uniform {
        center = base.camera.view.center,
        zoom = base.camera.view.zoom,
        params = Buffalo_Params {
            max_iter = base.max_iter,
            palette = base.palette,
            interior_color = base.interior_color,
            resolution = base.resolution,
            power = data.power,
        },
    }
    size = size_of(Buffalo_Uniform)
    mem.copy(dst, &uniform, size)
    return size, true
}
