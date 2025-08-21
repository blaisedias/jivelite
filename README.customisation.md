# Overview
This document is a basic guide on customising Jivelite layout

## Terms and Conventions
* *username* in file paths containing `/home/<username>....` : *&lt;username&gt;* is the user name under which jivelite-vis is run. Typically this is the current user name. On embedded systems where jivelite is launched without user login, it is dependent on the deployment. For example on piCorePlayer the user name is *tc*
* *UI* short form for User Interface

## Introduction
There are 3 stages of customisation
* Layout UI menu
* Reading key value pairs from the file `/home/<username>/.jivelite/userpath-vis/Joggler.json`
* Reading key value pairs from the file `/home/<username>/.jivelite/userpath-vis/JogglerNowPlaying.json`

Note: the value of a key may itself be a set of key value pairs.

The layout of the JSON files reflect the internal data structures of jivelite-vis.

The contents of the JSON files are loaded into internal data structures of jivelite-vis.
This makes fine control possible but is currently implemented without any safeguards.
The contents are not marshalled when loaded.

Consequently, care must be exercised when configuring jivelite-vis using the JSON files.

# Workflow
The recommended procedure is to proceed in stages, 
* Use the Layout UI menu first and other *Now Playing* menu settings like *Hide Now Playing X of Y*
* If this proves insufficient then use `/home/<username>/.jivelite/userpath-vis/Joggler.json`
* And finally `/home/<username>/.jivelite/userpath-vis/JogglerNowPlaying.json`

## Order of precedence
Settings is the UI are overridden by settings in `/home/<username>/.jivelite/userpath-vis/Joggler.json`

In turn settings in `/home/<username>/.jivelite/userpath-vis/Joggler.json` are overridden by settings in `/home/<username>/.jivelite/userpath-vis/JogglerNowPlaying.json`

All three stages are *NOT* necessary!

## Generated JSON files
In the absence of published schemas for the JSON files, jivelite-vis generates JSON files that reflect the current settings
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerSkin.json`
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlaying.json`

These file also serve as templates for the set of valid key value pairs.

`/home/<username>/.jivelite/userpath-vis/cache/JogglerSkin.json` is always generated.

`/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlaying.json` can be generated from the *Layout* UI menu.

Given the complex structure of `JogglerNowPlaying.json`, a template file without any concrete key pair values 
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlayingTemplate.json`

is generated as an aid for the user (see section JogglerNowPlaying.json for more details)

The generated JSON files have sections keyed under the display resolution(s).
These settings will be loaded and applied only when Jivelite-vis is running with the display set to that resolution.

Settings in the Layout UI menu are reflected in generated JSON files, if not overridden by settings in JSON files.

Settings in Joggler.json are reflected JogglerNowPlaying.json, if not overridden by settings in 
`/home/<username>/.jivelite/userpath-vis/JogglerNowPlaying.json`.

## Using the UI
The titles of the menu items are considered largely self explanatory - and will not be described further here.

## Joggler.json
This JSON file can be used to configure User Interface parameters.

The full path for this file is `/home/<username>/.jivelite/userpath-vis/Joggler.json`.

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

A description of keys and associated sets of values is not within scope for this document.

The contents can be determined by from the file
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerSkin.json`
and then modified to suit.

**It is good practice to only add key value pairs that need modification and cannot be modified in the UI here**.

## JogglerNowPlaying.json
This JSON file can only be used to configure User Interface parameters for Now Playing Views.
Contents of this configuration file override values set by the User Interface or `/home/<username>/.jivelite/userpath-vis/Joggler.json`

The fully qualified path for this file is `/home/<username>/.jivelite/userpath-vis/JogglerNowPlaying.json`.

The simplest way to create this file is to copy
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlayingTemplate.json`
to
* `/home/<username>/.jivelite/userpath-vis/JogglerNowPlaying.json`

Then copy the key pair values in matching sections from  `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlaying.json` and modify the values.


**It is good practice to only add key value pairs that need modification and cannot be modified in the UI or `/home/<username>/.jivelite/userpath-vis/JogglerNowPlaying.json` **.

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

### allstyles
The entries under *allstyles* are a convenience method to specify values for fields that the user would want to apply to all Now Playing styles. This should only be colours and font sizes.
In general changing font sizes is best done using the UI.

The following example changes the colours of all text fields for all *Now Playing* styles
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
To make it possible to change the order of controls buttons in a manner which is convenient and retains the functionality of the UI, the key `order_sort` has been added.

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
When modifying location, width, height, font sizes, text justification, etc. it is often difficult to work out what is required,
or what is setting is causing undesired effects.

In such cases use the menu item *Settings->Screen->Layout->Debug Layout*, this sets background colours for UI elements.

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
