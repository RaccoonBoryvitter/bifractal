package fractal

// Single shader format/ext/entry for all fractals — replaces 9 duplicated *_shader.odin files.

when ODIN_OS == .Windows {
    when #config(SHADER_BACKEND, "dx12") == "vulkan" {
        SHADER_EXT :: "spv"
        SHADER_ENTRY :: "main"
    }
    else {
        SHADER_EXT :: "dxil"
        SHADER_ENTRY :: "main"
    }
}
else when ODIN_OS == .Darwin {
    SHADER_EXT :: "metal"
    SHADER_ENTRY :: "main0"
}
else {
    SHADER_EXT :: "spv"
    SHADER_ENTRY :: "main"
}

MANDELBROT_SHADER :: #load(
    "../../assets/shaders/compiled/mandelbrot." + SHADER_EXT,
)

JULIA_SHADER :: #load("../../assets/shaders/compiled/julia." + SHADER_EXT)

BURNING_SHIP_SHADER :: #load(
    "../../assets/shaders/compiled/burning_ship." + SHADER_EXT,
)

TRICORN_SHADER :: #load("../../assets/shaders/compiled/tricorn." + SHADER_EXT)

CELTIC_SHADER :: #load("../../assets/shaders/compiled/celtic." + SHADER_EXT)

BUFFALO_SHADER :: #load("../../assets/shaders/compiled/buffalo." + SHADER_EXT)

CROSS_SHADER :: #load("../../assets/shaders/compiled/cross." + SHADER_EXT)

HEART_SHADER :: #load("../../assets/shaders/compiled/heart." + SHADER_EXT)

PERPENDICULAR_SHADER :: #load(
    "../../assets/shaders/compiled/perpendicular." + SHADER_EXT,
)
