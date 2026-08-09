package settings

default_settings :: proc() -> Settings {
    return Settings {
        hud = Hud_Settings {
            enabled = true,
            anchor = .TopRight,
            opacity = 1.0,
            padding = 12,
            show_fps = true,
            show_frame_ms = false,
            show_fractal_kind = true,
            show_fractal_params = true,
            show_center = true,
            show_zoom = true,
            show_iter = true,
            show_mouse = true,
            show_resolution = false,
            show_palette = true,
            coord_format = .Decimal,
            show_background = true,
            click_through = false,
        },
    }
}
