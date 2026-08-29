package ui

import im "deps:imgui"

import "../events"
import "../fractal"

draw_buffalo_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Buffalo_Data)
    if !ok {
        return
    }

    power := data.power
    if im.SliderFloat("Power", &power, 1.5, 6.0) {
        append(&view.events.queue, events.Buffalo_Power_Changed{value = power})
    }
}
