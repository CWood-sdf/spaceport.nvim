---@type SpaceportScreen
local l = {
    lines = {},
    topBuffer = 0,
    title = nil,
    remaps = {
        {
            key = "R",
            description = "Reload Spaceport",
            mode = "n",
            action = function ()
                require("spaceport.screen").render()
            end,
        },
    },
}

return l
