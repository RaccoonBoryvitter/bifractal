package main

import "base:runtime"

import mu "vendor:microui"
import sdl "vendor:sdl3"

AppState :: struct {
    ctx :           runtime.Context,
    window :        ^sdl.Window,
    window_width :  u32,
    window_height : u32,
    gpu :           GPUResources,
    fractal :       FractalState,
    ui_context :    mu.Context,

    fps_frame_count: u32,
    fps_last_ticks:  u64,
    fps_current:     f32,
}
