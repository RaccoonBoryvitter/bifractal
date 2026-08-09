package ui

import "core:fmt"

import im "deps:imgui"

draw_toast :: proc(view: ^Ui_View) {
    if view.toast == "" do return

    vp := im.GetMainViewport()
    pos := im.Vec2 {
        vp.WorkPos.x + vp.WorkSize.x * 0.5,
        vp.WorkPos.y + vp.WorkSize.y - 60,
    }

    im.SetNextWindowPos(pos, .Always, {0.5, 0.5})
    im.SetNextWindowViewport(vp.ID_)

    flags :=
        im.WindowFlags {
            .NoTitleBar,
            .NoResize,
            .NoMove,
            .NoScrollbar,
            .NoDocking,
            .NoSavedSettings,
            .AlwaysAutoResize,
        } |
        im.WindowFlags_NoInputs

    bg_color := im.GetStyleColorVec4(.WindowBg)
    bg_color.a = 0.7
	
    im.PushStyleColorImVec4(.WindowBg, bg_color^)
    defer im.PopStyleColor()

    if !im.Begin("##Toast", nil, flags) {
        im.End()
        return
    }
    defer im.End()

    im.Text(fmt.ctprintf("Saved: %s", view.toast))
}
