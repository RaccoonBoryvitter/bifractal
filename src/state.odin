package main

import "base:runtime"

import sdl "vendor:sdl3"
import mu "vendor:microui"

AppState :: struct {
    ctx: runtime.Context,

    window: ^sdl.Window,
    device: ^sdl.GPUDevice,

    compute_pipeline: ^sdl.GPUComputePipeline,
    texture: ^sdl.GPUTexture,
    
    uniform: FractalUniform,
    window_width: u32,
    window_height: u32,

    zoom_level: f32,
    is_dragging: bool,
    default_cursor: ^sdl.Cursor,
    move_cursor: ^sdl.Cursor,

    ui_context: mu.Context,
    ui_pipeline: ^sdl.GPUGraphicsPipeline,
    ui_vertex_buffer: ^sdl.GPUBuffer,
    ui_transfer_buffer: ^sdl.GPUTransferBuffer,
    ui_font_texture: ^sdl.GPUTexture,
    ui_font_sampler: ^sdl.GPUSampler,
}

FractalUniform :: struct {
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

PalettePreset :: struct {
    name:      string,
    a:         [3]f32,
    b:         [3]f32,
    c:         [3]f32,
    d:         [3]f32,
}

palette_presets := [?]PalettePreset{
    {
        name = "Electric",
        a = { 0.5, 0.5, 0.5 },
        b = { 0.5, 0.5, 0.5 },
        c = { 1.0, 1.0, 1.0 },
        d = { 0.0, 0.10, 0.20 },
    },
    {
        name = "Fire",
        a = { 0.5, 0.2, 0.1 },
        b = { 0.5, 0.4, 0.1 },
        c = { 1.0, 0.7, 0.4 },
        d = { 0.0, 0.15, 0.20 },
    },
    {
        name = "Ocean",
        a = { 0.2, 0.4, 0.6 },
        b = { 0.2, 0.3, 0.4 },
        c = { 1.0, 1.0, 1.0 },
        d = { 0.0, 0.10, 0.25 },
    },
    {
        name = "Grayscale",
        a = { 0.5, 0.5, 0.5 },
        b = { 0.5, 0.5, 0.5 },
        c = { 1.0, 1.0, 1.0 },
        d = { 0.0, 0.0, 0.0 },
    },
    {
        name = "Candy",
        a = { 0.5, 0.5, 0.5 },
        b = { 0.5, 0.5, 0.5 },
        c = { 1.0, 0.7, 0.4 },
        d = { 0.0, 0.15, 0.20 },
    },
    {
        name = "Sunset",
        a = { 0.8, 0.5, 0.4 },
        b = { 0.2, 0.4, 0.2 },
        c = { 2.0, 1.0, 1.0 },
        d = { 0.5, 0.25, 0.25 },
    },
    {
        name = "Neon",
        a = { 0.5, 0.5, 0.5 },
        b = { 0.5, 0.5, 0.5 },
        c = { 0.0, 0.33, 0.67 },
        d = { 0.0, 0.10, 0.20 },
    },
    {
        name = "Gold",
        a = { 0.5, 0.4, 0.1 },
        b = { 0.5, 0.3, 0.1 },
        c = { 1.0, 0.8, 0.3 },
        d = { 0.0, 0.10, 0.10 },
    },
}

apply_palette_preset :: proc(uniform: ^FractalUniform, preset: PalettePreset) {
    uniform.palette_a = preset.a
    uniform.palette_b = preset.b
    uniform.palette_c = preset.c
    uniform.palette_d = preset.d
}
