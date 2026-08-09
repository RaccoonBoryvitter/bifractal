package ui

import "core:fmt"

import im "deps:imgui"

draw_stats_tab :: proc(view: ^Ui_View) {
    im.Text(fmt.ctprintf("FPS: %.1f", view.fps))
    im.Text(fmt.ctprintf("Frame time: %.2f ms", view.frame_time_ms))
    im.Text(fmt.ctprintf("GPU: %s", view.gpu_name))
    im.Text(fmt.ctprintf("Graphics API: %s", view.gpu_driver))
    im.Text(
        fmt.ctprintf(
            "Resolution: %dx%d",
            view.window_size.w,
            view.window_size.h,
        ),
    )
}
