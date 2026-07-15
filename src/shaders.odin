package main

import sdl "vendor:sdl3"

when ODIN_OS == .Windows {
    when #config(SHADER_BACKEND, "dx12") == "vulkan" {
        SHADER_FORMAT :: sdl.GPUShaderFormatFlag.SPIRV
        SHADER_EXT    :: "spv"
        SHADER_ENTRY  :: "main"
    } else {
        SHADER_FORMAT :: sdl.GPUShaderFormatFlag.DXIL
        SHADER_EXT    :: "dxil"
        SHADER_ENTRY  :: "main"
    }
} else when ODIN_OS == .Darwin {
    SHADER_FORMAT :: sdl.GPUShaderFormatFlag.MSL
    SHADER_EXT    :: "metal"
    SHADER_ENTRY  :: "main0"
} else {
    SHADER_FORMAT :: sdl.GPUShaderFormatFlag.SPIRV
    SHADER_EXT    :: "spv"
    SHADER_ENTRY  :: "main"
}

MANDELBROT_SHADER :: #load("../assets/shaders/compiled/mandelbrot." + SHADER_EXT)
