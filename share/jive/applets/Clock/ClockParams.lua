
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

-- word clock parameters
word_clock = {
    -- colour palette for word clock
    colours = default_word_clock_colours,
    -- colour to use for word clock elements that are off
    -- rr -> red, gg -> green, bb -> blue, aa -> alpha
    -- note colours are applied as overlays, so alpha should almost always be ff
    -- Counter intuitively lowering the alpha value brightens the text.
    -- This is because the text images are white text on transparent background.
    off_colour = 0x303030ff,
    -- increment to apply when changing the colour.
    -- This should be a prime number  which is not a factor of the
    -- number of colours in the palette OR 1
    colour_inc = 7,
    -- foreground colour mode strings
    -- This array is also used by the UI for user selection
    colour_modes = {"Multiple", "Single", "White"},
    -- foreground colour mode attributes
    colour_mode_attributes = {
        ["Multiple"] = { uses_palette = true, change_colour_on_word = true},
        ["Single"] = { uses_palette = true, change_colour_on_word = false},
        ["White"] = { uses_palette = false, change_colour_on_word = false},
    },
    -- font selections
    font_list = {"CooperBlack", "FreeSans"},
    FreeSans = {
        font="FreeSansBold",
        layout = {
        -- Row 1
            textIt = {x=20, y=50},
            textIs = {x=86, y=50},
            textHas = {x=156, y=50},
            textNearly = {x=280, y=50},
            textJustgone = {x=496, y=50},

        -- Row 2
            textHalf = {x=20, y=108},
            textTen = {x=163, y=108},
            textAQuarter = {x=274, y=108},
            textTwenty = {x=579, y=108},

        -- Row 3
            textFive = {x=20, y=165},
            textMinutes = {x=169, y=165},
            textTo = {x=425, y=165},
            textPast = {x=537, y=165},
            textHourSix = {x=707, y=165},

        -- Row 4
            textHourSeven = {x=20, y=222},
            textHourOne = {x=222, y=222},
            textHourTwo = {x=363, y=222},
            textHourTen = {x=513, y=222},
            textHourFour = {x=650, y=222},

        -- Row 5
            textHourFive = {x=20, y=280},
            textHourNine = {x=193, y=280},
            textHourTwelve = {x=371, y=280},
            textHourEight = {x=639, y=280},

        -- Row 6
            textHourEleven = {x=20, y=338},
            textHourThree = {x=222, y=338},
            textOClock = {x=398, y=338},
            textAM = {x=627, y=338},
            textPM = {x=716, y=338},
        }
    },
    CooperBlack = {
        font="Cooper/ttf/Cooper-Black",
        layout = {
        -- Row 1
            textIt = {x=20, y=50},
            textIs = {x=20+78, y=50},
            textHas = {x=20+142, y=50},
            textNearly = {x=20+260, y=50},
            textJustgone = {x=20+474, y=50},

        -- Row 2
            textHalf = {x=20, y=50+58},
            textTen = {x=20+138, y=50+58},
            textAQuarter = {x=20+242, y=50+58},
            textTwenty = {x=20+546, y=50+58},

        -- Row 3
            textFive = {x=20, y=50+58+58},
            textMinutes = {x=20+160, y=50+58+58},
            textTo = {x=20+418, y=50+58+58},
            textPast = {x=20+514, y=50+58+58},
            textHourSix = {x=20+674, y=50+58+58},

        -- Row 4
            textHourSeven = {x=20, y=50+58+58+58},
            textHourOne = {x=20+198, y=50+58+58+58},
            textHourTwo = {x=20+340, y=50+58+58+58},
            textHourTen = {x=20+484, y=50+58+58+58},
            textHourFour = {x=20+622, y=50+58+58+58},

        -- Row 5
            textHourFive = {x=20, y=50+58+58+58+58},
            textHourNine = {x=20+170, y=50+58+58+58+58},
            textHourTwelve = {x=20+362, y=50+58+58+58+58},
            textHourEight = {x=20+610, y=50+58+58+58+58},

        -- Row 6
            textHourEleven = {x=20, y=50+58+58+58+58+58},
            textHourThree = {x=20+206, y=50+58+58+58+58+58},
            textOClock = {x=20+378, y=50+58+58+58+58+58},
            textAM = {x=20+596, y=50+58+58+58+58+58},
            textPM = {x=20+684, y=50+58+58+58+58+58},
        }
    }
}
