package ui

import im "deps:imgui"

import "../events"
import "../fractal"

draw_fractal_tab :: proc(view: ^Ui_View) {
    fractal_kind := view.fractal.kind
    if draw_enum_slider("Fractal", &fractal_kind) {
        append(
            &view.events.queue,
            events.Fractal_Kind_Changed{value = fractal_kind},
        )
    }

    max_iter := view.fractal.base.max_iter
    if im.SliderInt(
        "Iterations",
        &max_iter,
        fractal.FRACTAL_MIN_ITERATIONS,
        fractal.FRACTAL_MAX_ITERATIONS,
    ) {
        append(&view.events.queue, events.Max_Iter_Changed{value = max_iter})
    }

    im.Separator()

    if fractal_kind == .Mandelbrot {
        draw_mandelbrot_tab(view)
    }

    if fractal_kind == .Julia {
        draw_julia_tab(view)
    }

    if fractal_kind == .Burning_Ship {
        draw_burning_ship_tab(view)
    }

    if fractal_kind == .Tricorn {
        draw_tricorn_tab(view)
    }

    if fractal_kind == .Celtic {
        draw_celtic_tab(view)
    }

    if fractal_kind == .Buffalo {
        draw_buffalo_tab(view)
    }

    if fractal_kind == .Cross {
        draw_cross_tab(view)
    }

    if fractal_kind == .Heart {
        draw_heart_tab(view)
    }
}
