package main

import "base:runtime"
import "core:strings"
import "core:log"
import "core:os"
import "core:c"

import sdl "vendor:sdl3"

AppState :: struct {
    ctx: runtime.Context,

    window: ^sdl.Window,
    device: ^sdl.GPUDevice,

    compute_pipeline: ^sdl.GPUComputePipeline,
    texture: ^sdl.GPUTexture,
    
    uniform: UniformBuffer,
    window_width: u32,
    window_height: u32,
}

UniformBuffer :: struct {
    center: [2]f32,
    zoom: f32,
    max_iter: i32,

    palette_a: [3]f32,
    _pad_a: f32,

    palette_b: [3]f32,
    _pad_b: f32,

    palette_c: [3]f32,
    _pad_c: f32,

    palette_d: [3]f32,
    _pad_d: f32,

    resolution: [2]f32,
}

create_compute_pipeline :: proc(
    filepath: cstring, 
    device: ^sdl.GPUDevice
) -> ^sdl.GPUComputePipeline
{
    shaderCodeSize : uint
    shaderCode := sdl.LoadFile(filepath, &shaderCodeSize)
    defer sdl.free(shaderCode)

    computePipelineInfo := sdl.GPUComputePipelineCreateInfo{
        code = (^u8)(shaderCode),
        code_size = shaderCodeSize,
        entrypoint = "main",
        format = {.SPIRV},
        num_uniform_buffers = 1,
        num_readwrite_storage_textures = 1,
        threadcount_x = 8,
        threadcount_y = 8,
        threadcount_z = 1,
    }
    compute_pipeline := sdl.CreateGPUComputePipeline(device, computePipelineInfo)

    return compute_pipeline
}

create_output_texture :: proc(
    device: ^sdl.GPUDevice,
    width, height: u32
) -> ^sdl.GPUTexture
{
    createInfo := sdl.GPUTextureCreateInfo{
        type = .D2,
        format = .R8G8B8A8_UNORM,
        width = width,
        height = height,
        layer_count_or_depth = 1,
        num_levels = 1,
        usage = {.COMPUTE_STORAGE_WRITE, .SAMPLER, .COMPUTE_STORAGE_READ}
    }
    return sdl.CreateGPUTexture(device, createInfo)
}

@(export)
SDL_AppInit :: proc "c" (
    appstate: ^rawptr,
    argc: c.int,
    argv: [^]cstring,
) -> sdl.AppResult {
    context = runtime.default_context()
    context.logger = log.create_console_logger()

    state := new(AppState)
    state.ctx = context

    appstate^ = rawptr(state)

    ok := sdl.Init({.VIDEO, .EVENTS})
    if !ok {
        log.errorf("unable to initialize SDL: %s", sdl.GetError())
        return .FAILURE
    }

    window := sdl.CreateWindow("Odin Zoom", 1280, 720, {.RESIZABLE, .HIGH_PIXEL_DENSITY})
    if window == nil {
        log.errorf("unable to create SDL window: %s", sdl.GetError())
        return .FAILURE
    }
    state.window = window
    
    gpu_device := sdl.CreateGPUDevice({.SPIRV}, true, nil)
    if gpu_device == nil {
        log.errorf("unable to create SDL GPU device: %s", sdl.GetError())
        return .FAILURE
    }
    state.device = gpu_device

    ok = sdl.ClaimWindowForGPUDevice(state.device, state.window)
    if !ok {
        log.errorf("unable to claim window for GPU device: %s", sdl.GetError())
        return .FAILURE
    }

    compute_pipeline := create_compute_pipeline("../assets/shaders/compiled/mandelbrot.spv", state.device)
    if compute_pipeline == nil {
        log.errorf("unable to create GPU compute pipeline: %s", sdl.GetError())
        return .FAILURE
    }
    state.compute_pipeline = compute_pipeline

    sdl.GetWindowSizeInPixels(
        state.window,
        (^i32)(&state.window_width),
        (^i32)(&state.window_height),
    )

    state.texture = create_output_texture(state.device, state.window_width, state.window_height)

    state.uniform = UniformBuffer{
        center = { -0.5, 0.0 },
        zoom = 0.5,
        max_iter = 256,
        resolution = { f32(state.window_width), f32(state.window_height) },
        palette_a  = { 0.5, 0.5, 0.5 },
        palette_b  = { 0.5, 0.5, 0.5 },
        palette_c  = { 1.0, 1.0, 1.0 },
        palette_d  = { 0.0, 0.10, 0.20 },
    }

    return .CONTINUE
}

