package render

import sdl "vendor:sdl3"

import "../geom"
import "../platform"

SAVE_TOAST_DURATION_MS :: 3000

Save_State :: struct {
    pending:     bool,
    toast:       string,
    toast_ticks: u64,
}

request_save :: proc(state: ^Save_State) {
    state.pending = true
}

tick_toast :: proc(state: ^Save_State, now: u64) -> bool {
    if state.toast == "" do return false
    if now - state.toast_ticks > SAVE_TOAST_DURATION_MS {
        clear_toast(state)
        return true
    }
    return false
}

get_toast :: proc(state: ^Save_State) -> string {
    return state.toast
}

process_save :: proc(
    state: ^Save_State,
    gpu: ^platform.Gpu_Context,
    size: geom.Extent_2D,
) -> bool {
    if !state.pending do return false
    state.pending = false

    path, ok := save_output_to_png(gpu, size)
    if ok {
        clear_toast(state)
        state.toast = path
        state.toast_ticks = sdl.GetTicks()
    }
    return ok
}

destroy :: proc(state: ^Save_State) {
    clear_toast(state)
}

@(private = "file")
clear_toast :: proc(state: ^Save_State) {
    delete(state.toast)
    state.toast = ""
}
