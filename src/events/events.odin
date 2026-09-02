package events

import "../geom"

Window_Resized :: struct {
    size: geom.Extent_2D,
}

Image_Save_Requested :: struct {}

App_Event :: union {
    Window_Resized,
    Image_Save_Requested,
}

App_Events :: struct {
    queue: [dynamic]App_Event,
}