@(export)
SDL_AppEvent :: proc "c" (
    appstate: rawptr,
    event: ^sdl.Event,
) -> sdl.AppResult {
    state := (^AppState)(appstate)
    context = state.ctx

    #partial switch event.type {
    case .QUIT, .WINDOW_CLOSE_REQUESTED:
        return .SUCCESS
    case .WINDOW_PIXEL_SIZE_CHANGED:
        e := event.window
        state.window_width = u32(e.data1)
        state.window_height = u32(e.data2)
        state.uniform.resolution = { f32(e.data1), f32(e.data2) }

        sdl.ReleaseGPUTexture(state.device, state.texture)
        state.texture = create_output_texture(
            state.device,
            state.window_width,
            state.window_height
        )
        return .CONTINUE
    case:
        return .CONTINUE
    }

    return .CONTINUE
}

@(export)
SDL_AppIterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    state := (^AppState)(appstate)
    context = state.ctx

    command_buffer := sdl.AcquireGPUCommandBuffer(state.device)

    storageTextureBindings := [1]sdl.GPUStorageTextureReadWriteBinding{
        { texture = state.texture }
    }
    computePass := sdl.BeginGPUComputePass(
        command_buffer,
        raw_data(storageTextureBindings[:]),
        1,
        nil,
        0
    )
    sdl.BindGPUComputePipeline(computePass, state.compute_pipeline)
    sdl.PushGPUComputeUniformData(
        command_buffer,
        0,
        &state.uniform,
        size_of(UniformBuffer)
    )
    sdl.DispatchGPUCompute(
        computePass,
        (state.window_width + 7) / 8,
        (state.window_height + 7) / 8,
        1
    )
    sdl.EndGPUComputePass(computePass)

    swapchainTexture: ^sdl.GPUTexture
    width, height: u32

    ok := sdl.WaitAndAcquireGPUSwapchainTexture(
        command_buffer,
        state.window,
        &swapchainTexture,
        &width,
        &height
    )
    if !ok {
        log.errorf("unable to acquire swapchain texture: %s", sdl.GetError())
        return .FAILURE
    }
    if swapchainTexture == nil {
        ok = sdl.SubmitGPUCommandBuffer(command_buffer)
        if !ok {
            log.errorf("unable to submit GPU command buffer: %s", sdl.GetError())
            return .FAILURE
        }
        return .CONTINUE
    }

    blitInfo := sdl.GPUBlitInfo{
        source = {
            texture = state.texture,
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
        filter  = .LINEAR,
    }
    sdl.BlitGPUTexture(command_buffer, blitInfo)

    ok = sdl.SubmitGPUCommandBuffer(command_buffer)
    if !ok {
        log.errorf("unable to submit GPU command buffer: %s", sdl.GetError())
        return .FAILURE
    }

    return .CONTINUE
}

@(export)
SDL_AppQuit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
    // Probably, the result should be handled somehow?
    // Like, if it's a failure, then we just output the error?
    // I don't know, but let's ignore it for now
    state := (^AppState)(appstate)

    // Some comments say that `SDL_AppQuit` will call these functions for us
    // but I don't trust them, and I'm overprotective
    sdl.ReleaseGPUTexture(state.device, state.texture)
    sdl.ReleaseGPUComputePipeline(state.device, state.compute_pipeline)

    sdl.DestroyGPUDevice(state.device)
    sdl.DestroyWindow(state.window)
    sdl.Quit()

    context = state.ctx
    log.destroy_console_logger(context.logger)

    // I don't know if I should clean it like this, but why not?
    state = nil
}


main :: proc() {
    argc := cast(c.int)len(os.args)
    argv := make([]cstring, argc)
    defer delete(argv)

    for arg, i in os.args {
        c_arg, err := strings.clone_to_cstring(arg)
        if err != .None {
            panic("unexpected error ocurred while trying to retrieve application arguments")
        }

        argv[i] = c_arg
    }
    defer for arg in argv {
        delete (arg)
    }

    sdl.EnterAppMainCallbacks(
        argc,
        raw_data(argv),
        SDL_AppInit,
        SDL_AppIterate,
        SDL_AppEvent,
        SDL_AppQuit
    )
}
