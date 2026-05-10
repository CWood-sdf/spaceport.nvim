local M = {}

local h = vim.health

local function start(name)
    (h.start or h.report_start)(name)
end

local function ok(msg)
    (h.ok or h.report_ok)(msg)
end

---@param msg string
---@param advice? string[]
local function warn(msg, advice)
    local fn = h.warn or h.report_warn
    if advice and #advice > 0 and not h.warn then
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
    local fn = h.error or h.report_error
    if advice and #advice > 0 and not h.error then
        fn(msg .. "\n  - " .. table.concat(advice, "\n  - "))
        return
    end
    if advice and #advice > 0 then
        fn(msg, advice)
        return
    end
    fn(msg)
end

function M.check()
    start("spaceport: core")

    if vim.fn.has("nvim-0.8") == 1 then
        ok("Neovim >= 0.8.0")
    else
        err("Neovim >= 0.8.0 required")
    end

    local sp = require("spaceport")
    if sp._getHasInit() then
        ok("setup() has been called")
    else
        warn(
            "setup() has not been called",
            { "Call require('spaceport').setup({...}) in your config" }
        )
    end

    start("spaceport: projectHomes")
    for _, home in ipairs(sp._getProjectHomes()) do
        if vim.fn.isdirectory(home) == 1 then
            ok(("%s exists"):format(home))
        else
            warn(
                ("%s is not a directory"):format(home),
                { "Remove or fix this entry in projectHomes; .find() will skip it" }
            )
        end
    end

    start("spaceport: log")
    local cfg = sp.getConfig()
    local parent = vim.fn.fnamemodify(cfg.logPath, ":h")
    --- filewritable: 2 writable, 1 missing but parent allows create, 0 not writable
    local fw = vim.fn.filewritable(parent)
    if fw == 2 or fw == 1 then
        ok(("log directory writable or creatable: %s"):format(parent))
    else
        warn(
            ("log directory not writable: %s"):format(parent),
            { "Set logPath to a writable location" }
        )
    end

    start("spaceport: sections")
    local known = {
        name = true,
        remaps = true,
        recents = true,
        _global_remaps = true,
        hacker_news = true,
    }
    local uses_hn = false
    for _, s in ipairs(sp._getSections()) do
        local n = type(s) == "table" and s[1] or s
        if type(n) == "string" and known[n] ~= true then
            warn(
                ("unknown section %q"):format(n),
                {
                    "Built-ins: name, remaps, recents, _global_remaps, hacker_news",
                }
            )
        end
        if n == "hacker_news" then
            uses_hn = true
        end
    end
    if uses_hn then
        if vim.fn.executable("curl") == 1 then
            ok("curl found (used by hacker_news)")
        else
            warn("curl not found", { "Required by the hacker_news section" })
        end
    end
end

return M
