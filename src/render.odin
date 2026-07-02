package main

import "core:log"

import sdl "vendor:sdl3"

render_frame :: proc(state : ^AppState, vertex_count : int) -> sdl.AppResult {
    command_buffer := sdl.AcquireGPUCommandBuffer(state.gpu.device)

    storageTextureBindings := [1]sdl.GPUStorageTextureReadWriteBinding {
        {texture = state.gpu.texture},
    }
    computePass := sdl.BeginGPUComputePass(
        command_buffer,
        raw_data(storageTextureBindings[:]),
        1,
        nil,
        0,
    )
    sdl.BindGPUComputePipeline(computePass, state.gpu.compute_pipeline)
    sdl.PushGPUComputeUniformData(
        command_buffer,
        0,
        &state.fractal.uniform,
        size_of(FractalUniform),
    )
    sdl.DispatchGPUCompute(
        computePass,
        (state.window_width + 7) / 8,
        (state.window_height + 7) / 8,
        1,
    )
    sdl.EndGPUComputePass(computePass)

    if vertex_count > 0 {
        ui_copy_pass := sdl.BeginGPUCopyPass(command_buffer)
        sdl.UploadToGPUBuffer(
            ui_copy_pass,
            sdl.GPUTransferBufferLocation {
                transfer_buffer = state.gpu.ui_transfer_buffer,
            },
            sdl.GPUBufferRegion {
                buffer = state.gpu.ui_vertex_buffer,
                size = u32(vertex_count * size_of(UIVertex)),
            },
            false,
        )
        sdl.EndGPUCopyPass(ui_copy_pass)
    }

    swapchainTexture : ^sdl.GPUTexture
    width, height : u32

    ok := sdl.WaitAndAcquireGPUSwapchainTexture(
        command_buffer,
        state.window,
        &swapchainTexture,
        &width,
        &height,
    )
    if !ok {
        log.errorf("unable to acquire swapchain texture: %s", sdl.GetError())
        return .FAILURE
    }
    if swapchainTexture == nil {
        ok = sdl.SubmitGPUCommandBuffer(command_buffer)
        if !ok {
            log.errorf(
                "unable to submit GPU command buffer: %s",
                sdl.GetError(),
            )
            return .FAILURE
        }
        return .CONTINUE
    }

    sdl.BlitGPUTexture(
        command_buffer,
        sdl.GPUBlitInfo {
            source = {
                texture = state.gpu.texture,
                w = state.window_width,
                h = state.window_height,
                mip_level = 0,
                layer_or_depth_plane = 0,
                x = 0,
                y = 0,
            },
            destination = {
                texture = swapchainTexture,
                w = width,
                h = height,
                mip_level = 0,
                layer_or_depth_plane = 0,
                x = 0,
                y = 0,
            },
            load_op = .DONT_CARE,
            filter = .LINEAR,
        },
    )

    if vertex_count > 0 {
        color_target := sdl.GPUColorTargetInfo {
            texture  = swapchainTexture,
            load_op  = .LOAD,
            store_op = .STORE,
        }
        render_pass := sdl.BeginGPURenderPass(
            command_buffer,
            &color_target,
            1,
            nil,
        )
        sdl.BindGPUGraphicsPipeline(render_pass, state.gpu.ui_pipeline)

        globals := UIGlobals {
            screen_size = {f32(width), f32(height)},
        }
        sdl.PushGPUVertexUniformData(
            command_buffer,
            0,
            &globals,
            size_of(UIGlobals),
        )

        buf_binding := [1]sdl.GPUBufferBinding {
            {buffer = state.gpu.ui_vertex_buffer},
        }
        sdl.BindGPUVertexBuffers(render_pass, 0, raw_data(buf_binding[:]), 1)

        tex_binding := [1]sdl.GPUTextureSamplerBinding {
            {
                texture = state.gpu.ui_font_texture,
                sampler = state.gpu.ui_font_sampler,
            },
        }
        sdl.BindGPUFragmentSamplers(
            render_pass,
            0,
            raw_data(tex_binding[:]),
            1,
        )

        sdl.DrawGPUPrimitives(render_pass, u32(vertex_count), 1, 0, 0)
        sdl.EndGPURenderPass(render_pass)
    }

    ok = sdl.SubmitGPUCommandBuffer(command_buffer)
    if !ok {
        log.errorf("unable to submit GPU command buffer: %s", sdl.GetError())
        return .FAILURE
    }

    return .CONTINUE
}
