package main

import "base:runtime"
import "core:log"

import sdl "vendor:sdl3"

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
        {.RESIZABLE, .HIGH_PIXEL_DENSITY},
    )
    if window == nil {
        log.errorf("unable to create SDL window: %s", sdl.GetError())
        return nil
    }

    return window
}

init_gpu :: proc(window : ^sdl.Window) -> ^sdl.GPUDevice {
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

init_app :: proc(ctx : runtime.Context) -> ^AppState {
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

    state.fps_last_ticks = sdl.GetTicks()

    return state
}
