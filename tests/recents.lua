-- Run with isolated HOME/XDG directories:
-- nvim --headless -u NONE -i NONE -c 'set rtp+=.' -l tests/recents.lua
local root = vim.fn.stdpath("data")
vim.fn.mkdir(root, "p")
local projects = {}
for i = 1, 3 do
    projects[i] = root .. "/project-" .. i
    vim.fn.mkdir(projects[i], "p")
end
require("spaceport").setup({
    sections = { "recents" },
    icons = false,
    maxRecentFiles = 0,
})
vim.v.oldfiles = projects
vim.cmd("Spaceport importOldfiles")
vim.cmd("Spaceport")
local function keys(input)
    vim.v.errmsg = ""
    vim.api.nvim_feedkeys(input, "xt", false)
    assert(vim.v.errmsg == "", vim.v.errmsg)
end
local function data()
    return vim.json.decode(table.concat(vim.fn.readfile(
        root .. "/spaceport.json"), "\n"))
end
local function hover(project)
    for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        if line:find(project, 1, true) then
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            return
        end
    end
    error("Project not rendered: " .. project)
end
vim.api.nvim_win_set_cursor(0, { 1, 0 })
keys("t")
keys("dd")
keys("99t")
keys("99dd")
keys("1t")
hover(projects[1])
keys("J") -- moving the only pin must stay at the bottom
assert(data()[projects[1]].pinNumber == 1)
keys("2t")
keys("3t")
hover(projects[1])
keys("t") -- removing a tag keeps the remaining pin numbers contiguous
assert(data()[projects[2]].pinNumber == 1)
assert(data()[projects[3]].pinNumber == 2)
-- Row 5 used to contain a pin, but is now the blank before Today.
vim.api.nvim_win_set_cursor(0, { 5, 0 })
keys("dd")
assert(data()[projects[1]] ~= nil, "Blank rows must not retain old targets")
hover(projects[2])
keys("9J")
assert(data()[projects[2]].pinNumber == 2)
assert(data()[projects[3]].pinNumber == 1)
hover(projects[2])
keys("9K")
assert(data()[projects[2]].pinNumber == 1)
hover(projects[3])
keys("dd")
assert(data()[projects[3]] == nil)
assert(data()[projects[2]].pinNumber == 1)
print("recents: PASS")
vim.cmd("qa!")
