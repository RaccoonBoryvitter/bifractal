package ui

import "core:fmt"

import im "deps:imgui"

import "../events"
import "../settings"

draw_settings_tab :: proc(view: ^Ui_View) {
    s := &view.settings

    if im.CollapsingHeader("HUD", {.DefaultOpen}) {
        if im.Checkbox("Enabled", &s.hud.enabled) do view.settings_changed = true

        im.BeginDisabled(!s.hud.enabled)
        defer im.EndDisabled()

        if im.Checkbox("Show background", &s.hud.show_background) do view.settings_changed = true
        if im.Checkbox("Click-through", &s.hud.click_through) do view.settings_changed = true

        if im.SliderFloat("Opacity", &s.hud.opacity, 0.2, 1.0, "%.2f") {
            view.settings_changed = true
        }
        if im.SliderFloat("Padding", &s.hud.padding, 0, 64, "%.0f px") {
            view.settings_changed = true
        }

        anchor := s.hud.anchor
        if im.BeginCombo("Anchor", fmt.ctprintf("%s", anchor)) {
            for a in settings.Hud_Anchor {
                selected := a == anchor
                if im.Selectable(fmt.ctprintf("%s", a), selected) {
                    s.hud.anchor = a
                    view.settings_changed = true
                }
                if selected do im.SetItemDefaultFocus()
            }
            im.EndCombo()
        }

        im.SeparatorText("Fields")
        if im.Checkbox("FPS", &s.hud.show_fps) do view.settings_changed = true
        if im.Checkbox("Frame time", &s.hud.show_frame_ms) do view.settings_changed = true
        if im.Checkbox("Fractal", &s.hud.show_fractal_kind) do view.settings_changed = true
        if im.Checkbox("Fractal params", &s.hud.show_fractal_params) do view.settings_changed = true
        if im.Checkbox("Center", &s.hud.show_center) do view.settings_changed = true
        if im.Checkbox("Zoom", &s.hud.show_zoom) do view.settings_changed = true
        if im.Checkbox("Iterations", &s.hud.show_iter) do view.settings_changed = true
        if im.Checkbox("Mouse coords", &s.hud.show_mouse) do view.settings_changed = true
        if im.Checkbox("Resolution", &s.hud.show_resolution) do view.settings_changed = true
        if im.Checkbox("Palette name", &s.hud.show_palette) do view.settings_changed = true

        im.SeparatorText("Coordinate format")
        cf := s.hud.coord_format
        for f in settings.Coord_Format {
            selected := f == cf
            if im.RadioButton(fmt.ctprintf("%s", f), selected) {
                s.hud.coord_format = f
                view.settings_changed = true
            }
            if f != .Fraction do im.SameLine()
        }
    }

    im.Separator()

    if im.Button("Reset to defaults") {
        append(&view.events.queue, events.Settings_Reset{})
    }
    im.SameLine()
    if im.Button("Save") {
        view.settings_changed = true
        view.settings_save = true
    }
}
