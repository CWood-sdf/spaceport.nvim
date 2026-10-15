-- Run with isolated HOME/XDG directories:
-- nvim --headless -u NONE -i NONE -c 'set rtp+=.' -l tests/remaps.lua
vim.fn.mkdir(vim.fn.stdpath("data"), "p")
local expanded = false
local hit
local added = false
require("spaceport").setup({
    sections = {
        {
            lines = function ()
                return expanded and { "a", "b", "c" } or { "a" }
            end,
        },
        {
            title = "Target",
            lines = { "hit" },
            remaps = {
                {
                    key = "x",
                    mode = "n",
                    description = "Record screen-relative line",
                    callOutside = false,
                    action = function (line) hit = line end,
                },
            },
        },
        {
            "recents",
            remaps = {
                {
                    ogkey = "",
                    key = "z",
                    mode = "n",
                    description = "Additional remap",
                    action = function () added = true end,
                },
            },
        },
    },
})
vim.cmd("Spaceport")
expanded = true
vim.cmd("Spaceport")
vim.api.nvim_win_set_cursor(0, { 5, 0 })
vim.api.nvim_feedkeys("x", "xt", false)
assert(hit == 1, "Remap must use the current screen viewport")
vim.api.nvim_feedkeys("z", "xt", false)
assert(added, "Empty ogkey must add the documented remap")
print("remaps: PASS")
vim.cmd("qa!")
