package main

import "base:runtime"
import "core:strings"
import "core:log"
import "core:os"
import "core:c"

import sdl "vendor:sdl3"
import "vendor:wgpu"
import "vendor:wgpu/sdl3glue"

AppState :: struct {
    ctx: runtime.Context,

    window: ^sdl.Window,
    instance: wgpu.Instance,
    surface: wgpu.Surface,
    adapter: wgpu.Adapter,
    device: wgpu.Device,
    surface_configuration: wgpu.SurfaceConfiguration,
    queue: wgpu.Queue,
    shader_module: wgpu.ShaderModule,
    pipeline_layout: wgpu.PipelineLayout,
    render_pipeline: wgpu.RenderPipeline
}

wgpu_on_adapter :: proc "c" (
    status: wgpu.RequestAdapterStatus,
    adapter: wgpu.Adapter,
    message: wgpu.StringView,
    userdata1: rawptr,
    userdata2: rawptr
) {
    state := (^AppState)(userdata1)
    context = state.ctx

    if status != .Success || adapter == nil {
        log.errorf("unable to request WGPU adapter: [%v] %s", status, message)
        return
    }

    state.adapter = adapter
    wgpu.AdapterRequestDevice(adapter, nil, { callback = wgpu_on_device, userdata1 = userdata1 })
}

wgpu_on_device :: proc "c" (
    status: wgpu.RequestDeviceStatus,
    device: wgpu.Device,
    message: wgpu.StringView,
    userdata1: rawptr,
    userdata2: rawptr
) {
    state := (^AppState)(userdata1)
    context = state.ctx

    if status != .Success || device == nil {
        log.errorf("unable to request WGPU device: [%v] %s", status, message)
        return
    }

    state.device = device
    width, height := get_framebuffer_size(state.window)
    state.surface_configuration = wgpu.SurfaceConfiguration {
        device      = state.device,
		usage       = { .RenderAttachment },
		format      = .BGRA8Unorm,
		width       = width,
		height      = height,
		presentMode = .Fifo,
		alphaMode   = .Opaque,
    }
    wgpu.SurfaceConfigure(state.surface, &state.surface_configuration)

    state.queue = wgpu.DeviceGetQueue(state.device)

    shader :: `
    @vertex
	fn vs_main(@builtin(vertex_index) in_vertex_index: u32) -> @builtin(position) vec4<f32> {
		let x = f32(i32(in_vertex_index) - 1);
		let y = f32(i32(in_vertex_index & 1u) * 2 - 1);
		return vec4<f32>(x, y, 0.0, 1.0);
	}

	@fragment
	fn fs_main() -> @location(0) vec4<f32> {
		return vec4<f32>(1.0, 0.0, 0.0, 1.0);
	}`

    state.shader_module = wgpu.DeviceCreateShaderModule(state.device, &{
        nextInChain = &wgpu.ShaderSourceWGSL {
            sType = .ShaderSourceWGSL,
            code = shader,
        }
    })

    state.pipeline_layout = wgpu.DeviceCreatePipelineLayout(state.device, &{ })
    state.render_pipeline = wgpu.DeviceCreateRenderPipeline(state.device, &{
        layout = state.pipeline_layout,
        vertex = {
            module = state.shader_module,
            entryPoint = "vs_main",
        },
        fragment = &{
            module = state.shader_module,
            entryPoint = "fs_main",
            targetCount = 1,
            targets = &wgpu.ColorTargetState {
                format = .BGRA8Unorm,
                writeMask = wgpu.ColorWriteMaskFlags_All
            },
        },
        primitive = {
            topology = .TriangleList
        },
        multisample = {
            count = 1,
            mask = 0xFFFFFFFF
        }
    })
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
    wgpu_instance := wgpu.CreateInstance()
    if wgpu_instance == nil {
        log.error("unable to create WGPU instance")
        return .FAILURE
    }
    state.instance = wgpu_instance

    surface := sdl3glue.GetSurface(wgpu_instance, window)
    if surface == nil {
        log.error("unable to create WGPU surface")
        return .FAILURE
    }
    state.surface = surface

    wgpu.InstanceRequestAdapter(wgpu_instance, &{ compatibleSurface = surface }, { callback = wgpu_on_adapter, userdata1 = state })

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
    case .QUIT:
        return .SUCCESS
    case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
        resize(state)
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

    surface_texture := wgpu.SurfaceGetCurrentTexture(state.surface)
    switch surface_texture.status {
	case .SuccessOptimal, .SuccessSuboptimal:
		// All good, could handle suboptimal here.
	case .Timeout, .Outdated, .Lost:
		// Skip this frame, and re-configure surface.
		if surface_texture.texture != nil {
			wgpu.TextureRelease(surface_texture.texture)
		}
		resize(state)
		return .CONTINUE
	case .Occluded:
		// Window is occluded (e.g. minimized), skip this frame.
		return .CONTINUE
	case .Error:
		// Fatal error
        log.errorf("[triangle] get_current_texture status=%v", surface_texture.status)
        return .FAILURE
	}
    defer wgpu.TextureRelease(surface_texture.texture)

    frame := wgpu.TextureCreateView(surface_texture.texture, nil)
    defer wgpu.TextureViewRelease(frame)

    command_encoder := wgpu.DeviceCreateCommandEncoder(state.device, nil)
    defer wgpu.CommandEncoderRelease(command_encoder)

    render_pass_encoder := wgpu.CommandEncoderBeginRenderPass(
        command_encoder,
        &{
            colorAttachmentCount = 1,
            colorAttachments = &wgpu.RenderPassColorAttachment{
                view = frame,
                loadOp = .Clear,
                storeOp = .Store,
                depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
                clearValue = { 0, 1, 0, 1 },
            },
        },
    )

    wgpu.RenderPassEncoderSetPipeline(render_pass_encoder, state.render_pipeline)
    wgpu.RenderPassEncoderDraw(render_pass_encoder, vertexCount=3, instanceCount=1, firstVertex=0, firstInstance=0)

    wgpu.RenderPassEncoderEnd(render_pass_encoder)
    wgpu.RenderPassEncoderRelease(render_pass_encoder)

    command_buffer := wgpu.CommandEncoderFinish(command_encoder, nil)
    defer wgpu.CommandBufferRelease(command_buffer)

    wgpu.QueueSubmit(state.queue, { command_buffer })
    wgpu.SurfacePresent(state.surface)

    return .CONTINUE
}

