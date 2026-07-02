package main

import "core:fmt"
import "core:log"

import sdl "vendor:sdl3"

create_compute_pipeline :: proc(
    device : ^sdl.GPUDevice,
    name : string,
) -> ^sdl.GPUComputePipeline {
    format, ext := get_shader_format(device)

    filepath := fmt.ctprintf("../assets/shaders/compiled/%s.%s", name, ext)

    size : uint
    code := sdl.LoadFile(filepath, &size)
    defer sdl.free(code)

    compute_pipeline := sdl.CreateGPUComputePipeline(
        device,
        sdl.GPUComputePipelineCreateInfo {
            code = (^u8)(code),
            code_size = size,
            entrypoint = format == .MSL ? "main0" : "main",
            format = {format},
            num_uniform_buffers = 1,
            num_readwrite_storage_textures = 1,
            threadcount_x = 8,
            threadcount_y = 8,
            threadcount_z = 1,
        },
    )

    if compute_pipeline == nil {
        log.errorf(
            "failed to create compute pipeline \"%s\": %s",
            filepath,
            sdl.GetError(),
        )
    }

    return compute_pipeline
}

create_output_texture :: proc(
    device : ^sdl.GPUDevice,
    width, height : u32,
) -> ^sdl.GPUTexture {
    return sdl.CreateGPUTexture(
        device,
        sdl.GPUTextureCreateInfo {
            type = .D2,
            format = .R32G32B32A32_FLOAT,
            width = width,
            height = height,
            layer_count_or_depth = 1,
            num_levels = 1,
            usage = {.COMPUTE_STORAGE_WRITE, .SAMPLER, .COMPUTE_STORAGE_READ},
        },
    )
}
