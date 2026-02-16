
module(...)

-- colour palette in hex 0xrrggbbaa
-- rr -> red, gg -> green, bb -> blue, aa -> alpha
local default_word_clock_colours = {
    0xff6666ff,
    0xff8c66ff,
    0xffb366ff,
    0xffd966ff,
    0xffff66ff,
    0xd9ff66ff,
    0xb3ff66ff,
    0x8cff66ff,
    0x66ff66ff,
    0x66ff8cff,
    0x66ffb3ff,
    0x66ffd9ff,
    0x66ffffff,
    0x66d9ffff,
    0x66b3ffff,
    0x668cffff,
    0x6666ffff,
    0x8c66ffff,
    0xb366ffff,
    0xd966ffff,
    0xff66ffff,
    0xff66d9ff,
    0xff66b3ff,
    0xff668cff,
}

-- colour palette in hex 0xrrggbbaa
-- rr -> red, gg -> green, bb -> blue, aa -> alpha
local bright_word_clock_colours = {
    0xff0000ff,
    0xff4000ff,
    0xff8000ff,
    0xffc000ff,
    0xffff00ff,
    0xc0ff00ff,
    0x80ff00ff,
    0x40ff00ff,
    0x00ff00ff,
    0x00ff40ff,
    0x00ff80ff,
    0x00ffc0ff,
    0x00ffffff,
    0x00c0ffff,
    0x0080ffff,
    0x0040ffff,
    0x0000ffff,
    0x4000ffff,
    0x8000ffff,
    0xc000ffff,
    0xff00ffff,
    0xff00c0ff,
    0xff0080ff,
    0xff0040ff,
}

-- colour palette for word clock
word_clock_colours = default_word_clock_colours
-- colour to use for word clock elements that are off
-- rr -> red, gg -> green, bb -> blue, aa -> alpha
-- note colours are applied as overlays, so alpha should almost always be ff
-- Counter intuitively lowering the alpha value brightens the text.
-- This is because the text images are white text on transparent background.
word_clock_off_colour = 0x303030ff
-- increment to apply when changing the colour.
-- This should be a prime number  which is not a factor of the
-- number of colours in the palette OR 1
word_clock_colour_inc = 7
-- colour settings strings, order is important, the code compares strings
-- using index values to determine behaviour
-- This array is also used by the UI for user selection
word_clock_colour_settings = {"Monochrome", "Single Colour", "Multiple Colours"}
