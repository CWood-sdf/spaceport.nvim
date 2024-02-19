local spaceport = require("spaceport")
local M = {}
local dataPath = vim.fn.stdpath("data")
local dataDir = dataPath .. "/spaceport.json"
local log = spaceport.log

---@class (exact) SpaceportDir
---@field dir string
---@field time number
---@field isDir boolean
---@field pinNumber number
---@field prettyDir string
---@field tmuxWindowName string|nil
---@field tmuxSessionName string|nil

---@type SpaceportDir|nil
local currentDir = nil

---@type SpaceportDir[]
local data = {}
---@type SpaceportDir[]
local pinnedData = {}


---@alias SpaceportRawData table<string, {time: number, isDir: boolean, pinNumber: number, tmuxWindowName: string|nil, tmuxSessionName: string|nil}>

---@type SpaceportRawData
local rawData = {}
-- This is from SO, i forgot the link
---@param file string
---@return boolean
function M.exists(file)
    local ok, _, code = os.rename(file, file)
    if not ok then
        if code == 13 then
            -- Permission denied, but it exists
            return true
        end
    end
    if ok == nil then
        return false
    end
    return ok
end

---@param path string
---@return boolean
function M.isdir(path)
    -- "/" works on both Unix and Windows
    return M.exists(path .. "/")
end

---@param count number|nil
function M.importOldfiles(count)
    local oldfiles = vim.v.oldfiles
    M.refreshData()
    local d = M.getRawData()
    local time = require("spaceport.utils").getSeconds()
    local i = 1
    if d == nil then
        -- should never hapen but just in case
        log("Error getting spaceport data in importOldfiles (d is nil)")
        return
    end

    for _, v in pairs(oldfiles) do
        if d[v] == nil then
            d[v] = {
                time = time,
                isDir = M.isdir(v),
                pinNumber = 0,
            }
        end
        -- This sorts the oldfiles by time
        time = time - 1
        i = i + 1
        if count ~= nil and i > count then
            break
        end
    end
    M.writeData(d)
end

---@param d SpaceportRawData
---@return SpaceportRawData
local function sanitizeJsonData(d)
    local ret = {}
    for k, v in pairs(d) do
        if v.pinNumber == nil then
            v.pinNumber = 0
        end
        if v.time == nil then
            log("No time for " .. k .. " setting to current time")
            v.time = require("spaceport.utils").getSeconds()
        end
        if v.isDir == nil then
            log("No isDir for " .. k .. " setting to false")
            v.isDir = false
        end

        ret[k] = v
    end
    return ret
end


---@return SpaceportRawData
function M.readData()
    if not M.exists(dataDir) then
        local file = io.open(dataDir, "w")
        if file == nil then
            log("Can not create file at " .. dataDir .. "")
            print("Can not create file at " .. dataDir .. "")
            return {}
        end
        file:write(vim.json.encode({}))
        file:close()
        return {}
    end
    local file = io.open(dataDir, "r")
    if file == nil then
        return {}
    end
    local fileContents = file:read("*all")
    file:close()
    if fileContents == nil or fileContents == "" then
        fileContents = "{}"
        file = io.open(dataDir, "w")
        if file ~= nil then
            file:write(fileContents)
            file:close()
        end
    end
    local ret = vim.json.decode(fileContents, { object = true, array = true })
    ret = sanitizeJsonData(ret)
    if ret == nil then
        log("Error getting spaceport data")
        print("Error getting spaceport data")
        return {}
    end
    return ret
end

---@param dir string
function M.setCurrentDir(dir)
    -- M.refreshData()
    local d = M.getAllData()
    local found = false
    for _, v in pairs(d) do
        if v.dir == dir then
            currentDir = v
            found = true
            break
        end
    end
    if not found then
        print("Could not find " .. dir .. " in spaceport data")
    end
    M.doTmuxActions()
    vim.api.nvim_exec_autocmds("User", {
        pattern = "SpaceportDone",
        data = currentDir,
    })
end

---@param d SpaceportRawData
function M.writeData(d)
    local file = io.open(dataDir, "w")
    if file == nil then
        log("Can not create file at " .. dataDir .. "")
        print("Can not create file at " .. dataDir .. "")
        return
    end
    file:write(vim.json.encode(d))
    file:close()
end

function M.refreshData()
    data = {}
    pinnedData = {}
    rawData = M.readData()
    if rawData == nil then
        return
    end
    for k, v in pairs(rawData) do
        local insert = {
            dir = k,
            time = v.time,
            isDir = v.isDir,
            pinNumber = v.pinNumber,
            prettyDir = spaceport._fixDir(k),
            tmuxWindowName = v.tmuxWindowName,
            tmuxSessionName = v.tmuxSessionName,
        }
        if v.pinNumber == 0 then
            table.insert(data, insert)
        else
            table.insert(pinnedData, insert)
        end
    end
    table.sort(data, function(a, b)
        return a.time > b.time
    end)

    table.sort(pinnedData, function(a, b)
        return a.pinNumber < b.pinNumber
    end)
end

---@return SpaceportDir[]
function M.getAllData()
    local ret = {}
    for _, v in pairs(data) do
        table.insert(ret, v)
    end
    for _, v in pairs(pinnedData) do
        table.insert(ret, v)
    end
    table.sort(ret, function(a, b)
        return a.time > b.time
    end)
    return ret
end

