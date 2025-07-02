# Overview
This document is a basic guide on customising Jivelite layout

There are 3 stages of customisation
* Layout UI menu
* Reading key value pairs from the file `/home/<username>/.jivelite/userpath-vis/Joggler.json`
* Reading key value pairs from the file `/.jivelite/userpath-vis/JogglerNowPlaying.json`

Note: the value of a key may itself be a set of key value pairs.

The layout of the JSON files reflect the internal data structures of jivelite-vis.

The contents of the JSON files are loaded into internal data structures of jivelite-vis.
This makes fine control possible but is currently implemented without any safeguards.
The contents are not marshalled when loaded.

Consequently, care must be exercised when using the JSON files.

# Workflow
The recommended procedure is to proceeed in stages, 
* Use the Layout UI menu first and other *Now Playing* menu settings like *Hide Now Playing X of Y*
* If this proves insufficient then use Joggler.json file
* And finally JogglerNowPlaying.json

All three stages are *NOT* necessary!

In the absence of published schemas for the JSON files, jivelite-vis generates JSON files that reflect the current settings
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerSkin.json`
* `/home/<username>/.jivelite/userpath-vis/cache/PiGridSkin.json`
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlaying.json`
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlayingTemplate.json`

These files serve as templates of the key value pairs required to configure the layout, with the exception of `JogglerNowPlaying.json`.

Given the complex structure of `JogglerNowPlaying.json`, a template file with no concrete key pair values `JogglerNowPlayingTemplate.json` is generated.

The generated JSON files have sections keyed under the display resolution(s).
These settings will be loaded and applied only when Jivelite-vis is running with the display set to that resolution.

Settings in the Layout UI menu are reflected in generated JSON files.

Settings in Joggler.json are reflected JogglerNowPlaying.json

## Using the UI
The titles of the menu items are considered largely self explanatory - and will not be described further here.

## Joggler.json
It is good practice to only add key value pairs that are modified and cannot be modified to the UI here.

Format is: 
```
{
    <W>x<H>: {
        "jogglerSkin" :{
            ....
            ....
        },
        "gridSkin" :{
            ....
            ....
        }
    }
}
```
where:
* W is display width
* H is display height

The contents of "jogglerSkin" should be copied from 
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerSkin.json`
and then modified to suit

The contents of "gridSkin" should be copied from 
* `/home/<username>/.jivelite/userpath-vis/cache/PiGridSkin.json`
and then modified to suit

**Only copy those key values pairs that need modification.**

## JogglerNowPlaying.json
The simplest way to create this is to copy
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlayingTemplate.json`
to
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlaying.json`


Then copy the key pair values in matching sections from  `/home/<username>/.jivelite/userpath-vis/Joggler.json`,
and then modify the values.


It is good practice to only add key value pairs that are modified and cannot be modified to the UI here.

Further it is good practice to only add key value pairs that cannot be modified suitably in `/home/<username>/.jivelite/userpath-vis/Joggler.json` here

`JogglerNowPlayingTemplate.json` contains a section `-doc`, which contains 2 sections targeted at users,
 * *advisories*
   * This contains notes on how to use the *allstyles* section and *ordering of controls*
 * *reference*
   * This section contains reference values of key pairs

Format is:
```
{
    <W>x<H>: {
        ....
        ....
    },
    "allstyles": {
        ....
        ....
    }

}
```
Where:
* W is display width
* H is display height

