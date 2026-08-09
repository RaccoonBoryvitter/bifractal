package ui

import "core:fmt"

import im "deps:imgui"

import "../settings"

draw_hud :: proc(view: ^Ui_View) {
    s := view.settings.hud
    if !s.enabled do return

    vp := im.GetMainViewport()
    pos := compute_hud_anchor(vp, s)
    pivot := compute_hud_pivot(s.anchor)

    im.SetNextWindowPos(pos, .Always, pivot)
    im.SetNextWindowViewport(vp.ID_)
    im.SetNextWindowBgAlpha(s.opacity)

    flags := im.WindowFlags {
        .NoTitleBar,
        .NoResize,
        .NoMove,
        .NoScrollbar,
        .NoDocking,
        .NoSavedSettings,
        .AlwaysAutoResize,
    }
    if s.click_through {
        flags += im.WindowFlags_NoInputs
    }

    if !s.show_background {
        flags += {.NoBackground}
    }

    if !im.Begin("##HUD", nil, flags) {
        im.End()
        return
    }
    defer im.End()

    if s.show_fps do row("FPS", fmt.tprintf("%.1f", view.fps))
    if s.show_frame_ms do row("Frame", fmt.tprintf("%.2f ms", view.frame_time_ms))
    if s.show_fractal_kind do row("Fractal", fractal_kind_name(view.fractal))
    if s.show_fractal_params {
        if p := fractal_params_name(view.fractal); p != "" do im.Text("%s", p)
    }
    if s.show_center do row("Center", format_coord(view.fractal.base.camera.view.center, s.coord_format))
    if s.show_zoom do row("Zoom", format_zoom(view.fractal.base.camera.view.zoom))
    if s.show_iter do row("Iter", fmt.tprintf("%d", view.fractal.base.max_iter))
    if s.show_mouse {
        mouse := [2]f32 {
            real(view.ui_state.mouse_complex),
            imag(view.ui_state.mouse_complex),
        }
        row("Mouse", format_coord(mouse, s.coord_format))
    }
    if s.show_resolution do row("Res", fmt.tprintf("%dx%d", view.window_size.w, view.window_size.h))
    if s.show_palette do row("Palette", palette_name(view.fractal.base.palette))
}

@(private = "file")
row :: proc(label, value: string) {
    im.Text(fmt.ctprintf("%s: %s", label, value))
}

@(private = "file")
compute_hud_anchor :: proc(
    vp: ^im.Viewport,
    s: settings.Hud_Settings,
) -> im.Vec2 {
    p := s.padding
    switch s.anchor {
    case .TopRight:
        return {vp.WorkPos.x + vp.WorkSize.x - p, vp.WorkPos.y + p}
    case .TopLeft:
        return {vp.WorkPos.x + p, vp.WorkPos.y + p}
    case .BottomRight:
        return {
            vp.WorkPos.x + vp.WorkSize.x - p,
            vp.WorkPos.y + vp.WorkSize.y - p,
        }
    case .BottomLeft:
        return {vp.WorkPos.x + p, vp.WorkPos.y + vp.WorkSize.y - p}
    }
    return {0, 0}
}

@(private = "file")
compute_hud_pivot :: proc(anchor: settings.Hud_Anchor) -> im.Vec2 {
    switch anchor {
    case .TopRight:
        return {1, 0}
    case .TopLeft:
        return {0, 0}
    case .BottomRight:
        return {1, 1}
    case .BottomLeft:
        return {0, 1}
    }
    return {0, 0}
}
