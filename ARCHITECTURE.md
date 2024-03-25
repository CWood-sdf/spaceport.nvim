# Architecture

## High Level Overview

Spaceport is composed of two seperate components: the project tracker and a powerful rendering engine.

The directory tracker is responsible for recording when project are entered, managing functions to call when a project is entered, tags, tmux window names, and the json file database. It is nearly entirely contained in the `lua/spaceport/data.lua` file.

The rendering engine is responsible for taking screens, rendering them, and setting keymaps. It is nearly entirely contained in the `lua/spaceport/screen.lua` file.

## Project Tracker

The entry point for the project tracker is the `refreshData()` function. This funciton invokes `readData()` to read the json file database, then places the rawData into the `data` and `pinnedData` tables.

The `readData()` function reads from the json file database, and then it cleans the data just in case the json file is corrupted.

The other important functions are:

- `renameSession/Window()`: Renames the tmux session/window if a project has been selected.
- `useWindow/SessionName()`: Sets the tmux window/session name to be the name that the project has been assigned.
- `tmuxSplitWindowDown/Left()`: Splits the tmux window down or left, depending on the direction.
- `cd()`: Does all the actions necessary to change the project to the parameter passed in.

## Rendering Engine High Level Overview

### Types

The `SpaceportRemap` class is used to store keymaps. Most of the fields are self-explanatory except for the `visible` and `callOutside` fields. The `visible` field is used to determine if the keymap should be visible on the screen remaps screen. The `callOutside` field tells the keymap engine whether to call the keymap function if the cursor is outside the lines of the screen that the keymap is on.

The `SpaceportWord` class is one of the most important classes in the rendering engine. It is used to store text to render, but it also stores highlight data in the `colorOpts` field. The `colorOpts` field is passed nearly directly to the `nvim_set_hl` function, so if you want help with that, go to the neovim documentation. However, the rendering engine internally creates the actual highlight group with the given colorOpts field, but this might be undesired behavior if you want the user to set the highlight values in their own config. To accomodate this, an optional \_name field can be added to `colorOpts` to override the default highlight group name.

The `SpaceportScreen` class is used to store all data on a screen in the rendering engine. It stores the lines to be rendered, the remaps to be set, and the (optional) start position of the screen.

Two properties that need a little bit of explanation in the `SpaceportScreen` class are `position` and `onExit`. The `position` property is used to determine where to place a screen, if left nil, the screen will be centered and placed directly below the previous screen with `position` not set. However, if `position` is set, the position value is used as an offset vector from one of the corners of the screen. The diagram below shows the corner that is chosen based on the sign of the x and y values of the position vector.

<!--prettier-ignore-->
┌──────────────────────────── viewport ──────────────────────────────────────────┐
│                       ▲                                                        │
│                       │◄ ──── .row measures from the top if it is positive     │
│                       │                                                        │
│                       ▼                                                        │
│                    ┌───────────────────────────────┐                           │
│                    │                               │                           │
│ .col is from the   │                               │ .col measures from the    │
│ left if it's pos   │                               │  right if it is negative  │
│       │            │             screen            │                 │         │
│       ▼            │                               │                 ▼         │
│◄ ──────────────── ►│                               │◄ ────────────────────── ► │
│                    │                               │                           │
│                    │                               │                           │
│                    └───────────────────────────────┘                           │
│                      ▲                                                         │
│                      │◄ ─── .row measures from the bottom if it is negative    │
│                      │                                                         │
│                      ▼                                                         │
└────────────────────────────────────────────────────────────────────────────────┘

<!--prettier-ignore-->
### Functions

The first ~330 Lines of the `screen.lua` file are helper functions that are used for rendering or sanitizing the screens. About 113 of the 330 lines are helper functions around the SpaceportWord class for centering words, splitting words, and converting words to string and vice versa.

The `render()` function is the entry point for the rendering engine, it refreshes the json data, creates a window and buffer if needed, calls the `renderGrid()` function to virtually render the screen to a table, renders the text to the buffer, then invokes the `highlightBuffer()` function to highlight the buffer, then finally sets the keymaps via `setRemaps()`.

## Rendering Engine Low Level Overview

### `renderGrid()`

`renderGrid` takes three arguments: a `screen` object, an array of words `gridLines`, and a `centerRow`. It returns two values: the modified `gridLines` array, and a `SpaceportViewport` object.

The main purpose of this function is to render the content of the given screen into a 2D grid (`gridLines`) and calculate the viewport area for it. Here's a high-level summary of what it does:

1. It initializes some variables, including an array `lines` that will be used to store lines from the screen.

2. The function starts by adding a top buffer based on the `screen.topBuffer` value.

3. If the screen has a title, it adds that title as the first line in the `lines` array.

4. It then appends all lines from the screen (if available) to the `lines` array after the title, and calculates the maximum height and width of the grid.

5. Based on the position information provided in the `screen`, it adjusts the row (`row`) and column (`col`) variables if necessary. If no position is given, it centers the lines.

6. It makes sure that the size of `gridLines` is big enough to accommodate all lines.

7. For each line in the `lines` array, it generates a new row for the corresponding gridLine by taking words from the line, adding them to the grid (based on the screen position), and handling UTF-8 characters.

8. Finally, the function returns the updated `gridLines` array, and a `SpaceportViewport` object that contains information about the starting and ending rows and columns of the viewport.

### `highlightBuffer()`

The given function `higlightBuffer` is designed to highlight specific words in a buffer based on the provided gridLines, which is a 2D table of SpaceportWord objects.

The function performs the following steps:

1. If hlNs (highlight namespaces) is not nil, it clears and sets to nil.
2. Creates or reinitializes a new highlight namespace called "Spaceport".
3. Checks if the buffer and winid are valid.
4. Initializes variables for iteration through gridLines and usedHighlights.
5. Iterates through each word in the gridLines, and for each word:
   1. If it has colorOpts, processes the colorOpts as follows:
      - If it desires that it has a specific highlight group name, uses that group name.
      - If it already exists as a highlight group name in usedHighlights, uses that group name.
      - If not, generates a new global highlight group name (spaceport_hl\_ followed by an incrementing id), and sets its colors using vim.api.nvim_set_hl().
   2. Adds the highlight to the buffer using vim.api.nvim_buf_add_highlight().
6. Resets the col and row variables for the next iteration.

### `setRemaps()`

The `setRemaps` function is used to configure key mappings. It takes in two arguments: `viewport` and `screens`.

The function begins by calling `refreshData()` so that the latest data is available for remaps.

Next, for each screen in the `screens` array, it iterates through the list of remaps associated with that screen (if present). For each remap, it checks if the `action` property is a function. If it is, it sets up a key mapping using `vim.keymap.set()`. The function called when the mapping is invoked checks if the cursor is within the viewport area of the screen. If it is, the function calls the `action` function associated with the remap. If the cursor is outside the viewport area, the function checks if the `callOutside` property is set to true, and if it is, it calls the `action` function.

If the `action` property is not a function, the function directly sets up the key mapping using `vim.keymap.set()`, with no further processing.

Finally, for each shortcut in the Spaceport configuration, the function sets up a key mapping to open that directory or file using `vim.keymap.set("n", v[1], ...)`.
