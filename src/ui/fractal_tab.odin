package ui

import im "deps:imgui"

import "../events"
import "../fractal"

draw_fractal_tab :: proc(view: ^Ui_View) {
    max_iter := view.fractal.base.max_iter
    if im.SliderInt(
        "Iterations",
        &max_iter,
        fractal.FRACTAL_MIN_ITERATIONS,
        fractal.FRACTAL_MAX_ITERATIONS,
    ) {
        append(&view.events.queue, events.Max_Iter_Changed{value = max_iter})
    }

    if d, ok := &view.fractal.data.(fractal.Mandelbrot_Data); ok {
        draw_mandelbrot_tab(view, d)
    }
}
