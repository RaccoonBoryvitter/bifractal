package ui

import im "deps:imgui"

import "../events"
import "../fractal"

draw_perpendicular_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Perpendicular_Data)
    if !ok {
        return
    }

    power := data.power
    if im.SliderFloat("Power", &power, 1.5, 6.0) {
        append(
            &view.events.queue,
            events.Perpendicular_Power_Changed{value = power},
        )
    }
}
