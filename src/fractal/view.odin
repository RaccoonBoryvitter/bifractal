package fractal

import "core:math"

import sdl "vendor:sdl3"

import "../geom"

view_screen_to_complex :: proc(
    screen: geom.Vec2,
    size: geom.Extent_2D,
    view: Fractal_View,
) -> complex64 {
    w := f32(size.w)
    h := f32(size.h)
    return complex(
        (screen.x - w * 0.5) / (h * view.zoom) + view.center.x,
        -(screen.y - h * 0.5) / (h * view.zoom) + view.center.y,
    )
}

get_window_pixel_scale :: proc(window: ^sdl.Window) -> geom.Vec2 {
    logical_w, logical_h: i32
    sdl.GetWindowSize(window, &logical_w, &logical_h)

    if logical_w <= 0 || logical_h <= 0 {
        return geom.Vec2{1, 1}
    }

    pixel_w, pixel_h: i32
    sdl.GetWindowSizeInPixels(window, &pixel_w, &pixel_h)

    return geom.Vec2 {
        f32(pixel_w) / f32(logical_w),
        f32(pixel_h) / f32(logical_h),
    }
}

reset_fractal_view :: proc(base: ^Fractal_Base) {
    base.camera.view.zoom = FRACTAL_DEFAULT_ZOOM
    base.zoom_level = math.log2(base.camera.view.zoom)
    base.camera.view.center = {
        FRACTAL_DEFAULT_CENTER_X,
        FRACTAL_DEFAULT_CENTER_Y,
    }
    base.max_iter = FRACTAL_DEFAULT_MAX_ITER
}
