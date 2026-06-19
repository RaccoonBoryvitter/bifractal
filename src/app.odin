package main

import "core:log"
import "core:math"
import "base:runtime"

import sdl "vendor:sdl3"
import mu  "vendor:microui"

init_sdl_window :: proc() -> ^sdl.Window {
    ok := sdl.Init({.VIDEO, .EVENTS})
    if !ok {
        log.errorf("unable to initialize SDL: %s", sdl.GetError())
        return nil
    }

    window := sdl.CreateWindow(
        WINDOW_TITLE,
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        {.RESIZABLE, .HIGH_PIXEL_DENSITY}
    )
    if window == nil {
        log.errorf("unable to create SDL window: %s", sdl.GetError())
        return nil
    }
    
    return window
}

init_gpu :: proc(window: ^sdl.Window) -> ^sdl.GPUDevice {
    gpu_device := sdl.CreateGPUDevice({.SPIRV}, true, nil)
    if gpu_device == nil {
        log.errorf("unable to create SDL GPU device: %s", sdl.GetError())
        return nil
    }

    ok := sdl.ClaimWindowForGPUDevice(gpu_device, window)
    if !ok {
        log.errorf("unable to claim window for GPU device: %s", sdl.GetError())
        return nil
    }

    return gpu_device
}

init_fractal_compute :: proc(state: ^AppState) -> bool {
    compute_pipeline := create_compute_pipeline(
        MANDELBROT_SHADER_PATH,
        state.gpu.device
    )
    if compute_pipeline == nil {
        log.errorf("unable to create GPU compute pipeline: %s", sdl.GetError())
        return false
    }
    state.gpu.compute_pipeline = compute_pipeline

    state.gpu.texture = create_output_texture(
        state.gpu.device,
        state.window_width,
        state.window_height
    )

    return true
}

init_fractal_state :: proc(state: ^AppState) -> FractalState {
    zoom := FRACTAL_DEFAULT_ZOOM
    return FractalState{
        uniform = {
            center = { FRACTAL_DEFAULT_CENTER_X, FRACTAL_DEFAULT_CENTER_Y },
            zoom = FRACTAL_DEFAULT_ZOOM,
            max_iter = FRACTAL_DEFAULT_MAX_ITER,
            resolution = { f32(state.window_width), f32(state.window_height) },
            palette_a  = { 0.5, 0.5, 0.5 },
            palette_b  = { 0.5, 0.5, 0.5 },
            palette_c  = { 1.0, 1.0, 1.0 },
            palette_d  = { 0.0, 0.10, 0.20 },
        },
        zoom_level = math.log2(f32(zoom)),
        default_cursor = sdl.CreateSystemCursor(.DEFAULT),
        move_cursor = sdl.CreateSystemCursor(.MOVE),
    }
}

init_ui_pipeline :: proc(state: ^AppState) -> bool {
    ui_vertex_shader := create_gpu_shader(
        state.gpu.device,
        UI_VERTEX_SHADER_PATH,
        .VERTEX,
        num_uniform_buffers = 1
    )
    if ui_vertex_shader == nil {
        return false
    }

    ui_fragment_shader := create_gpu_shader(
        state.gpu.device,
        UI_FRAGMENT_SHADER_PATH,
        .FRAGMENT,
        num_samplers = 1
    )
    if ui_fragment_shader == nil {
        return false
    }

    ui_vertex_buffer_descs := [1]sdl.GPUVertexBufferDescription{{
        slot = 0,
        pitch = size_of(UIVertex),
        input_rate = .VERTEX,
    }}

    ui_vertex_attrs := [3]sdl.GPUVertexAttribute{
        { location = 0, buffer_slot = 0, format = .FLOAT2, offset = 0 },
        { location = 1, buffer_slot = 0, format = .FLOAT2, offset = size_of(f32) * 2 },
        { location = 2, buffer_slot = 0, format = .FLOAT4, offset = size_of(f32) * 4 },
    }

    color_targets := [1]sdl.GPUColorTargetDescription{{
        format = sdl.GetGPUSwapchainTextureFormat(state.gpu.device, state.window),
        blend_state = {
            enable_blend = true,
            color_blend_op = .ADD,
            alpha_blend_op = .ADD,
            src_color_blendfactor = .SRC_ALPHA,
            dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
            src_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
            dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
        },
    }}

    ui_pipeline := sdl.CreateGPUGraphicsPipeline(
        state.gpu.device,
        sdl.GPUGraphicsPipelineCreateInfo{
            vertex_shader = ui_vertex_shader,
            fragment_shader = ui_fragment_shader,
            primitive_type = .TRIANGLELIST,
            vertex_input_state = {
                num_vertex_buffers = 1,
                vertex_buffer_descriptions = raw_data(ui_vertex_buffer_descs[:]),
                num_vertex_attributes = 3,
                vertex_attributes = raw_data(ui_vertex_attrs[:]),
            },
            target_info = {
                num_color_targets = 1,
                color_target_descriptions = raw_data(color_targets[:])
            },
        }
    )
    sdl.ReleaseGPUShader(state.gpu.device, ui_vertex_shader)
    sdl.ReleaseGPUShader(state.gpu.device, ui_fragment_shader)
    state.gpu.ui_pipeline = ui_pipeline

    return true
}

init_ui_resources :: proc(state: ^AppState) {
    state.gpu.ui_vertex_buffer = sdl.CreateGPUBuffer(
        state.gpu.device,
        sdl.GPUBufferCreateInfo{
            size = size_of(UIVertex) * MAX_UI_VERTICES,
            usage = {.VERTEX},
        }
    )
    state.gpu.ui_transfer_buffer = sdl.CreateGPUTransferBuffer(
        state.gpu.device,
        sdl.GPUTransferBufferCreateInfo{
            size = size_of(UIVertex) * MAX_UI_VERTICES,
            usage = .UPLOAD
        }
    )

    state.gpu.ui_font_texture = create_font_texture(state.gpu.device)
    state.gpu.ui_font_sampler = sdl.CreateGPUSampler(
        state.gpu.device,
        sdl.GPUSamplerCreateInfo{
            min_filter = .NEAREST,
            mag_filter = .NEAREST,
        }
    )

    mu.init(&state.ui_context)
    state.ui_context.text_width = mu.default_atlas_text_width
    state.ui_context.text_height = mu.default_atlas_text_height
}

init_app :: proc(ctx: runtime.Context) -> ^AppState {
    context = ctx

    state := new(AppState)
    state.ctx = context
    context.logger = log.create_console_logger()

    state.window = init_sdl_window()
    if state.window == nil {
        return nil
    }

    sdl.GetWindowSizeInPixels(
        state.window,
        (^i32)(&state.window_width),
        (^i32)(&state.window_height),
    )

    state.gpu.device = init_gpu(state.window)
    if state.gpu.device == nil {
        return nil
    }

    if !init_fractal_compute(state) {
        return nil
    }

    state.fractal = init_fractal_state(state)

    if !init_ui_pipeline(state) {
        return nil
    }

    init_ui_resources(state)

    return state
}
