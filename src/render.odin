package main

import "core:log"

import imgui "deps:imgui"
import imgui_impl_sdlgpu3 "deps:imgui/imgui_impl_sdlgpu3"

import sdl "vendor:sdl3"

render_frame :: proc(state: ^App_State, vertex_count: int) -> sdl.AppResult {
    command_buffer := sdl.AcquireGPUCommandBuffer(state.gpu.device)

    storage_texture_bindings := [1]sdl.GPUStorageTextureReadWriteBinding {
        {texture = state.gpu.texture},
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
        &state.fractal.uniform,
        size_of(Fractal_Uniform),
    )
    sdl.DispatchGPUCompute(
        compute_pass,
        (state.window_resolution.w + 7) / 8,
        (state.window_resolution.h + 7) / 8,
        1,
    )
    sdl.EndGPUComputePass(compute_pass)

    if vertex_count > 0 {
        ui_copy_pass := sdl.BeginGPUCopyPass(command_buffer)
        sdl.UploadToGPUBuffer(
            ui_copy_pass,
            sdl.GPUTransferBufferLocation {
                transfer_buffer = state.gpu.ui_transfer_buffer,
            },
            sdl.GPUBufferRegion {
                buffer = state.gpu.ui_vertex_buffer,
                size = u32(vertex_count * size_of(Ui_Vertex)),
            },
            false,
        )
        sdl.EndGPUCopyPass(ui_copy_pass)
    }

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
        log.errorf("unable to acquire swapchain texture: %s", sdl.GetError())
        return .FAILURE
    }
    if swapchain_texture == nil {
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
            load_op = .DONT_CARE,
            filter = .LINEAR,
        },
    )

    if vertex_count > 0 {
        color_target := sdl.GPUColorTargetInfo {
            texture  = swapchain_texture,
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

        globals := Ui_Globals {
            screen_size = {f32(width), f32(height)},
        }
        sdl.PushGPUVertexUniformData(
            command_buffer,
            0,
            &globals,
            size_of(Ui_Globals),
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

    imgui.Render()
    draw_data := imgui.GetDrawData()
    is_minimized :=
        draw_data.DisplaySize.x == 0 || draw_data.DisplaySize.y == 0

    if swapchain_texture != nil && !is_minimized {
        imgui_impl_sdlgpu3.PrepareDrawData(draw_data, command_buffer)

        target_info := sdl.GPUColorTargetInfo {
            texture     = swapchain_texture,
            load_op     = .LOAD,
            store_op    = .STORE,
        }
        render_pass := sdl.BeginGPURenderPass(
            command_buffer,
            &target_info,
            1,
            nil,
        )
        imgui_impl_sdlgpu3.RenderDrawData(
            draw_data,
            command_buffer,
            render_pass,
            nil,
        )

        sdl.EndGPURenderPass(render_pass)
    }

    io := imgui.GetIOImGuiContextPtr(state.imgui.ctx)
    if .ViewportsEnable in io.ConfigFlags {
        imgui.UpdatePlatformWindows()
        imgui.RenderPlatformWindowsDefault()
    }

    ok = sdl.SubmitGPUCommandBuffer(command_buffer)
    if !ok {
        log.errorf("unable to submit GPU command buffer: %s", sdl.GetError())
        return .FAILURE
    }

    return .CONTINUE
}
