package ui

import im "deps:imgui"

create_imgui_ui :: proc(view: ^Ui_View) {
    defer free_all(context.temp_allocator)

    im.SetNextWindowSize({360, 600}, .FirstUseEver)

    if !im.Begin("Sidebar", nil, {.NoSavedSettings}) {
        im.End()
        return
    }
    defer im.End()

    if im.BeginTabBar("SidebarTabs") {
        if im.BeginTabItem("View") {
            draw_view_tab(view)
            im.EndTabItem()
        }

        if im.BeginTabItem("Fractal") {
            draw_fractal_tab(view)
            im.EndTabItem()
        }

        if im.BeginTabItem("Palette") {
            draw_palette_tab(view)
            im.EndTabItem()
        }

        if im.BeginTabItem("Stats") {
            draw_stats_tab(view)
            im.EndTabItem()
        }

        if im.BeginTabItem("Settings") {
            draw_settings_tab(view)
            im.EndTabItem()
        }

        im.EndTabBar()
    }
}
