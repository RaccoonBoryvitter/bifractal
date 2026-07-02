package main

import "core:fmt"
import "core:log"

import sdl "vendor:sdl3"

create_shader :: proc(
    device : ^sdl.GPUDevice,
    name : string,
    shader_type : sdl.GPUShaderStage,
    num_uniform_buffers : u32 = 0,
    num_samplers : u32 = 0,
    num_storage_textures : u32 = 0,
    num_storage_buffers : u32 = 0,
) -> ^sdl.GPUShader {
    format, ext := get_shader_format(device)

    filepath := fmt.ctprintf("../assets/shaders/compiled/%s.%s", name, ext)

    size : uint
    code := sdl.LoadFile(filepath, &size)
    if code == nil {
        log.errorf("failed to load shader %s: %s", filepath, sdl.GetError())
        return nil
    }
    defer sdl.free(code)

    shader := sdl.CreateGPUShader(
        device,
        sdl.GPUShaderCreateInfo {
            code = (^u8)(code),
            code_size = size,
            entrypoint = format == .MSL ? "main0" : "main",
            format = {format},
            stage = shader_type,
            num_uniform_buffers = num_uniform_buffers,
            num_samplers = num_samplers,
            num_storage_textures = num_storage_textures,
            num_storage_buffers = num_storage_buffers,
        },
    )

    if shader == nil {
        log.errorf("failed to create shader %s: %s", filepath, sdl.GetError())
    }

    return shader
}

get_shader_format :: proc(
    device : ^sdl.GPUDevice,
) -> (
    sdl.GPUShaderFormatFlag,
    string,
) {
    formats := sdl.GetGPUShaderFormats(device)
    if .SPIRV in formats do return .SPIRV, "spv"
    if .DXIL in formats do return .DXIL, "dxil"
    if .DXBC in formats do return .DXBC, "dxbc"
    if .MSL in formats do return .MSL, "msl"
    panic("no supported shader format")
}