The contents of `<W>x<H>` are used to further refine *Now Playing* style and should be copied from 
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlaying.json` and then modified to suit.

**Only copy those parts that need modification.**

### allstyles
The entries under *allstyles* are a convenience method to specify values for fields that the user would want to apply to all Now Playing styles. This should only be colours and font sizes.
Changing font sizes is best done using the UI.

For example the following extract changes the colours of all text fields for all *Now Playing* styles
```
    "allstyles": {
            "npalbumgroup": {
                "npalbum": {
                    "fg": [ 0, 231, 231 ],
                    "sh": [ 55, 55, 55 ]
                }
            },
            "npartistalbum": {
                "fg": [ 231, 231, 0 ],
                "sh": [ 55, 55, 55 ]
            },
            "npartistgroup": {
                "npartist": {
                    "fg": [ 231, 231, 0 ],
                    "sh": [ 55, 55, 55 ]
                }            },
            "npartwork": {
            },
            "npaudiometadata": {
                "fg": [ 231, 231, 0 ]
            },
            "npcontrols": {
            },
            "npdebugdata": {
                "fg": [ 0, 231, 231 ],
                "sh": [ 55, 55, 55 ]
            },
            "npprogress": {
                "elapsed": {
                    "fg": [ 0, 231, 231 ],
                    "sh": [ 55, 55, 55 ]
                },
                "elapsedSmall": {
                    "fg": [ 0, 231, 231 ],
                    "sh": [ 55, 55, 55 ]
                },
                "remain": {
                    "fg": [ 0, 231, 231 ],
                    "sh": [ 55, 55, 55 ]
                },
                "remainSmall": {
                    "fg": [ 0, 231, 231 ],
                    "sh": [ 55, 55, 55 ]
                }
            },
            "npprogressNB": {
                "elapsed": {
                    "fg": [ 0, 231, 231 ],
                    "sh": [ 55, 55, 55 ]
                },
                "elapsedSmall": {
                    "fg": [ 0, 231, 231 ],
                    "sh": [ 55, 55, 55 ]
                }
            },
            "nptitle": {
                "nptrack": {
                    "fg": [ 0, 231, 0 ],
                    "sh": [ 55, 55, 55 ]
                }
            },
            "title": {
                "text": {
                    "fg": [ 231, 0, 231 ]
                },
                "textButton": {
                    "fg": [ 231, 0, 231 ]
                }
            }
          }
```

Here
* `fg` is the foreground colour ( colour of the text )
* `sh` is the colour of shadow applied to text

### values of keys named **order**
These should only be changed after familiarisation of their function by inspecting the code.

#### controls order
To make to possible to change the order of controls buttons in a manner which is convenient and retains the functionality of the UI, the key `order_sort` has been added.

The reference contents is generated in `-doc`.`reference` section of `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlaying.json`

The contents **must** define the sort order for **all** controls regardless of visibility.

By defining this in `allstyles` the control buttons order is defined consistently for all *Now Playing* views.

### Semantics and values of primitive keys
* `x`: number of pixels from the left edge
* `y`: number of pixels from the top edge
* `w`: width in pixels
* `h`: height in pixels
* `_font_size` and `_font_size_bold`: font size, there is no separate setting to embolden fonts
* `align`: horizontal alignment of the UI element with the rectangle defined by `x`,`y`,`w`, and `h`
  * values: `left`, `center` and `right`
* `fg` : foreground colour
  * array of integers [`red`, `green`, `blue`]
  * range of values for each integer i `0` - `255` 
* `sh` : text shadow colour
  * array of integers [`red`, `green`, `blue`]
  * range of values for each integer i `0` - `255` 

#### The description of the following keys are approximations. In general changing these values is not recommended.
* `border`: border of the UI element in pixels [`left`, `top`, `right`, `bottom`]
* `padding`: padding applied to the UI element in pixels [`left`, `top`, `right`, `bottom`]
* `position` : vertical and horizontal position with the rectangle defined by `x`,`y`,`w`, and `h`
   * `0`: north
   * `1`: east
   * `2`: south
   * `3`: west
   * `4`: center
   * `5`: none

# Debugging Layout issues
When modifying location, width, height, font sizes, text justification .... it is often difficult to work out what is required,
or what is setting is causing undesired effects.

To help in this case use the menu item *Settings->Screen->Layout->Debug Layout*, this sets background colours for UI elements.

This feature is mainly targeted at Now Playing views, and is not very useful for other screens.

# FAQ
1) In *npcontrols.order_sort*, what are *divVolSpace* and *divVolSpace2* ?

Answer:
  * These are spacers, used to right justify the volume controls in the controls bar.
  * Only *divVolSpace2* is used for large art Now Playing views with controls.
  * The values are calculated by the code and are not user configurable.

2) Is the *-doc* section in *JogglerNowPlayingTemplate.json* required in *JogglerNowPlaying.json*?

Answer:
  * No, the section has been provided as an aid for the user. Including the section does no harm, as the section is ignored.
