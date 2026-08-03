package main

when ODIN_OS == .Windows {
    when #config(SHADER_BACKEND, "dx12") == "vulkan" {
        SHADER_EXT    :: "spv"
        SHADER_ENTRY  :: "main"
    } else {
        SHADER_EXT    :: "dxil"
        SHADER_ENTRY  :: "main"
    }
} else when ODIN_OS == .Darwin {
    SHADER_EXT    :: "metal"
    SHADER_ENTRY  :: "main0"
} else {
    SHADER_EXT    :: "spv"
    SHADER_ENTRY  :: "main"
}

MANDELBROT_SHADER :: #load("../assets/shaders/compiled/mandelbrot." + SHADER_EXT)
