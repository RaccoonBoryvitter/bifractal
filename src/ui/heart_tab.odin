package ui

import im "deps:imgui"

import "../events"
import "../fractal"

draw_heart_tab :: proc(view: ^Ui_View) {
    data, ok := &view.fractal.data.(fractal.Heart_Data)
    if !ok {
        return
    }

    power := data.power
    if im.SliderFloat("Power", &power, 1.5, 6.0) {
        append(&view.events.queue, events.Heart_Power_Changed{value = power})
    }
}
