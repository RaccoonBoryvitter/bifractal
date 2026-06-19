package main

import "core:log"

import sdl "vendor:sdl3"

// Types

GPUResources :: struct {
    device :             ^sdl.GPUDevice,
    compute_pipeline :   ^sdl.GPUComputePipeline,
    texture :            ^sdl.GPUTexture,
    ui_pipeline :        ^sdl.GPUGraphicsPipeline,
    ui_vertex_buffer :   ^sdl.GPUBuffer,
    ui_transfer_buffer : ^sdl.GPUTransferBuffer,
    ui_font_texture :    ^sdl.GPUTexture,
    ui_font_sampler :    ^sdl.GPUSampler,
}

// Functions

create_compute_pipeline :: proc(
    filepath : cstring,
    device : ^sdl.GPUDevice,
) -> ^sdl.GPUComputePipeline {
    size : uint
    code := sdl.LoadFile(filepath, &size)
    defer sdl.free(code)

    compute_pipeline := sdl.CreateGPUComputePipeline(
        device,
        sdl.GPUComputePipelineCreateInfo {
            code = (^u8)(code),
            code_size = size,
            entrypoint = "main",
            format = {.SPIRV},
            num_uniform_buffers = 1,
            num_readwrite_storage_textures = 1,
            threadcount_x = 8,
            threadcount_y = 8,
            threadcount_z = 1,
        },
    )

    return compute_pipeline
}

create_gpu_shader :: proc(
    device : ^sdl.GPUDevice,
    filepath : cstring,
    shader_type : sdl.GPUShaderStage,
    num_uniform_buffers : u32 = 0,
    num_samplers : u32 = 0,
    num_storage_textures : u32 = 0,
    num_storage_buffers : u32 = 0,
) -> ^sdl.GPUShader {
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
            entrypoint = "main",
            format = {.SPIRV},
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

create_output_texture :: proc(
    device : ^sdl.GPUDevice,
    width, height : u32,
) -> ^sdl.GPUTexture {
    return sdl.CreateGPUTexture(
        device,
        sdl.GPUTextureCreateInfo {
            type = .D2,
            format = .R8G8B8A8_UNORM,
            width = width,
            height = height,
            layer_count_or_depth = 1,
            num_levels = 1,
            usage = {.COMPUTE_STORAGE_WRITE, .SAMPLER, .COMPUTE_STORAGE_READ},
        },
    )
}
