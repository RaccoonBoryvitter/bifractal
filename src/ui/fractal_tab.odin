package ui

import im "deps:imgui"

import "../events"
import "../fractal"

draw_fractal_tab :: proc(view: ^Ui_View) {
    fractal_kind := view.fractal.kind
    if im.RadioButton("Mandelbrot##kind", fractal_kind == .Mandelbrot) {
        append(
            &view.events.queue,
            events.Fractal_Kind_Changed{value = .Mandelbrot}
        )
    }

    im.SameLine()
    if im.RadioButton("Julia##kind", fractal_kind == .Julia) {
        append(
            &view.events.queue,
            events.Fractal_Kind_Changed{value = .Julia}
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
}
