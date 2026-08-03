package ui

import "core:fmt"

import im "deps:imgui"
import sdl "vendor:sdl3"

import "../events"
import "../fractal"

draw_view_tab :: proc(view: ^Ui_View) {
    im.Text(
        fmt.ctprintf(
            "Zoom: %s",
            format_zoom(view.fractal.base.camera.view.zoom),
        ),
    )
    im.Text(
        fmt.ctprintf(
            "Center: %+.6f %+.6fi",
            view.fractal.base.camera.view.center.x,
            view.fractal.base.camera.view.center.y,
        ),
    )

    mouse_x, mouse_y: f32
    _ = sdl.GetMouseState(&mouse_x, &mouse_y)
    view.ui_state.mouse_complex = fractal.view_screen_to_complex(
        {mouse_x * view.pixel_scale.x, mouse_y * view.pixel_scale.y},
        view.window_size,
        view.fractal.base.camera.view,
    )
    im.Text(
        fmt.ctprintf(
            "Mouse: %+.6f %+.6fi",
            real(view.ui_state.mouse_complex),
            imag(view.ui_state.mouse_complex),
        ),
    )

    if im.Button("Reset View") {
        append(&view.events.queue, events.View_Reset{})
    }
}
