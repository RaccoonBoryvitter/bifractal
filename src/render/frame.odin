package render

import "core:log"
import "core:mem"

import im "deps:imgui"
import im_sdlgpu "deps:imgui/imgui_impl_sdlgpu3"
import sdl "vendor:sdl3"

import "../fractal"
import "../geom"
import "../platform"

Render_View :: struct {
    gpu:         ^platform.Gpu_Context,
    kind:        fractal.Fractal_Kind,
    fractal:     ^fractal.Fractal,
    window:      ^sdl.Window,
    window_size: geom.Extent_2D,
}

render_context_begin :: proc(
    view: ^Render_View,
) -> (
    ctx: Render_Context,
    ok: bool,
) {
    ctx.cmd = sdl.AcquireGPUCommandBuffer(view.gpu.device)
    if ctx.cmd == nil {
        log.warnf("unable to acquire GPU command buffer: %s", sdl.GetError())
        return ctx, false
    }

    backing := make([]byte, 4 * 1024, context.temp_allocator)
    mem.arena_init(&ctx.scratch, backing)

    return ctx, true
}

render_context_end :: proc(ctx: ^Render_Context) {
    if ctx.cmd != nil {
        if !sdl.SubmitGPUCommandBuffer(ctx.cmd) {
            log.errorf(
                "unable to submit GPU command buffer: %s",
                sdl.GetError(),
            )
        }
    }
    mem.arena_free_all(&ctx.scratch)
}

render_compute_pass :: proc(view: ^Render_View, ctx: ^Render_Context) {
    ctx.pass = .Compute

    storage_texture_bindings := [1]sdl.GPUStorageTextureReadWriteBinding {
        {texture = view.gpu.output, cycle = true},
    }
    compute_pass := sdl.BeginGPUComputePass(
        ctx.cmd,
        raw_data(storage_texture_bindings[:]),
        1,
        nil,
        0,
    )
    sdl.BindGPUComputePipeline(compute_pass, view.gpu.pipelines[view.kind])

    uniform_size := fractal.fractal_uniform_size(view.fractal)
    uniform, alloc_err := mem.arena_alloc(&ctx.scratch, uniform_size)
    if alloc_err != .None {
        sdl.EndGPUComputePass(compute_pass)
        ctx.pass = .None
        return
    }
    if !fractal.fractal_make_uniform(view.fractal, uniform) {
        sdl.EndGPUComputePass(compute_pass)
        ctx.pass = .None
        return
    }

    sdl.PushGPUComputeUniformData(ctx.cmd, 0, uniform, u32(uniform_size))
    sdl.DispatchGPUCompute(
        compute_pass,
        (view.window_size.w + 7) / 8,
        (view.window_size.h + 7) / 8,
        1,
    )
    sdl.EndGPUComputePass(compute_pass)

    ctx.pass = .None
}

render_blit_pass :: proc(
    view: ^Render_View,
    ctx: ^Render_Context,
) -> (
    swapchain_texture: ^sdl.GPUTexture,
    ok: bool,
) {
    ctx.pass = .Blit

    width, height: u32
    ok = sdl.WaitAndAcquireGPUSwapchainTexture(
        ctx.cmd,
        view.window,
        &swapchain_texture,
        &width,
        &height,
    )
    if !ok {
        log.errorf("unable to acquire swapchain texture: %s", sdl.GetError())
        ctx.pass = .None
        return nil, false
    }
    if swapchain_texture == nil {
        ctx.pass = .None
        return nil, true
    }

    sdl.BlitGPUTexture(
        ctx.cmd,
        sdl.GPUBlitInfo {
            source = {
                texture = view.gpu.output,
                w = view.window_size.w,
                h = view.window_size.h,
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

    ctx.pass = .None
    return swapchain_texture, true
}

render_ui_pass :: proc(
    view: ^Render_View,
    ctx: ^Render_Context,
    swapchain_texture: ^sdl.GPUTexture,
) {
    ctx.pass = .Ui

    im.Render()
    draw_data := im.GetDrawData()
    is_minimized :=
        draw_data.DisplaySize.x == 0 || draw_data.DisplaySize.y == 0

    if swapchain_texture != nil && !is_minimized {
        im_sdlgpu.PrepareDrawData(draw_data, ctx.cmd)

        target_info := sdl.GPUColorTargetInfo {
            texture  = swapchain_texture,
            load_op  = .LOAD,
            store_op = .STORE,
        }
        render_pass := sdl.BeginGPURenderPass(ctx.cmd, &target_info, 1, nil)
        im_sdlgpu.RenderDrawData(draw_data, ctx.cmd, render_pass, nil)

        sdl.EndGPURenderPass(render_pass)
    }

    ctx.pass = .None
}

render_present_frame :: proc(view: ^Render_View) -> sdl.AppResult {
    if !view.gpu.valid {
        return .FAILURE
    }

    ctx, ok := render_context_begin(view)
    if !ok {
        return .FAILURE
    }
    defer render_context_end(&ctx)

    render_compute_pass(view, &ctx)

    swapchain_texture, blit_ok := render_blit_pass(view, &ctx)
    if !blit_ok {
        return .FAILURE
    }
    if swapchain_texture == nil {
        return .CONTINUE
    }

    render_ui_pass(view, &ctx, swapchain_texture)

    return .CONTINUE
}
