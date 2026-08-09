package ui

import im "deps:imgui"

import "../events"
import "../fractal"
import "../geom"
import "../palette"
import "../settings"

Channel :: enum {
    Red,
    Green,
    Blue,
}

Ui_State :: struct {
    ctx:              ^im.Context,
    mouse_complex:    complex64,
    selected_channel: Channel,
}

Ui_View :: struct {
    ui_state:         ^Ui_State,
    fractal:          ^fractal.Fractal,
    palette_state:    ^palette.Palette_State,
    events:           ^events.App_Events,
    settings:         settings.Settings,
    settings_changed: bool,
    settings_save:    bool,
    window_size:      geom.Extent_2D,
    pixel_scale:      geom.Vec2,
    gpu_name:         string,
    gpu_driver:       string,
    fps:              f32,
    frame_time_ms:    f32,
}
