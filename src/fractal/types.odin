package fractal

import "../geom"
import "../palette"

Fractal_Kind :: enum {
    Mandelbrot,
}

Fractal_View :: struct {
    center: [2]f32,
    zoom:   f32,
}

Fractal_Camera :: struct {
    view:        Fractal_View,
    is_dragging: bool,
    drag_start:  geom.Vec2,
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
    pos:   geom.Vec2,
    delta: geom.Vec2,
}

Fractal_Base :: struct {
    camera:         Fractal_Camera,
    max_iter:       i32,
    palette:        palette.Palette,
    interior_color: [4]f32,
    resolution:     [2]f32,
    zoom_level:     f32,
}

Mandelbrot_Data :: struct {
    power: f32,
}

Fractal_Data :: union {
    Mandelbrot_Data,
}

Fractal :: struct {
    kind: Fractal_Kind,
    base: Fractal_Base,
    data: Fractal_Data,
}
