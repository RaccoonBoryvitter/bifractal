package ui

import "core:fmt"

import im "deps:imgui"

import "../events"

draw_view_tab :: proc(view: ^Ui_View) {
    im.Text(
        fmt.ctprintf(
            "Zoom: %s",
            format_zoom(view.fractal.base.camera.view.zoom),
        ),
    )
    im.Text(
        fmt.ctprintf(
            "Center: %s",
            format_coord(
                view.fractal.base.camera.view.center,
                view.settings.hud.coord_format,
            ),
        ),
    )
    im.Text(
        fmt.ctprintf(
            "Mouse: %s",
            format_coord(
                {
                    real(view.ui_state.mouse_complex),
                    imag(view.ui_state.mouse_complex),
                },
                view.settings.hud.coord_format,
            ),
        ),
    )

    im.Spacing()

    if im.Button("Reset View") {
        append(&view.events.queue, events.View_Reset{})
    }
    im.SameLine()
    if im.Button("Save Image (Ctrl+S)") {
        append(&view.events.queue, events.Image_Save_Requested{})
    }
}
