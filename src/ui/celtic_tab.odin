package ui

import im "deps:imgui"

import "../events"
import "../fractal"

draw_celtic_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Celtic_Data)
    if !ok {
        return
    }

    power := data.power
    if im.SliderFloat("Power", &power, 1.5, 6.0) {
        append(&view.events.queue, events.Celtic_Power_Changed{value = power})
    }
}