@(export)
SDL_AppQuit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
    // Probably, the result should be handled somehow?
    // Like, if it's a failure, then we just output the error?
    // I don't know, but let's ignore it for now
    state := (^AppState)(appstate)

    wgpu.RenderPipelineRelease(state.render_pipeline)
    wgpu.PipelineLayoutRelease(state.pipeline_layout)
    wgpu.ShaderModuleRelease(state.shader_module)
    wgpu.QueueRelease(state.queue)
    wgpu.DeviceRelease(state.device)
    wgpu.AdapterRelease(state.adapter)
    wgpu.SurfaceRelease(state.surface)
    wgpu.InstanceRelease(state.instance)

    // Some comments say that `SDL_AppQuit` will call these functions for us
    // but I don't trust them, and I'm overprotective
    sdl.DestroyWindow(state.window)
    sdl.Quit()

    context = state.ctx
    log.destroy_console_logger(context.logger)

    // I don't know if I should clean it like this, but why not?
    state = nil
}

get_framebuffer_size :: proc(window: ^sdl.Window) -> (width, height: u32) {
    w, h: i32
    sdl.GetWindowSizeInPixels(window, &w, &h)
    return u32(w), u32(h)
}

resize :: proc "c" (state: ^AppState) {
    context = state.ctx

    width, height := get_framebuffer_size(state.window)
    state.surface_configuration.width = width
    state.surface_configuration.height = height

    wgpu.SurfaceConfigure(state.surface, &state.surface_configuration)
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
