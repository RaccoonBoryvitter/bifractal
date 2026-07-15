package main

import im "deps:imgui"
import im_sdlgpu "deps:imgui/imgui_impl_sdlgpu3"

import sdl "vendor:sdl3"

render_present_frame :: proc(state: ^App_State) -> sdl.AppResult {
    command_buffer := sdl.AcquireGPUCommandBuffer(state.gpu.device)

    storage_texture_bindings := [1]sdl.GPUStorageTextureReadWriteBinding {
        {texture = state.gpu.texture, cycle = true},
    }
    compute_pass := sdl.BeginGPUComputePass(
        command_buffer,
        raw_data(storage_texture_bindings[:]),
        1,
        nil,
        0,
    )
    sdl.BindGPUComputePipeline(compute_pass, state.gpu.compute_pipeline)
    sdl.PushGPUComputeUniformData(
        command_buffer,
        0,
        &state.fractal.params,
        size_of(Fractal_Params),
    )
    sdl.DispatchGPUCompute(
        compute_pass,
        (state.window_resolution.w + 7) / 8,
        (state.window_resolution.h + 7) / 8,
        1,
    )
    sdl.EndGPUComputePass(compute_pass)

    swapchain_texture: ^sdl.GPUTexture
    width, height: u32

    ok := sdl.WaitAndAcquireGPUSwapchainTexture(
        command_buffer,
        state.window,
        &swapchain_texture,
        &width,
        &height,
    )
    if !ok {
        sdl.LogError(
            i32(sdl.LogCategory.RENDER),
            "unable to acquire swapchain texture: %s",
            sdl.GetError(),
        )
        return .FAILURE
    }
    if swapchain_texture == nil {
        ok = sdl.SubmitGPUCommandBuffer(command_buffer)
        if !ok {
            sdl.LogError(
                i32(sdl.LogCategory.RENDER),
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
                w = state.window_resolution.w,
                h = state.window_resolution.h,
                mip_level = 0,
                layer_or_depth_plane = 0,
                x = 0,
                y = 0,
            },
            destination = {
                texture = swapchain_texture,
                w = width,
                h = height,
                mip_level = 0,
                layer_or_depth_plane = 0,
                x = 0,
                y = 0,
            },
            load_op = .CLEAR,
            clear_color = {0, 0, 0, 1},
            filter = .LINEAR,
        },
    )

    im.Render()
    draw_data := im.GetDrawData()
    is_minimized :=
        draw_data.DisplaySize.x == 0 || draw_data.DisplaySize.y == 0

    if swapchain_texture != nil && !is_minimized {
        im_sdlgpu.PrepareDrawData(draw_data, command_buffer)

        target_info := sdl.GPUColorTargetInfo {
            texture  = swapchain_texture,
            load_op  = .LOAD,
            store_op = .STORE,
        }
        render_pass := sdl.BeginGPURenderPass(
            command_buffer,
            &target_info,
            1,
            nil,
        )
        im_sdlgpu.RenderDrawData(draw_data, command_buffer, render_pass, nil)

        sdl.EndGPURenderPass(render_pass)
    }

    ok = sdl.SubmitGPUCommandBuffer(command_buffer)
    if !ok {
        sdl.LogError(
            i32(sdl.LogCategory.RENDER),
            "unable to submit GPU command buffer: %s",
            sdl.GetError(),
        )
        return .FAILURE
    }

    return .CONTINUE
}
