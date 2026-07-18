package main

import sdl "vendor:sdl3"

resize_gpu_output :: proc(
    ctx: ^Gpu_Context,
    new_size: Extent_2D,
) -> ^sdl.GPUTexture {
    if ctx.output != nil && ctx.device != nil {
        sdl.ReleaseGPUTexture(ctx.device, ctx.output)
    }

    new_output := create_output_texture(ctx.device, new_size)
    if new_output == nil {
        ctx.output = nil
        ctx.output_size = {}
        ctx.valid = false
        return nil
    }

    ctx.output = new_output
    ctx.output_size = new_size
    ctx.valid = true
    return new_output
}

create_compute_pipeline :: proc(
    device: ^sdl.GPUDevice,
) -> ^sdl.GPUComputePipeline {
    compute_pipeline := sdl.CreateGPUComputePipeline(
        device,
        sdl.GPUComputePipelineCreateInfo {
            code = raw_data(MANDELBROT_SHADER),
            code_size = len(MANDELBROT_SHADER),
            entrypoint = SHADER_ENTRY,
            format = {SHADER_FORMAT},
            num_uniform_buffers = 1,
            num_readwrite_storage_textures = 1,
            threadcount_x = 8,
            threadcount_y = 8,
            threadcount_z = 1,
        },
    )

    if compute_pipeline == nil {
        sdl.LogError(
            i32(sdl.LogCategory.RENDER),
            "failed to create compute pipeline: %s",
            sdl.GetError(),
        )
    }

    return compute_pipeline
}

create_output_texture :: proc(
    device: ^sdl.GPUDevice,
    resolution: Extent_2D,
) -> ^sdl.GPUTexture {
    return sdl.CreateGPUTexture(
        device,
        sdl.GPUTextureCreateInfo {
            type = .D2,
            format = .R32G32B32A32_FLOAT,
            width = resolution.w,
            height = resolution.h,
            layer_count_or_depth = 1,
            num_levels = 1,
            usage = {.COMPUTE_STORAGE_WRITE, .SAMPLER, .COMPUTE_STORAGE_READ},
        },
    )
}
