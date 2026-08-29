package platform

import "../geom"
import "core:log"
import sdl "vendor:sdl3"

WINDOW_TITLE :: "Bifractal"
WINDOW_RESOLUTION :: geom.Extent_2D {
    w = 1280,
    h = 720,
}

Window :: struct {
    handle:         ^sdl.Window,
    size:           geom.Extent_2D,
    pixel_scale:    geom.Vec2,
    default_cursor: ^sdl.Cursor,
    move_cursor:    ^sdl.Cursor,
}

init_window :: proc() -> ^Window {
    apply_app_metadata()
    ok := sdl.Init({.VIDEO, .EVENTS})
    if !ok {
        log.errorf("unable to initialize SDL: %s", sdl.GetError())
        return nil
    }

    main_scale := sdl.GetDisplayContentScale(sdl.GetPrimaryDisplay())
    handle := sdl.CreateWindow(
        WINDOW_TITLE,
        i32(f32(WINDOW_RESOLUTION.w) * main_scale),
        i32(f32(WINDOW_RESOLUTION.h) * main_scale),
        {.RESIZABLE, .HIGH_PIXEL_DENSITY},
    )
    if handle == nil {
        log.errorf("unable to create SDL window: %s", sdl.GetError())
        sdl.Quit()
        return nil
    }

    sdl.SetWindowPosition(
        handle,
        sdl.WINDOWPOS_CENTERED,
        sdl.WINDOWPOS_CENTERED,
    )

    result := new(Window)
    result.handle = handle
    result.default_cursor = sdl.CreateSystemCursor(.DEFAULT)
    result.move_cursor = sdl.CreateSystemCursor(.MOVE)
    return result
}

compute_pixel_scale :: proc(handle: ^sdl.Window) -> geom.Vec2 {
    logical_w, logical_h: i32
    sdl.GetWindowSize(handle, &logical_w, &logical_h)

    if logical_w <= 0 || logical_h <= 0 {
        return geom.Vec2{1, 1}
    }

    pixel_w, pixel_h: i32
    sdl.GetWindowSizeInPixels(handle, &pixel_w, &pixel_h)

    return geom.Vec2 {
        f32(pixel_w) / f32(logical_w),
        f32(pixel_h) / f32(logical_h),
    }
}
