package ui

import im "deps:imgui"

import "../events"
import "../fractal"

draw_mandelbrot_tab :: proc(view: ^Ui_View, data: ^fractal.Mandelbrot_Data) {
    power := data.power
    if im.SliderFloat("Power", &power, 1.5, 6.0) {
        append(
            &view.events.queue,
            events.Mandelbrot_Power_Changed{value = power},
        )
    }
}
