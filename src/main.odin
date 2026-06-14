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
    vertex_buffer: ^sdl.GPUBuffer,
    transfer_buffer: ^sdl.GPUTransferBuffer,
    graphics_pipeline: ^sdl.GPUGraphicsPipeline,
    
    uniform: UniformBuffer,
}

Vertex :: struct {
    position: [3]f32,
    color: [4]f32
}

UniformBuffer :: struct {
    time: f32
}

vertices :: []Vertex{
    { position = {  0.0,  0.5, 0.0 }, color = { 1.0, 0.0, 0.0, 1.0 } }, // top vertex
    { position = { -0.5, -0.5, 0.0 }, color = { 1.0, 1.0, 0.0, 1.0 } }, // bottom left vertex
    { position = {  0.5, -0.5, 0.0 }, color = { 1.0, 0.0, 1.0, 1.0 } }, // bottom right vertex
}

verticesSize := size_of(Vertex) * len(vertices)

create_gpu_shader :: proc(
    filepath: cstring, 
    shader_type: sdl.GPUShaderStage,
    device: ^sdl.GPUDevice,
    use_uniform: bool
) -> ^sdl.GPUShader
{
    shaderCodeSize : uint
    shaderCode := sdl.LoadFile(filepath, &shaderCodeSize)

    shaderInfo := sdl.GPUShaderCreateInfo{
        code = (^u8)(shaderCode),
        code_size = shaderCodeSize,
        entrypoint = "main",
        format = {.SPIRV},
        stage = shader_type,
        num_samplers = 0,
        num_storage_buffers = 0,
        num_storage_textures = 0,
        num_uniform_buffers = use_uniform ? 1 : 0,
    }

    shader := sdl.CreateGPUShader(device, shaderInfo)
    sdl.free(shaderCode)

    return shader
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
    state.uniform = {}

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
    
    gpu_device := sdl.CreateGPUDevice({.SPIRV}, false, nil)
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

    vertexShader := create_gpu_shader(
        "../assets/shaders/compiled/vertex.spv",
        .VERTEX,
        state.device,
        false
    )
    fragmentShader := create_gpu_shader(
        "../assets/shaders/compiled/fragment.spv",
        .FRAGMENT,
        state.device,
        true
    )

    vertexBufferDescriptions := [1]sdl.GPUVertexBufferDescription{
        {
            slot = 0,
            input_rate = .VERTEX,
            instance_step_rate = 0,
            pitch = size_of(Vertex),
        }
    }

    vertexAttributes := [2]sdl.GPUVertexAttribute{
        {
            buffer_slot = 0,
            location = 0,
            format = .FLOAT3,
            offset = 0,
        },
        {
            buffer_slot = 0,
            location = 1,
            format = .FLOAT4,
            offset = size_of(f32) * 3,
        }
    }

    colorTargetDescriptions := [1]sdl.GPUColorTargetDescription{
        {
            format = sdl.GetGPUSwapchainTextureFormat(state.device, state.window),
            blend_state = {
                enable_blend = true,
                color_blend_op = .ADD,
                alpha_blend_op = .ADD,
                src_color_blendfactor = .SRC_ALPHA,
                dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
                src_alpha_blendfactor = .SRC_ALPHA,
                dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
            }
        }
    }

    pipelineInfo := sdl.GPUGraphicsPipelineCreateInfo{
        vertex_shader = vertexShader,
        fragment_shader = fragmentShader,
        primitive_type = .TRIANGLELIST,
        vertex_input_state = {
            num_vertex_buffers = 1,
            vertex_buffer_descriptions = raw_data(vertexBufferDescriptions[:]),
            num_vertex_attributes = 2,
            vertex_attributes = raw_data(vertexAttributes[:])
        },
        target_info = {
            num_color_targets = 1,
            color_target_descriptions = raw_data(colorTargetDescriptions[:])
        }
    }

    graphics_pipeline := sdl.CreateGPUGraphicsPipeline(state.device, pipelineInfo)
    if graphics_pipeline == nil {
        log.errorf("unable to create GPU graphics pipeline: %s", sdl.GetError())
        return .FAILURE
    }
    state.graphics_pipeline = graphics_pipeline

    sdl.ReleaseGPUShader(state.device, vertexShader)
    sdl.ReleaseGPUShader(state.device, fragmentShader)

    bufferInfo := sdl.GPUBufferCreateInfo{
        size = u32(verticesSize),
        usage = {.VERTEX}
    }
    vertexBuffer := sdl.CreateGPUBuffer(state.device, bufferInfo)
    if vertexBuffer == nil {
        log.errorf("unable to create GPU vertex buffer: %s", sdl.GetError())
        return .FAILURE
    }
    state.vertex_buffer = vertexBuffer

    transferBufferCreateInfo := sdl.GPUTransferBufferCreateInfo{
        size = u32(verticesSize),
        usage = .UPLOAD
    }
    transferBuffer := sdl.CreateGPUTransferBuffer(state.device, transferBufferCreateInfo)
    if transferBuffer == nil {
        log.errorf("unable to create GPU transfer buffer: %s", sdl.GetError())
        return .FAILURE
    }
    state.transfer_buffer = transferBuffer

    vertexData := sdl.MapGPUTransferBuffer(state.device, state.transfer_buffer, false)
    sdl.memcpy(vertexData, raw_data(vertices), uint(verticesSize))
    sdl.UnmapGPUTransferBuffer(state.device, state.transfer_buffer)
    
    command_buffer := sdl.AcquireGPUCommandBuffer(state.device)
    copy_pass := sdl.BeginGPUCopyPass(command_buffer)

    transferBufferLocation := sdl.GPUTransferBufferLocation{
        transfer_buffer = state.transfer_buffer,
        offset = 0,
    }

    bufferRegion := sdl.GPUBufferRegion{
        buffer = state.vertex_buffer,
        size = u32(verticesSize),
        offset = 0,
    }

    sdl.UploadToGPUBuffer(copy_pass, transferBufferLocation, bufferRegion, true)

    sdl.EndGPUCopyPass(copy_pass)
    ok = sdl.SubmitGPUCommandBuffer(command_buffer)
    if !ok {
        log.errorf("unable to submit GPU command buffer: %s", sdl.GetError())
        return .FAILURE
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
    case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
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

    swapchainTexture : ^sdl.GPUTexture
    width, height : u32

    ok := sdl.WaitAndAcquireGPUSwapchainTexture(
        command_buffer,
        state.window,
        &swapchainTexture,
        &width,
        &height
    )
    if !ok {
        log.errorf("unable to acquire GPU swapchain texture: %s", sdl.GetError())
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

    colorTargetInfo := sdl.GPUColorTargetInfo{
        texture = swapchainTexture,
        clear_color = { 240.0 / 255.0, 240.0 / 255.0, 240.0 / 255.0, 255.0 / 255.0 },
        load_op = .CLEAR,
        store_op = .STORE,
    }

    render_pass := sdl.BeginGPURenderPass(command_buffer, &colorTargetInfo, 1, nil)

    sdl.BindGPUGraphicsPipeline(render_pass, state.graphics_pipeline)

    bufferBindings := [1]sdl.GPUBufferBinding{
        {
            buffer = state.vertex_buffer,
            offset = 0
        }
    }
    sdl.BindGPUVertexBuffers(render_pass, 0, raw_data(bufferBindings[:]), 1)

    state.uniform.time = f32(sdl.GetTicksNS()) / 1e9
    sdl.PushGPUFragmentUniformData(command_buffer, 0, &state.uniform, size_of(UniformBuffer))

    sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)

    sdl.EndGPURenderPass(render_pass)

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
    sdl.ReleaseGPUBuffer(state.device, state.vertex_buffer)
    sdl.ReleaseGPUTransferBuffer(state.device, state.transfer_buffer)
    sdl.ReleaseGPUGraphicsPipeline(state.device, state.graphics_pipeline)

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
