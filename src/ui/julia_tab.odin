package ui

import im "deps:imgui"

import "../events"
import "../fractal"

draw_julia_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Julia_Data)
    if !ok {
        return
    }

    constant_parts := transmute([2]f32)data.constant
    if im.SliderFloat2("Constant", &constant_parts, -1.5, 1.5) {
        new_constant := transmute(complex64)constant_parts
        append(
            &view.events.queue,
            events.Julia_Constant_Changed{value = new_constant}
        )
    }
}