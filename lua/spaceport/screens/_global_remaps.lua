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
        {
            key = ".",
            description = "Open current dir",
            mode = "n",
            action = function ()
                require("spaceport.data").setCurrentDir(vim.fn.getcwd())
            end,
        }
    },
}

return l
