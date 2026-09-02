package ui

import im "deps:imgui"

import "../fractal"
import "../geom"

MIN_POWER: f32 : 1.5
MAX_POWER: f32 : 6.0

MIN_JULIA: f32 : -1.5
MAX_JULIA: f32 : 1.5

draw_fractal_tab :: proc(view: ^Ui_View) {
    fractal_kind := view.fractal.kind
    if draw_enum_slider("Fractal", &fractal_kind) {
        view.fractal^ = fractal.init_fractal_state(
            fractal_kind,
            geom.Extent_2D {
                w = u32(view.fractal.base.resolution.x),
                h = u32(view.fractal.base.resolution.y),
            },
        )
    }

    max_iter := view.fractal.base.max_iter
    if im.SliderInt(
        "Iterations",
        &max_iter,
        fractal.FRACTAL_MIN_ITERATIONS,
        fractal.FRACTAL_MAX_ITERATIONS,
    ) {
        view.fractal.base.max_iter = clamp(
            max_iter,
            fractal.FRACTAL_MIN_ITERATIONS,
            fractal.FRACTAL_MAX_ITERATIONS,
        )
    }

    im.Separator()

    switch fractal_kind {
    case .Mandelbrot:
        draw_mandelbrot_tab(view)
    case .Julia:
        draw_julia_tab(view)
    case .Burning_Ship:
        draw_burning_ship_tab(view)
    case .Tricorn:
        draw_tricorn_tab(view)
    case .Celtic:
        draw_celtic_tab(view)
    case .Buffalo:
        draw_buffalo_tab(view)
    case .Cross:
        draw_cross_tab(view)
    case .Heart:
        draw_heart_tab(view)
    case .Perpendicular:
        draw_perpendicular_tab(view)
    }
}

@(private = "file")
draw_mandelbrot_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Mandelbrot_Data)
    if !ok {
        return
    }

    im.SliderFloat("Power", &data.power, MIN_POWER, MAX_POWER)
}

@(private = "file")
draw_julia_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Julia_Data)
    if !ok {
        return
    }

    constant_parts := transmute([2]f32)data.constant
    if im.SliderFloat2("Constant", &constant_parts, MIN_JULIA, MAX_JULIA) {
        data.constant = transmute(complex64)constant_parts
    }
}

@(private = "file")
draw_burning_ship_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Burning_Ship_Data)
    if !ok {
        return
    }

    im.SliderFloat("Power", &data.power, MIN_POWER, MAX_POWER)
}

@(private = "file")
draw_tricorn_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Tricorn_Data)
    if !ok {
        return
    }

    im.SliderFloat("Power", &data.power, MIN_POWER, MAX_POWER)
}

@(private = "file")
draw_celtic_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Celtic_Data)
    if !ok {
        return
    }

    im.SliderFloat("Power", &data.power, MIN_POWER, MAX_POWER)
}

@(private = "file")
draw_buffalo_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Buffalo_Data)
    if !ok {
        return
    }

    im.SliderFloat("Power", &data.power, MIN_POWER, MAX_POWER)
}

@(private = "file")
draw_cross_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Cross_Data)
    if !ok {
        return
    }

    im.SliderFloat("Power", &data.power, MIN_POWER, MAX_POWER)
}

@(private = "file")
draw_heart_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Heart_Data)
    if !ok {
        return
    }

    im.SliderFloat("Power", &data.power, MIN_POWER, MAX_POWER)
}

@(private = "file")
draw_perpendicular_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Perpendicular_Data)
    if !ok {
        return
    }

    im.SliderFloat("Power", &data.power, MIN_POWER, MAX_POWER)
}