---@return SpaceportDir[]
function M.getMruData()
    local ret = {}
    if require("spaceport")._getMaxRecentFiles() == 0 then
        return data
    end
    for i = 1, require("spaceport")._getMaxRecentFiles() do
        if data[i] == nil then
            break
        end
        table.insert(ret, data[i])
    end
    return ret
end

---@return SpaceportDir[]
function M.getAllMruData()
    return data
end

---@return SpaceportDir[]
function M.getPinnedData()
    return pinnedData
end

---@return SpaceportRawData
function M.getRawData()
    return rawData
end

---@param str string
function M.renameSession(str)
    M.refreshData()
    if currentDir == nil then
        print("No spaceport directory selected yet")
        return
    end
    currentDir.tmuxSessionName = str
    rawData[currentDir.dir].tmuxSessionName = currentDir.tmuxSessionName
    M.writeData(rawData)
    M.useSessionName()
end

---@param str string
function M.renameWindow(str)
    M.refreshData()
    if currentDir == nil then
        print("No spaceport directory selected yet")
        return
    end
    currentDir.tmuxWindowName = str
    if rawData[currentDir.dir] == nil then
        rawData[currentDir.dir] = {}
    end
    rawData[currentDir.dir].tmuxWindowName = currentDir.tmuxWindowName
    M.writeData(rawData)
    M.useWindowName()
end

-- Changes the window name to be the one in currentDir
function M.useWindowName()
    if currentDir == nil then
        print("No spaceport directory selected yet")
        return
    end
    if os.getenv("TMUX") == nil then
        print("Not in tmux")
        return
    end
    vim.fn.jobstart({ "tmux", "rename-window", currentDir.tmuxWindowName }, {
        on_exit = function()
        end,
    })
end

-- Changes the session name to be the one in currentDir
function M.useSessionName()
    if currentDir == nil then
        print("No spaceport directory selected yet")
        return
    end
    if os.getenv("TMUX") == nil then
        print("Not in tmux")
        return
    end
    vim.fn.jobstart({ "tmux", "rename-session", currentDir.tmuxSessionName }, {
        on_exit = function()
        end,
    })
end

-- Splits the window horizontally in tmux
function M.tmuxSplitWindowDown()
    if currentDir == nil then
        print("No spaceport directory selected yet")
        return
    end
    if os.getenv("TMUX") == nil then
        return
    end
    vim.fn.jobstart({ "tmux", "split-window", "-c" .. currentDir.dir }, {
        on_exit = function()
        end,
    })
end

-- Splits the window vertically in tmux
function M.tmuxSplitWindowLeft()
    if currentDir == nil then
        print("No spaceport directory selected yet")
        return
    end
    if os.getenv("TMUX") == nil then
        return
    end
    vim.fn.jobstart({ "tmux", "split-window", "-h", "-c" .. currentDir.dir }, {
        on_exit = function()
        end,
    })
end

-- Renames window and/or session if they are set
function M.doTmuxActions()
    if currentDir == nil then
        print("No spaceport directory selected yet")
        return
    end
    if currentDir.tmuxSessionName ~= nil then
        M.useSessionName()
    end
    if currentDir.tmuxWindowName ~= nil then
        M.useWindowName()
    end
end

---@param str string
function M.removeDir(str)
    local d = M.getRawData()
    if d == nil then
        M.refreshData()
        d = M.getRawData()
    end
    if d == nil then
        return
    end
    if d[str].pinNumber ~= 0 then
        local pin = d[str].pinNumber
        for _, v in pairs(d) do
            if v.pinNumber > pin then
                v.pinNumber = v.pinNumber - 1
            end
        end
    end
    d[str] = nil
    M.writeData(d)
end

---@param dir SpaceportDir
function M.cd(dir)
    if rawData[dir.dir] == nil then
        rawData[dir.dir] = {
            time = require("spaceport.utils").getSeconds(),
            isDir = dir.isDir,
            pinNumber = 0,
        }
    end
    rawData[dir.dir].time = require("spaceport.utils").getSeconds()
    M.writeData(rawData)
    local screens = require("spaceport.screen").getActualScreens()
    if dir.isDir then
        local ok, _ = pcall(vim.cmd.cd, dir.dir)
        if not ok then
            local answer = vim.fn.input(
                "It seems like "
                .. dir.dir
                .. " does not exist anymore, would you like it to be removed from spaceport? (y/n):"
            )
            if answer == "y" then
                M.removeDir(dir.dir)
                -- M.refreshData()
                require("spaceport.screen").render()
            end
            return
        end

        for _, screen in pairs(screens) do
            if screen.onExit ~= nil then
                screen.onExit()
            end
        end
        spaceport._projectEntryCommand()
    else
        local ok = M.exists(dir.dir)
        if not ok then
            local answer = vim.fn.input(
                "It seems like "
                .. dir.dir
                .. " does not exist anymore, would you like it to be removed from spaceport? (y/n):"
            )
            if answer == "y" then
                M.removeDir(dir.dir)
                -- M.refreshData()
                require("spaceport.screen").render()
            end
            return
        else
            for _, screen in pairs(screens) do
                if screen.onExit ~= nil then
                    screen.onExit()
                end
            end
            vim.cmd("edit " .. dir.dir)
        end
    end

    currentDir = dir
    M.doTmuxActions()
    vim.api.nvim_exec_autocmds("User", {
        pattern = "SpaceportDone",
        data = currentDir,
    })
end

return M
