package app

import "base:runtime"

import sdl "vendor:sdl3"

SDL_AppQuit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
    context = runtime.default_context()
    state := (^App_Context)(appstate)
	
    if state != nil {
        context.logger = state.logger
        destroy_app(state)
    }
}
