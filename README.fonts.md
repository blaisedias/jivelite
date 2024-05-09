# Fonts
Support has been added to support using of fonts other than FreeSans

A set of fonts from https://fonts.google.com has been added to `share/jive/fonts/`

The jivelite binary has been modifed to accept a default font setting.

This is primarily to workaround invocations to the set the font where the 
font specificatoin is not passed to the native code.

## Selecting a font
A menu item `Select Fonts` has been added under
`Settings` -> `Screen`

## Known issues
Some apps like Clock will only use the new font after JiveLite is restarted

