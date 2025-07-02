# Overview
This document is a basic guide on customising Jivelite layout

There are 3 methods of customisation
* Layout UI menu
* Reading key value pairs from the file `/home/<username>/.jivelite/userpath-vis/Joggler.json`
* Reading pairs from the file `/.jivelite/userpath-vis/JogglerNowPlaying.json`

Note: the value of a key may itself be a set of key value pairs.

The layout of the JSON files reflect the internal data structures of jivelite-vis.

The contents of the JSON files are loaded into internal data structures of jivelite-vis. This makes fine control possible but is currently implemented without any safeguards. When loaded the contents are not marshalled.

Care must be exercised when using the JSON files.

# Workflow
The recommended procedure is to use the Layout UI menu first and other *Now Playing* menu settings like *Hide Now Playing X of Y*

If this proves insufficient then use Joggler.json file

And finally JogglerNowPlaying.json

In the absence of published schemas for the JSON files, jivelite-vis generates JSON files that reflect the current settings
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerSkin.json`
* `/home/<username>/.jivelite/userpath-vis/cache/PiGridSkin.json`
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlaying.json`

These files serve as templates of the key value pairs required to configure the layout.

The generated JSON files have sections keyed under the display resolution(s).
These settings will be loaded and applied only when Jivelite-vis is running with the display set to that resolution.

Settings in the Layout UI menu are reflected in generated JSON files.

Settings in Joggler.json are reflected JogglerNowPlaying.json

## Using the UI
The titles of the  menu items are considered largely self explanatory - and will not be described further here.

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

**Only copy those parts that need modification.**

## JogglerNowPlaying.json
It is good practice to only add key value pairs that are modified and cannot be modified to the UI here.

Further it is good practice to only add key value pairs that cannot be modified suitably in `/home/<username>/.jivelite/userpath-vis/Joggler.json` here

Format is:
```
{
    "allstyles": {
        ....
        ....
    }
    <W>x<H>: {
        ....
        ....
    }
}
```

where:
* W is display width
* H is display height

The contents of `<W>x<H>` are used to further refine *Now Playing* style and should be copied from 
* `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlaying.json` and then modified to suit.

**Only copy those parts that need modification.**

### allstyles
The entries under *allstyles* are a convenience method to specify values for fields that the user would want to apply to all Now Playing styles. This should only be colours and font sizes.
Changing font sizes is bets done using the UI.

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

#### values of keys named **order**
These should only be changed after familiarisation of their function by inspecting the code.

#### controls order
To make to possible to change the order of controls buttons in a manner which is convenient and retains the functionality of the UI, the key `order_sort` has been added.

The reference contents is generated be seen in `-doc` section of `/home/<username>/.jivelite/userpath-vis/cache/JogglerNowPlaying.json`

The `allstyles` section there is an example of the entry required to changed the order of the control buttons.

The contents **must** define the sort order for **all** controls regardless of visibility.

By defining this in `allstyles` the control buttons order is defined consistently for all *Now Playing* views.
