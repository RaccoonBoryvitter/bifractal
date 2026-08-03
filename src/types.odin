package main

import "core:log"
import "core:math/rand"
import "core:mem"

import "geom"
import "palette"
import "events"
import "platform"

import im "deps:imgui"
import sdl "vendor:sdl3"

Vec2 :: geom.Vec2
Extent_2D :: geom.Extent_2D

Channel :: enum {
    Red,
    Green,
    Blue,
}

Window                    :: platform.Window
Gpu_Context               :: platform.Gpu_Context
init_window               :: platform.init_window
init_gpu                  :: platform.init_gpu
create_compute_pipeline   :: platform.create_compute_pipeline
resize_gpu_output         :: platform.resize_gpu_output
sdl_log_callback          :: platform.sdl_log_callback
WINDOW_TITLE              :: platform.WINDOW_TITLE
WINDOW_RESOLUTION         :: platform.WINDOW_RESOLUTION
SHADER_FORMAT             :: platform.SHADER_FORMAT

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

View_Reset                  :: events.View_Reset
Max_Iter_Changed            :: events.Max_Iter_Changed
Window_Resized              :: events.Window_Resized
Palette_Banded_Changed      :: events.Palette_Banded_Changed
Palette_Mirrored            :: events.Palette_Mirrored
Palette_Rotated             :: events.Palette_Rotated
Palette_Randomized          :: events.Palette_Randomized
Palette_Preset_Applied      :: events.Palette_Preset_Applied
Palette_Color_Changed       :: events.Palette_Color_Changed
Mandelbrot_Power_Changed    :: events.Mandelbrot_Power_Changed
Interior_Color_Changed      :: events.Interior_Color_Changed
App_Event                   :: events.App_Event
App_Events                  :: events.App_Events

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
