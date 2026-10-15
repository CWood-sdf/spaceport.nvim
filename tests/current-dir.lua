-- Run with isolated HOME/XDG directories:
-- nvim --headless -u NONE -i NONE -c 'set rtp+=.' -l tests/current-dir.lua
vim.opt.rtp:append(vim.fn.getcwd())
local root = vim.fn.stdpath("data")
vim.fn.mkdir(root, "p")
local project = root .. "/project"
vim.fn.mkdir(project, "p")
vim.cmd.cd(project)
local entered = 0
local done = 0
vim.api.nvim_create_autocmd("User", {
    pattern = "SpaceportDone",
    callback = function () done = done + 1 end,
})
require("spaceport").setup({
    sections = { "_global_remaps", "recents" },
    projectEntry = function ()
        entered = entered + 1
        vim.cmd("enew")
    end,
})
vim.cmd("Spaceport")
vim.api.nvim_feedkeys(".", "xt", false)
assert(entered == 1, "Open current dir must run projectEntry")
assert(done == 1, "Project entry must emit SpaceportDone")
assert(vim.bo.filetype ~= "spaceport")
local data = vim.json.decode(table.concat(vim.fn.readfile(
    root .. "/spaceport.json"), "\n"))
assert(data[vim.fn.getcwd()].isDir)
vim.cmd("Spaceport")
vim.api.nvim_feedkeys(".", "xt", false)
assert(entered == 2, "Tracked current directory must still open")
print("current-dir: PASS")
vim.cmd("qa!")
