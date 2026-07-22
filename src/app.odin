package main

import "core:log"
import "core:math/rand"
import "core:strings"

import im "deps:imgui"
import im_sdl "deps:imgui/imgui_impl_sdl3"
import im_sdlgpu "deps:imgui/imgui_impl_sdlgpu3"
import sdl "vendor:sdl3"

init_window :: proc() -> ^sdl.Window {
    ok := sdl.Init({.VIDEO, .EVENTS})
    if !ok {
        log.errorf("unable to initialize SDL: %s", sdl.GetError())
        return nil
    }

    main_scale := sdl.GetDisplayContentScale(sdl.GetPrimaryDisplay())
    window := sdl.CreateWindow(
        WINDOW_TITLE,
        i32(f32(WINDOW_RESOLUTION.w) * main_scale), // I will eventually come up
        i32(f32(WINDOW_RESOLUTION.h) * main_scale), // with a better solution
        {.RESIZABLE, .HIGH_PIXEL_DENSITY},
    )
    if window == nil {
        log.errorf("unable to create SDL window: %s", sdl.GetError())
        sdl.Quit()
        return nil
    }

    sdl.SetWindowPosition(
        window,
        sdl.WINDOWPOS_CENTERED,
        sdl.WINDOWPOS_CENTERED,
    )

    return window
}

init_gpu :: proc(window: ^sdl.Window) -> ^sdl.GPUDevice {
    gpu_device := sdl.CreateGPUDevice({.SPIRV, .DXIL, .MSL}, true, nil)
    if gpu_device == nil {
        log.errorf("unable to create SDL GPU device: %s", sdl.GetError())
        return nil
    }

    ok := sdl.ClaimWindowForGPUDevice(gpu_device, window)
    if !ok {
        log.errorf("unable to claim window for GPU device: %s", sdl.GetError())
        sdl.DestroyGPUDevice(gpu_device)
        return nil
    }

    ok = sdl.SetGPUSwapchainParameters(gpu_device, window, .SDR, .VSYNC)
    if !ok {
        log.warnf("unable to set swapchain parameters: %s", sdl.GetError())
    }

    ok = sdl.SetGPUAllowedFramesInFlight(gpu_device, 2)
    if !ok {
        log.warnf("unable to set frames in flight: %s", sdl.GetError())
    }

    return gpu_device
}

create_app_logger :: proc() -> log.Logger {
    when ODIN_DEBUG {
        return log.create_console_logger(.Debug)
    } else {
        return log.create_console_logger(.Info)
    }
}

app_dispatch_events :: proc(state: ^App_Context) {
    for event in state.events.queue {
        switch e in event {
        case View_Reset:
            reset_fractal_view(
                &state.fractal.camera.view,
                &state.fractal.params,
                &state.fractal.zoom_level,
            )
        case Max_Iter_Changed:
            state.fractal.params.max_iter = clamp(
                e.value,
                FRACTAL_MIN_ITERATIONS,
                FRACTAL_MAX_ITERATIONS,
            )
        case Window_Resized:
            state.window.size = e.size
            state.fractal.params.resolution = {f32(e.size.w), f32(e.size.h)}
            if resize_gpu_output(&state.gpu, e.size) == nil {
                state.gpu.valid = false
            }
        case Palette_Banded_Changed:
            state.palette.banded = e.banded
        case Palette_Mirrored:
            mirror_palette(&state.fractal.params.palette)
        case Palette_Rotated:
            rotate_palette(&state.fractal.params.palette, e.delta)
        case Palette_Randomized:
            randomize_palette(
                &state.fractal.params.palette,
                rand.default_random_generator(&state.palette.rand_state),
            )
        case Palette_Preset_Applied:
            apply_palette_preset(&state.fractal.params.palette, e.preset)
        case Palette_Color_Changed:
            switch e.kind {
            case .Offset:
                state.fractal.params.palette.offset = e.value
            case .Amplitude:
                state.fractal.params.palette.amplitude = e.value
            case .Frequency:
                state.fractal.params.palette.frequency = e.value
            case .Phase:
                state.fractal.params.palette.phase = e.value
            }
        case Mandelbrot_Power_Changed:
            state.fractal.params.power = e.value
        }
    }
    clear(&state.events.queue)
}

