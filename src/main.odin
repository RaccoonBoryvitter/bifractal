package main

import "core:c"
import "core:os"
import "core:strings"

import sdl "vendor:sdl3"

main :: proc() {
    arg_c := (c.int)(len(os.args))
    arg_v := make([]cstring, arg_c)
    defer delete(arg_v)
    defer for arg in arg_v {
        delete(arg)
    }

    for arg, i in os.args {
        c_arg, err := strings.clone_to_cstring(arg)
        if err != .None {
            panic(
                "unexpected error ocurred while trying to retrieve application arguments",
            )
        }

        arg_v[i] = c_arg
    }

    main_callback := proc "c" (argc: c.int, argv: [^]cstring) -> c.int {
        return sdl.EnterAppMainCallbacks(
            argc,
            argv,
            SDL_AppInit,
            SDL_AppIterate,
            SDL_AppEvent,
            SDL_AppQuit,
        )
    }
    sdl.RunApp(arg_c, raw_data(arg_v), main_callback, nil)
}
