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

FractalState :: struct {
    uniform :        FractalUniform,
    zoom_level :     f32,
    is_dragging :    bool,
    default_cursor : ^sdl.Cursor,
    move_cursor :    ^sdl.Cursor,
}

PalettePreset :: struct {
    name : string,
    a :    [3]f32,
    b :    [3]f32,
    c :    [3]f32,
    d :    [3]f32,
}

UIVertex :: struct {
    position : [2]f32,
    uv :       [2]f32,
    color :    [4]f32,
}

UIGlobals :: struct {
    screen_size : [2]f32,
}

AppState :: struct {
    ctx :             runtime.Context,
    window :          ^sdl.Window,
    window_width :    u32,
    window_height :   u32,
    gpu :             GPUResources,
    fractal :         FractalState,
    ui_context :      mu.Context,
    fps_frame_count : u32,
    fps_last_ticks :  u64,
    fps_current :     f32,
}
