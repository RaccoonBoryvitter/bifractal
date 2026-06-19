package main

import "base:runtime"

import mu "vendor:microui"
import sdl "vendor:sdl3"

GPUResources :: struct {
    device :             ^sdl.GPUDevice,
    compute_pipeline :   ^sdl.GPUComputePipeline,
    texture :            ^sdl.GPUTexture,
    ui_pipeline :        ^sdl.GPUGraphicsPipeline,
    ui_vertex_buffer :   ^sdl.GPUBuffer,
    ui_transfer_buffer : ^sdl.GPUTransferBuffer,
    ui_font_texture :    ^sdl.GPUTexture,
    ui_font_sampler :    ^sdl.GPUSampler,
}

FractalState :: struct {
    uniform :        FractalUniform,
    zoom_level :     f32,
    is_dragging :    bool,
    default_cursor : ^sdl.Cursor,
    move_cursor :    ^sdl.Cursor,
}

AppState :: struct {
    ctx :           runtime.Context,
    window :        ^sdl.Window,
    window_width :  u32,
    window_height : u32,
    gpu :           GPUResources,
    fractal :       FractalState,
    ui_context :    mu.Context,
}

FractalUniform :: struct {
    center :     [2]f32,
    zoom :       f32,
    max_iter :   i32,
    palette_a :  [3]f32,
    _pad_a :     f32,
    palette_b :  [3]f32,
    _pad_b :     f32,
    palette_c :  [3]f32,
    _pad_c :     f32,
    palette_d :  [3]f32,
    _pad_d :     f32,
    resolution : [2]f32,
}
