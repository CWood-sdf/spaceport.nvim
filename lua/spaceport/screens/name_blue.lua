---@type (string|SpaceportWord[])[]
local topSection = {
    { { " _____                       ______          _   ", colorOpts = { fg = "#0000FF" } } },
    { { "/  ___|                      | ___ \\        | |  ", colorOpts = { fg = "#2222FF" } } },
    { { "\\ `--. _ __   __ _  ___ ___  | |_/ /__  _ __| |_ ", colorOpts = { fg = "#4444FF" } } },
    { { " `--. \\ '_ \\ / _` |/ __/ _ \\ |  __/ _ \\| '__| __|", colorOpts = { fg = "#6666FF" } } },
    { { "/\\__/ / |_) | (_| | (_|  __/ | | | (_) | |  | |_ ", colorOpts = { fg = "#8888FF" } } },
    { { "\\____/| .__/ \\__,_|\\___\\___| \\_|  \\___/|_|   \\__|", colorOpts = { fg = "#AAAAFF" } } },
    { { "      | |                                        ", colorOpts = { fg = "#CCCCFF" } } },
    { { "      |_|                                        ", colorOpts = { fg = "#EEEEFF" } } },
}
---@type SpaceportScreen
local r = {
    lines = topSection,
    remaps = {},
    title = nil,
    topBuffer = 1,
}

return r
