package app

import "core:log"
import "core:math/rand"
import "core:strings"

import im "deps:imgui"
import im_sdl "deps:imgui/imgui_impl_sdl3"
import im_sdlgpu "deps:imgui/imgui_impl_sdlgpu3"
import sdl "vendor:sdl3"

import "../events"
import "../fractal"
import "../geom"
import "../palette"
import "../platform"
import "../settings"
import "../ui"

App_Context :: struct {
    window:         platform.Window,
    logger:         log.Logger,
    gpu:            platform.Gpu_Context,
    fractal:        fractal.Fractal,
    palette:        palette.Palette_State,
    ui:             ui.Ui_State,
    time:           Time,
    events:         events.App_Events,
    settings:       settings.Settings,
    settings_dirty: bool,
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
        case events.View_Reset:
            fractal.reset_fractal_view(&state.fractal.base)
        case events.Max_Iter_Changed:
            state.fractal.base.max_iter = clamp(
                e.value,
                fractal.FRACTAL_MIN_ITERATIONS,
                fractal.FRACTAL_MAX_ITERATIONS,
            )
        case events.Window_Resized:
            state.window.size = e.size
            state.window.pixel_scale = platform.compute_pixel_scale(
                state.window.handle,
            )
            state.fractal.base.resolution = {f32(e.size.w), f32(e.size.h)}
            if platform.resize_gpu_output(&state.gpu, e.size) == nil {
                state.gpu.valid = false
            }
        case events.Palette_Banded_Changed:
            state.palette.banded = e.banded
        case events.Palette_Mirrored:
            palette.mirror_palette(&state.fractal.base.palette)
        case events.Palette_Rotated:
            palette.rotate_palette(&state.fractal.base.palette, e.delta)
        case events.Palette_Randomized:
            palette.randomize_palette(
                &state.fractal.base.palette,
                rand.default_random_generator(&state.palette.rand_state),
            )
        case events.Palette_Preset_Applied:
            palette.apply_palette_preset(&state.fractal.base.palette, e.preset)
        case events.Palette_Color_Changed:
            switch e.kind {
            case .Offset:
                state.fractal.base.palette.offset = e.value
            case .Amplitude:
                state.fractal.base.palette.amplitude = e.value
            case .Frequency:
                state.fractal.base.palette.frequency = e.value
            case .Phase:
                state.fractal.base.palette.phase = e.value
            }
        case events.Interior_Color_Changed:
            state.fractal.base.interior_color = {
                e.value.r,
                e.value.g,
                e.value.b,
                1.0,
            }
        case events.Fractal_Kind_Changed:
            state.fractal = fractal.init_fractal_state(
                e.value,
                geom.Extent_2D {
                    w = u32(state.fractal.base.resolution.x),
                    h = u32(state.fractal.base.resolution.y),
                },
            )
        case events.Mandelbrot_Power_Changed:
            #partial switch d in state.fractal.data {
            case fractal.Mandelbrot_Data:
                state.fractal.data = fractal.Mandelbrot_Data {
                    power = e.value,
                }
            }
        case events.Julia_Constant_Changed:
            #partial switch d in state.fractal.data {
            case fractal.Julia_Data:
                state.fractal.data = fractal.Julia_Data {
                    constant = e.value,
                }
            }
        case events.Settings_Reset:
            state.settings = settings.default_settings()
            state.settings_dirty = true
        }
    }
    clear(&state.events.queue)
}

sync_drag_cursor :: proc(state: ^App_Context) {
    target: ^sdl.Cursor
    if state.fractal.base.camera.is_dragging {
        target = state.window.move_cursor
    }
     else {
        target = state.window.default_cursor
    }
    if target == nil {
        return
    }
    if !sdl.SetCursor(target) {
        log.errorf("unable to set cursor: %s", sdl.GetError())
    }
}

init_app :: proc() -> ^App_Context {
    state := new(App_Context)
    state.logger = create_app_logger()
    context.logger = state.logger

    state.events.queue = make([dynamic]events.App_Event)

    sdl.SetLogOutputFunction(platform.sdl_log_callback, &state.logger)
    when ODIN_DEBUG {
        sdl.SetLogPriorities(.DEBUG)
    } else {
        sdl.SetLogPriorities(.INFO)
    }

    ok := true
    defer if !ok { destroy_app(state) }

    state.window = platform.init_window()^
    if state.window.handle == nil {
        ok = false
        return nil
    }

    sdl.GetWindowSizeInPixels(
        state.window.handle,
        (^i32)(&state.window.size.w),
        (^i32)(&state.window.size.h),
    )
    state.window.pixel_scale = platform.compute_pixel_scale(
        state.window.handle,
    )

    state.gpu.device = platform.init_gpu(state.window.handle)
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

    state.gpu.pipelines = platform.create_compute_pipelines(state.gpu.device)
    if state.gpu.pipelines == nil || len(state.gpu.pipelines) == 0 {
        ok = false
        return nil
    }

    if platform.resize_gpu_output(&state.gpu, state.window.size) == nil {
        ok = false
        return nil
    }

    state.gpu.valid = true

    state.fractal = fractal.init_fractal_state(.Mandelbrot, state.window.size)

    state.palette.rand_state = rand.create_u64(42)
    state.time.last_ticks = sdl.GetTicks()

    settings.init()
    state.settings, _ = settings.load()

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

destroy_app :: proc(state: ^App_Context) {
    if state == nil {
        return
    }

    if state.ui.ctx != nil {
        im_sdlgpu.Shutdown()
        im_sdl.Shutdown()
        im.DestroyContext(state.ui.ctx)
    }

    if state.window.move_cursor != nil {
        sdl.DestroyCursor(state.window.move_cursor)
    }
    if state.window.default_cursor != nil {
        sdl.DestroyCursor(state.window.default_cursor)
    }

    if state.gpu.output != nil && state.gpu.device != nil {
        sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.output)
    }
    if state.gpu.pipelines != nil && state.gpu.device != nil {
        for _, pipeline in state.gpu.pipelines {
            sdl.ReleaseGPUComputePipeline(state.gpu.device, pipeline)
        }
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

    if state.settings_dirty {
        settings.save(state.settings)
    }

    if state.logger.procedure != nil {
        log.destroy_console_logger(state.logger)
    }
    free(state)
}
