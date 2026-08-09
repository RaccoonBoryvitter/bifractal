package platform

import sdl "vendor:sdl3"

BIFRACTAL_NAME    :: "Bifractal"
BIFRACTAL_VERSION :: "0.5.0"
BIFRACTAL_APP_ID  :: "io.github.RaccoonBoryvitter.bifractal"
BIFRACTAL_AUTHOR  :: "RaccoonBoryvitter"
BIFRACTAL_URL     :: "https://github.com/RaccoonBoryvitter/bifractal"
BIFRACTAL_TYPE    :: "application"

apply_app_metadata :: proc() {
	_ = sdl.SetAppMetadata(BIFRACTAL_NAME, BIFRACTAL_VERSION, BIFRACTAL_APP_ID)
	_ = sdl.SetAppMetadataProperty(sdl.PROP_APP_METADATA_CREATOR_STRING, BIFRACTAL_AUTHOR)
	_ = sdl.SetAppMetadataProperty(sdl.PROP_APP_METADATA_URL_STRING, BIFRACTAL_URL)
	_ = sdl.SetAppMetadataProperty(sdl.PROP_APP_METADATA_TYPE_STRING, BIFRACTAL_TYPE)
}
