package main

import "base:runtime"
import "core:strings"
import "core:os"
import "core:c"

import sdl "vendor:sdl3"

main :: proc() {
    argc := cast(c.int)len(os.args)
    argv := make([]cstring, argc)
    defer delete(argv)

    for arg, i in os.args {
        c_arg, err := strings.clone_to_cstring(arg)
        if err != .None {
            panic("unexpected error ocurred while trying to retrieve application arguments")
        }

        argv[i] = c_arg
    }
    defer for arg in argv {
        delete (arg)
    }

    main_callback := proc(argc: c.int, argv: [^]cstring) {
        sdl.EnterAppMainCallbacks(
            argc,
            argv,
            SDL_AppInit,
            SDL_AppIterate,
            SDL_AppEvent,
            SDL_AppQuit
        )
    }
    sdl.RunApp(argc, raw_data(argv), main_callback, nil)
}
