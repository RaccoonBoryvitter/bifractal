package main

import "base:runtime"

import "core:log"
import "core:math/rand"

import im "deps:imgui"
import sdl "vendor:sdl3"

Extent_2D :: struct {
    w, h: u32,
}

Window :: struct {
    handle: ^sdl.Window,
    size:   Extent_2D,
}

Gpu_Context :: struct {
    device:           ^sdl.GPUDevice,
    compute_pipeline: ^sdl.GPUComputePipeline,
    texture:          ^sdl.GPUTexture,
    name:             string,
    driver:           string,
}

Palette :: struct {
    offset:    [4]f32,
    amplitude: [4]f32,
    frequency: [4]f32,
    phase:     [4]f32,
}

Fractal_View :: struct {
    center: [2]f32,
    zoom:   f32,
}

Fractal_Camera :: struct {
    view:        Fractal_View,
    is_dragging: bool,
    drag_start:  [2]f32,
}

Fractal_Params :: struct {
    max_iter:      i32,
    using palette: Palette,
    resolution:    [2]f32,
}

Fractal_Uniform :: struct {
    center:       [2]f32,
    zoom:         f32,
    using params: Fractal_Params,
}

Fractal :: struct {
    camera:         Fractal_Camera,
    params:         Fractal_Params,
    zoom_level:     f32,
    default_cursor: ^sdl.Cursor,
    move_cursor:    ^sdl.Cursor,
}

Palette_Preset :: struct {
    name:          string,
    using palette: Palette,
}

Palette_State :: struct {
    banded:     bool,
    snapshot:   Maybe(Palette_Preset),
    rand_state: rand.Default_Random_State,
}

Ui_State :: struct {
    ctx:           ^im.Context,
    mouse_complex: complex64,
}

Time :: struct {
    frame_count: u32,
    last_ticks:  u64,
    current:     f32,
}

App_Context :: struct {
    window:  Window,
    logger:  log.Logger,
    gpu:     Gpu_Context,
    fractal: Fractal,
    palette: Palette_State,
    ui:      Ui_State,
    time:    Time,
}
