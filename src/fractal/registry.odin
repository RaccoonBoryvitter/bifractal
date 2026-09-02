package fractal

Fractal_Impl :: struct {
    shader_bytes: []byte,
    shader_entry: cstring,
    uniform_size: proc(_: ^Fractal) -> int,
    make_uniform: proc(_: ^Fractal, _: rawptr) -> bool,
}

mandelbrot_uniform_size :: proc(f: ^Fractal) -> int { return size_of(
        Mandelbrot_Uniform,
    ) }
mandelbrot_make_uniform_wrap :: proc(f: ^Fractal, dst: rawptr) -> bool {
    d, ok := &f.data.(Mandelbrot_Data)
    if !ok { return false }
    _, ok2 := mandelbrot_make_uniform(&f.base, d, dst)
    return ok2
}

julia_uniform_size :: proc(f: ^Fractal) -> int { return size_of(
        Julia_Uniform,
    ) }
julia_make_uniform_wrap :: proc(f: ^Fractal, dst: rawptr) -> bool {
    d, ok := &f.data.(Julia_Data)
    if !ok { return false }
    _, ok2 := julia_make_uniform(&f.base, d, dst)
    return ok2
}

burning_ship_uniform_size :: proc(f: ^Fractal) -> int { return size_of(
        Burning_Ship_Uniform,
    ) }
burning_ship_make_uniform_wrap :: proc(f: ^Fractal, dst: rawptr) -> bool {
    d, ok := &f.data.(Burning_Ship_Data)
    if !ok { return false }
    _, ok2 := burning_ship_make_uniform(&f.base, d, dst)
    return ok2
}

tricorn_uniform_size :: proc(f: ^Fractal) -> int { return size_of(
        Tricorn_Uniform,
    ) }
tricorn_make_uniform_wrap :: proc(f: ^Fractal, dst: rawptr) -> bool {
    d, ok := &f.data.(Tricorn_Data)
    if !ok { return false }
    _, ok2 := tricorn_make_uniform(&f.base, d, dst)
    return ok2
}

celtic_uniform_size :: proc(f: ^Fractal) -> int { return size_of(
        Celtic_Uniform,
    ) }
celtic_make_uniform_wrap :: proc(f: ^Fractal, dst: rawptr) -> bool {
    d, ok := &f.data.(Celtic_Data)
    if !ok { return false }
    _, ok2 := celtic_make_uniform(&f.base, d, dst)
    return ok2
}

buffalo_uniform_size :: proc(f: ^Fractal) -> int { return size_of(
        Buffalo_Uniform,
    ) }
buffalo_make_uniform_wrap :: proc(f: ^Fractal, dst: rawptr) -> bool {
    d, ok := &f.data.(Buffalo_Data)
    if !ok { return false }
    _, ok2 := buffalo_make_uniform(&f.base, d, dst)
    return ok2
}

cross_uniform_size :: proc(f: ^Fractal) -> int { return size_of(
        Cross_Uniform,
    ) }
cross_make_uniform_wrap :: proc(f: ^Fractal, dst: rawptr) -> bool {
    d, ok := &f.data.(Cross_Data)
    if !ok { return false }
    _, ok2 := cross_make_uniform(&f.base, d, dst)
    return ok2
}

heart_uniform_size :: proc(f: ^Fractal) -> int { return size_of(
        Heart_Uniform,
    ) }
heart_make_uniform_wrap :: proc(f: ^Fractal, dst: rawptr) -> bool {
    d, ok := &f.data.(Heart_Data)
    if !ok { return false }
    _, ok2 := heart_make_uniform(&f.base, d, dst)
    return ok2
}

perpendicular_uniform_size :: proc(f: ^Fractal) -> int { return size_of(
        Perpendicular_Uniform,
    ) }
perpendicular_make_uniform_wrap :: proc(f: ^Fractal, dst: rawptr) -> bool {
    d, ok := &f.data.(Perpendicular_Data)
    if !ok { return false }
    _, ok2 := perpendicular_make_uniform(&f.base, d, dst)
    return ok2
}

FRACTAL_REGISTRY: [Fractal_Kind]Fractal_Impl = [Fractal_Kind]Fractal_Impl {
    .Mandelbrot    = {
        MANDELBROT_SHADER,
        SHADER_ENTRY,
        mandelbrot_uniform_size,
        mandelbrot_make_uniform_wrap,
    },
    .Julia         = {
        JULIA_SHADER,
        SHADER_ENTRY,
        julia_uniform_size,
        julia_make_uniform_wrap,
    },
    .Burning_Ship  = {
        BURNING_SHIP_SHADER,
        SHADER_ENTRY,
        burning_ship_uniform_size,
        burning_ship_make_uniform_wrap,
    },
    .Tricorn       = {
        TRICORN_SHADER,
        SHADER_ENTRY,
        tricorn_uniform_size,
        tricorn_make_uniform_wrap,
    },
    .Celtic        = {
        CELTIC_SHADER,
        SHADER_ENTRY,
        celtic_uniform_size,
        celtic_make_uniform_wrap,
    },
    .Buffalo       = {
        BUFFALO_SHADER,
        SHADER_ENTRY,
        buffalo_uniform_size,
        buffalo_make_uniform_wrap,
    },
    .Cross         = {
        CROSS_SHADER,
        SHADER_ENTRY,
        cross_uniform_size,
        cross_make_uniform_wrap,
    },
    .Heart         = {
        HEART_SHADER,
        SHADER_ENTRY,
        heart_uniform_size,
        heart_make_uniform_wrap,
    },
    .Perpendicular = {
        PERPENDICULAR_SHADER,
        SHADER_ENTRY,
        perpendicular_uniform_size,
        perpendicular_make_uniform_wrap,
    },
}