destroy_app :: proc(state: ^App_Context) {
    if state == nil {
        return
    }

    if state.ui.ctx != nil {
        im_sdlgpu.Shutdown()
        im_sdl.Shutdown()
        im.DestroyContext(state.ui.ctx)
    }

    if state.fractal.move_cursor != nil {
        sdl.DestroyCursor(state.fractal.move_cursor)
    }
    if state.fractal.default_cursor != nil {
        sdl.DestroyCursor(state.fractal.default_cursor)
    }

    if state.gpu.output != nil && state.gpu.device != nil {
        sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.output)
    }
    if state.gpu.pipeline != nil && state.gpu.device != nil {
        sdl.ReleaseGPUComputePipeline(state.gpu.device, state.gpu.pipeline)
    }

    if state.gpu.device != nil {
        sdl.DestroyGPUDevice(state.gpu.device)
    }
    if state.window.handle != nil {
        sdl.DestroyWindow(state.window.handle)
    }

    sdl.SetLogOutputFunction(sdl.GetDefaultLogOutputFunction(), nil)
    sdl.Quit()

    delete(state.gpu.name)
    delete(state.gpu.driver)
    delete(state.events.queue)

    if state.logger.procedure != nil {
        log.destroy_console_logger(state.logger)
    }
    free(state)
}

init_app :: proc() -> ^App_Context {
    state := new(App_Context)
    state.logger = create_app_logger()
    context.logger = state.logger

    state.events.queue = make([dynamic]App_Event)

    sdl.SetLogOutputFunction(sdl_log_callback, &state.logger)
    when ODIN_DEBUG {
        sdl.SetLogPriorities(.DEBUG)
    } else {
        sdl.SetLogPriorities(.INFO)
    }

    ok := true
    defer if !ok { destroy_app(state) }

    state.window.handle = init_window()
    if state.window.handle == nil {
        ok = false
        return nil
    }

    sdl.GetWindowSizeInPixels(
        state.window.handle,
        (^i32)(&state.window.size.w),
        (^i32)(&state.window.size.h),
    )

    state.gpu.device = init_gpu(state.window.handle)
    if state.gpu.device == nil {
        ok = false
        return nil
    }

    gpu_props := sdl.GetGPUDeviceProperties(state.gpu.device)
    state.gpu.name = strings.clone(
        string(
            sdl.GetStringProperty(
                gpu_props,
                sdl.PROP_GPU_DEVICE_NAME_STRING,
                "Unknown",
            ),
        ),
    )
    state.gpu.driver = strings.clone(
        string(sdl.GetGPUDeviceDriver(state.gpu.device)),
    )

    state.gpu.pipeline = create_compute_pipeline(state.gpu.device)
    if state.gpu.pipeline == nil {
        ok = false
        return nil
    }

    if resize_gpu_output(&state.gpu, state.window.size) == nil {
        ok = false
        return nil
    }

    state.gpu.valid = true

    state.fractal = init_fractal_state(state.window.size)

    state.palette.rand_state = rand.create_u64(42)
    state.time.last_ticks = sdl.GetTicks()

    im.CHECKVERSION()
    state.ui.ctx = im.CreateContext()
    state.ui.selected_channel = .Red
    imgui_io := im.GetIOImGuiContextPtr(state.ui.ctx)
    imgui_io.ConfigFlags += {.NavEnableKeyboard, .DockingEnable}

    system_theme := sdl.GetSystemTheme()
    switch system_theme {
    case .UNKNOWN:
        im.StyleColorsClassic()
    case .DARK:
        im.StyleColorsDark()
    case .LIGHT:
        im.StyleColorsLight()
    }

    imgui_style := im.GetStyle()
    main_scale := sdl.GetDisplayContentScale(sdl.GetPrimaryDisplay())
    im.Style_ScaleAllSizes(imgui_style, main_scale)
    imgui_style.FontScaleDpi = main_scale
    imgui_io.ConfigDpiScaleFonts = true

    im_sdl.InitForSDLGPU(state.window.handle)

    init_info := im_sdlgpu.InitInfo {
        Device               = state.gpu.device,
        ColorTargetFormat    = sdl.GetGPUSwapchainTextureFormat(
            state.gpu.device,
            state.window.handle,
        ),
        MSAASamples          = ._1,
        SwapchainComposition = .SDR,
        PresentMode          = .VSYNC,
    }
    im_sdlgpu.Init(&init_info)

    return state
}
