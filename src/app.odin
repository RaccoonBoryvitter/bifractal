package main

import "base:runtime"
import "core:log"
import "core:math/rand"

import imgui "deps:imgui"
import imgui_impl_sdl3 "deps:imgui/imgui_impl_sdl3"
import imgui_impl_sdlgpu3 "deps:imgui/imgui_impl_sdlgpu3"
import mu "vendor:microui"
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
        return nil
    }

    return gpu_device
}

init_app :: proc(ctx: runtime.Context) -> ^App_State {
    context = ctx

    state := new(App_State)
    state.ctx = context
    context.logger = log.create_console_logger()

    state.window = init_window()
    if state.window == nil {
        return nil
    }

    sdl.GetWindowSizeInPixels(
        state.window,
        (^i32)(&state.window_resolution.w),
        (^i32)(&state.window_resolution.h),
    )

    state.gpu.device = init_gpu(state.window)
    if state.gpu.device == nil {
        return nil
    }

    gpu_props := sdl.GetGPUDeviceProperties(state.gpu.device)
    state.gpu_name = string(
        sdl.GetStringProperty(
            gpu_props,
            sdl.PROP_GPU_DEVICE_NAME_STRING,
            "Unknown",
        ),
    )
    state.gpu_driver = string(sdl.GetGPUDeviceDriver(state.gpu.device))

    pipeline, texture, ok := init_fractal_compute(
        state.gpu.device,
        state.window_resolution,
    )
    if !ok {
        return nil
    }
    state.gpu.compute_pipeline = pipeline
    state.gpu.texture = texture

    state.fractal = init_fractal_state(state.window_resolution)

    if !init_ui_pipeline(state) {
        return nil
    }

    init_ui_resources(state)

    compute_texel_size: u64 = 16
    compute_texture_size :=
        u64(state.window_resolution.w) *
        u64(state.window_resolution.h) *
        compute_texel_size

    ui_texel_size: u64 = 4
    ui_texture_size :=
        u64(mu.DEFAULT_ATLAS_WIDTH) *
        u64(mu.DEFAULT_ATLAS_HEIGHT) *
        ui_texel_size

    ui_buffer_size := u64(MAX_UI_VERTICES) * u64(size_of(Ui_Vertex))

    state.gpu_vram_bytes =
        compute_texture_size +
        ui_texture_size +
        ui_buffer_size +
        ui_buffer_size // vertex buffer// transfer buffer

    state.rand_state = rand.create_u64(42)
    state.fps_last_ticks = sdl.GetTicks()

    imgui.CHECKVERSION()
    state.imgui = { }
    state.imgui.ctx = imgui.CreateContext()
    imgui_io := imgui.GetIOImGuiContextPtr(state.imgui.ctx)
    imgui_io.ConfigFlags += {
        .NavEnableKeyboard,
        .DockingEnable,
        .ViewportsEnable,
    }

    system_theme := sdl.GetSystemTheme()
    switch system_theme {
    case .UNKNOWN:
        imgui.StyleColorsClassic()
    case .DARK:
        imgui.StyleColorsDark()
    case .LIGHT:
        imgui.StyleColorsLight()
    }

    imgui_style := imgui.GetStyle()
    main_scale := sdl.GetDisplayContentScale(sdl.GetPrimaryDisplay())
    imgui.Style_ScaleAllSizes(imgui_style, main_scale)
    imgui_style.FontScaleDpi = main_scale
    imgui_io.ConfigDpiScaleFonts = true
    imgui_io.ConfigDpiScaleViewports = true

    if .ViewportsEnable in imgui_io.ConfigFlags {
        imgui_style.WindowRounding = 0
        imgui_style.Colors[imgui.Col.WindowBg].w = 1
    }

    imgui_impl_sdl3.InitForSDLGPU(state.window)

    init_info := imgui_impl_sdlgpu3.InitInfo {
        Device               = state.gpu.device,
        ColorTargetFormat    = sdl.GetGPUSwapchainTextureFormat(
            state.gpu.device,
            state.window,
        ),
        MSAASamples          = ._1,
        SwapchainComposition = .SDR,
        PresentMode          = .VSYNC,
    }
    imgui_impl_sdlgpu3.Init(&init_info)

    return state
}
