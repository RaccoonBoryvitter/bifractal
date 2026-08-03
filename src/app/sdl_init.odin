package app

import "base:runtime"
import "core:c"

import sdl "vendor:sdl3"

SDL_AppInit :: proc "c" (
    appstate: ^rawptr,
    argc: c.int,
    argv: [^]cstring,
) -> sdl.AppResult {
    context = runtime.default_context()
    state := init_app()
    if state == nil {
        return .FAILURE
    }
    context.logger = state.logger

    appstate^ = rawptr(state)
    return .CONTINUE
}
