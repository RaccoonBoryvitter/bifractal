package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:math"

import mu "vendor:microui"
import sdl "vendor:sdl3"

@(export)
SDL_AppInit :: proc "c" (
    appstate : ^rawptr,
    argc : c.int,
    argv : [^]cstring,
) -> sdl.AppResult {
    context = runtime.default_context()
    state := init_app(context)
    if state == nil {
        return .FAILURE
    }

    appstate^ = rawptr(state)
    return .CONTINUE
}

@(export)
SDL_AppEvent :: proc "c" (
    appstate : rawptr,
    event : ^sdl.Event,
) -> sdl.AppResult {
    state := (^AppState)(appstate)
    context = state.ctx

    handle_ui_events(event, state)

    // Fractal input handling
    fractal_result := handle_fractal_events(event, state)
    if fractal_result != .CONTINUE {
        return fractal_result
    }

    return .CONTINUE
}

fps_update :: proc(state : ^AppState) {
    state.fps_frame_count += 1
    now := sdl.GetTicks()
    elapsed := now - state.fps_last_ticks

    if elapsed >= FPS_INTERVAL_MS {
        state.fps_current = f32(state.fps_frame_count) / (f32(elapsed) / 1000.0)
        state.fps_frame_count = 0
        state.fps_last_ticks = now
    }
}

@(export)
SDL_AppIterate :: proc "c" (appstate : rawptr) -> sdl.AppResult {
    state := (^AppState)(appstate)
    context = state.ctx
    defer free_all(context.temp_allocator)

    fps_update(state)
    create_ui(state)
    vertex_count := handle_mu_commands(state)

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

@(export)
SDL_AppQuit :: proc "c" (appstate : rawptr, result : sdl.AppResult) {
    state := (^AppState)(appstate)
    context = state.ctx

    sdl.DestroyCursor(state.fractal.move_cursor)
    sdl.DestroyCursor(state.fractal.default_cursor)

    sdl.ReleaseGPUBuffer(state.gpu.device, state.gpu.ui_vertex_buffer)
    sdl.ReleaseGPUTransferBuffer(
        state.gpu.device,
        state.gpu.ui_transfer_buffer,
    )
    sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.ui_font_texture)
    sdl.ReleaseGPUSampler(state.gpu.device, state.gpu.ui_font_sampler)
    sdl.ReleaseGPUGraphicsPipeline(state.gpu.device, state.gpu.ui_pipeline)

    sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.texture)
    sdl.ReleaseGPUComputePipeline(state.gpu.device, state.gpu.compute_pipeline)

    sdl.DestroyGPUDevice(state.gpu.device)
    sdl.DestroyWindow(state.window)
    sdl.Quit()

    log.destroy_console_logger(context.logger)
    free(state)
}
