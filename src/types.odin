package main

import "core:log"
import "core:math/rand"
import "core:mem"

import "geom"
import "palette"

import im "deps:imgui"
import sdl "vendor:sdl3"

Vec2 :: geom.Vec2
Extent_2D :: geom.Extent_2D

Channel :: enum {
    Red,
    Green,
    Blue,
}

Window :: struct {
    handle: ^sdl.Window,
    size:   Extent_2D,
}

Gpu_Context :: struct {
    device:      ^sdl.GPUDevice,
    pipeline:    ^sdl.GPUComputePipeline,
    output:      ^sdl.GPUTexture,
    output_size: Extent_2D,
    name:        string,
    driver:      string,
    valid:       bool,
}

Palette :: palette.Palette
Palette_Preset         :: palette.Palette_Preset
Palette_State          :: palette.Palette_State
Palette_Color_Kind     :: palette.Palette_Color_Kind
apply_palette_preset   :: palette.apply_palette_preset
mirror_palette         :: palette.mirror_palette
rotate_palette         :: palette.rotate_palette
randomize_palette      :: palette.randomize_palette
cosine_palette_cpu     :: palette.cosine_palette_cpu
palette_create_samples :: palette.palette_create_samples
PALETTE_SWATCH_STEPS          :: palette.PALETTE_SWATCH_STEPS
PALETTE_PRESET_SWATCH_STEPS   :: palette.PALETTE_PRESET_SWATCH_STEPS
PALETTE_SWATCH_WIDTH          :: palette.PALETTE_SWATCH_WIDTH
PALETTE_PRESETS               :: palette.PALETTE_PRESETS

Fractal_View :: struct {
    center: [2]f32,
    zoom:   f32,
}

Fractal_Camera :: struct {
    view:        Fractal_View,
    is_dragging: bool,
    drag_start:  Vec2,
}

Fractal_Command :: enum {
    None,
    Pan,
    Zoom,
    Reset_View,
    Increase_Iter,
    Decrease_Iter,
    Drag_Start,
    Drag_End,
}

Fractal_Input :: struct {
    cmd:   Fractal_Command,
    pos:   Vec2,
    delta: Vec2,
}

Fractal_Params :: struct {
    max_iter:       i32,
    using palette:  Palette,
    interior_color: [4]f32,
    resolution:     [2]f32,
    power:          f32,
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

View_Reset :: struct {}
Max_Iter_Changed :: struct {
    value: i32,
}
Window_Resized :: struct {
    size: Extent_2D,
}
Palette_Banded_Changed :: struct {
    banded: bool,
}
Palette_Mirrored :: struct {}
Palette_Rotated :: struct {
    delta: f32,
}
Palette_Randomized :: struct {}
Palette_Preset_Applied :: struct {
    preset: Palette_Preset,
}
Palette_Color_Changed :: struct {
    kind:  Palette_Color_Kind,
    value: [4]f32,
}
Mandelbrot_Power_Changed :: struct {
    value: f32,
}
Interior_Color_Changed :: struct {
    value: [3]f32,
}

App_Event :: union {
    View_Reset,
    Max_Iter_Changed,
    Window_Resized,
    Palette_Banded_Changed,
    Palette_Mirrored,
    Palette_Rotated,
    Palette_Randomized,
    Palette_Preset_Applied,
    Palette_Color_Changed,
    Mandelbrot_Power_Changed,
    Interior_Color_Changed,
}

App_Events :: struct {
    queue: [dynamic]App_Event,
}

Frame_Pass :: enum {
    None,
    Compute,
    Blit,
    Ui,
}

Render_Context :: struct {
    cmd:     ^sdl.GPUCommandBuffer,
    scratch: mem.Arena,
    pass:    Frame_Pass,
}

Ui_State :: struct {
    ctx:              ^im.Context,
    mouse_complex:    complex64,
    selected_channel: Channel,
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
    events:  App_Events,
}
