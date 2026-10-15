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
                local dir = vim.fn.getcwd()
                local data = require("spaceport.data")
                for _, entry in ipairs(data.getAllData()) do
                    if entry.dir == dir then
                        data.cd(entry)
                        return
                    end
                end
                data.cd({
                    dir = dir,
                    prettyDir = require("spaceport")._fixDir(dir),
                    isDir = true,
                    pinNumber = 0,
                    time = require("spaceport.utils").getSeconds(),
                })
            end,
        }
    },
}

return l
