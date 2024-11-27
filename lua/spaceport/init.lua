local M = {}

---@class (exact) SpaceportRemapModifier
---@field ogkey? string the key of the current remap that is being overriden
---@field key? string set to empty string to delete remap
---@field description? string
---@field action? fun(line: number, count: number)
---@field callOutside? boolean
---@field visible? boolean

---@class SpaceportScreenConfig : SpaceportScreen
---@field [1] string
---@field remaps SpaceportRemapModifier[]

---@class (exact) SpaceportConfig
---@field replaceDirs (string[] | string)[]
---@field replaceHome boolean
---@field projectEntry string | fun()
---@field sections (string | fun(): SpaceportScreen | SpaceportScreen | SpaceportScreenConfig)[]
---@field icons boolean | {File: string, Dir: string}
---@field logPath string
---@field maxRecentFiles number
---@field logPreserveHrs number
---@field lastViewTime "pin"|"today"|"yesterday"|"pastWeek"|"pastMonth"|"later"
---@field debug boolean
---@field shortcuts string[][]
local opts = {
    lastViewTime = "later",
    replaceDirs = {},
    replaceHome = true,
    projectEntry = "Ex",
    logPath = vim.fn.stdpath("log") .. "/spaceport.log",
    logPreserveHrs = 24,
    sections = {
        "name",
        "remaps",
        "recents",
        "_global_remaps",
    },
    icons = false,
    maxRecentFiles = 0,
    debug = false,
    shortcuts = {},
}

local lastClean = 0

local function cleanLog()
    local logFile = opts.logPath
    if not require("spaceport.data").exists(logFile) then
        vim.fn.writefile({ "" }, logFile)
    end
    local log = vim.fn.readfile(logFile)
    for i = 1, #log do
        local num = vim.fn.strptime("%Y-%m-%d~%H:%M:%S", vim.fn.split(log[i], " ")[1])
        if not num then
            table.remove(log, i)
        elseif num < vim.fn.localtime() - opts.logPreserveHrs * 60 then
            table.remove(log, i)
        end
    end
    vim.fn.writefile(log, logFile)
    lastClean = vim.loop.hrtime()
end

local startupStart = 0
local startupTime = 0

function M.__timeStartup()
    startupStart = vim.loop.hrtime()
end

function M.__timeStartupEnd()
    startupTime = vim.loop.hrtime() - startupStart
end

---@return number
function M.getStartupTime()
    return startupTime / 1e6
end

local hasInit = false
---@param _opts SpaceportConfig
function M.setup(_opts)
    hasInit = true
    for k, v in pairs(_opts) do
        if opts[k] == nil then
            M.log("Invalid option for spaceport config: " .. k)
        end
        opts[k] = v
    end
    opts.logPath = vim.fn.fnamemodify(opts.logPath, ":p") or ""
    require("spaceport.setup_auto")
    vim.schedule(function()
        cleanLog()
    end)
end

---@param msg string
function M.log(msg)
    if msg == nil then
        return
    end
    -- Clean every hour
    if (vim.loop.hrtime() - lastClean) / 1e9 > 60 * 60 then
        cleanLog()
    end
    local str = vim.fn.strftime("%Y-%m-%d~%H:%M:%S") .. " " .. msg
    local logFile = vim.fn.fnamemodify(opts.logPath, ":p") or ""
    local file = io.open(logFile, "a")
    if file == nil then
        print("Could not open log file: " .. logFile)
        return
    end
    file:write(str .. "\n")
    file:close()
end

---@return number
function M._getMaxRecentFiles()
    return opts.maxRecentFiles
end

---@return boolean
function M._getHasInit()
    return hasInit
end

---@return (string|string[])[]
function M._getIgnoreDirs()
    return opts.replaceDirs
end

---@return string
---@param path string
function M._swapHomeWithTilde(path)
    if not opts.replaceHome then
        return path
    end
    -- print(os.getenv("HOME"), opts.replaceHome, path, jit.os)
    local home = os.getenv("HOME") or ""
    if jit.os == "Windows" then
        home = os.getenv("USERPROFILE") or ""
    end
    local pathCopy = path .. ""
    local shouldSwap = true
    for i = 1, #home do
        if i > #pathCopy then
            break
        end
        if pathCopy:sub(i, i) ~= home:sub(i, i) then
            shouldSwap = false
            break
        end
    end
    if shouldSwap then
        return "~" .. pathCopy:sub(#home + 1)
    end
    return path
end

---@return string
---@param path string
function M._fixDir(path)
    ---@type string
    local ret = M._swapHomeWithTilde(path .. "")
    for _, dir in pairs(opts.replaceDirs) do
        local ok = type(dir) == "table"
        if ok then
            -- print(vim.inspect(d))
            ret = ret:gsub(dir[1], dir[2])
            -- return ret
        else
            ---@cast dir string
            ret = ret:gsub(dir, "")
        end
    end
    return ret
end

---@return (string | fun(): SpaceportScreen | SpaceportScreen | SpaceportScreenConfig )[]
function M._getSections()
    return opts.sections
end

---@return string
---@param icon string
function M._getIcon(icon)
    if type(opts.icons) == "table" then
        if opts.icons[icon] then return opts.icons[icon] else return "" end
    else
        local defaultIcons = { File = "", Dir = "" }
        if opts.icons then
            if defaultIcons then return defaultIcons[icon] else return "" end
        end
    end
    return ""
end

function M._projectEntryCommand()
    if type(opts.projectEntry) == "string" then
        local cmd = opts.projectEntry
        ---@cast cmd string
        vim.cmd(cmd)
    elseif type(opts.projectEntry) == "function" then
        opts.projectEntry()
    end
end

---@return SpaceportConfig
function M.getConfig()
    return opts
end

return M
