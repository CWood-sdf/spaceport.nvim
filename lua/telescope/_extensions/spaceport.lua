local telescope = require("telescope")

local function check()
    local health = vim.health
    local start = health.start or health.report_start
    local ok = health.ok or health.report_ok

    ---@param msg string
    ---@param advice? string[]
    local function warn(msg, advice)
        local fn = health.warn or health.report_warn
        if advice and #advice > 0 and not health.warn then
            fn(msg .. "\n  - " .. table.concat(advice, "\n  - "))
            return
        end
        if advice and #advice > 0 then
            fn(msg, advice)
            return
        end
        fn(msg)
    end

    ---@param msg string
    ---@param advice? string[]
    local function err(msg, advice)
        local fn = health.error or health.report_error
        if advice and #advice > 0 and not health.error then
            fn(msg .. "\n  - " .. table.concat(advice, "\n  - "))
            return
        end
        if advice and #advice > 0 then
            fn(msg, advice)
            return
        end
        fn(msg)
    end

    start("telescope-spaceport")

    local has_telescope = pcall(require, "telescope")
    if has_telescope then
        ok("telescope loaded")
    else
        err("telescope not found")
    end

    local has_core = pcall(require, "spaceport")
    if has_core then
        ok("spaceport core loaded")
    else
        err(
            "spaceport core not loaded",
            {
                "Install the spaceport plugin (spaceport.nvim) and call require('spaceport').setup({})",
            }
        )
    end

    if vim.fn.executable("fd") == 1 then
        ok("fd found (used by .find())")
    else
        warn(
            "fd not found",
            {
                "Install sharkdp/fd; required by telescope.extensions.spaceport.find()",
            }
        )
    end

    if vim.fn.executable("tmux") == 1 then
        ok("tmux found")
    else
        warn(
            "tmux not found",
            {
                "Optional; needed only for .tmux_windows() / .tmux_sessions()",
            }
        )
    end
end

return telescope.register_extension({
    exports = {
        projects = require("telescope._extensions.spaceport_mru"),
        tmux_windows = require("telescope._extensions.spaceport_tmux_windows"),
        tmux_sessions = require("telescope._extensions.spaceport_tmux_sessions"),
        find = require("telescope._extensions.spaceport_finder"),
    },
    health = check,
})
