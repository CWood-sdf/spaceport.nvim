local linesToDir = {}
local mru
local pinned
---@param config { [string]: any }
---@return (string|SpaceportWord[])[]
local function l(config)
    mru = require("spaceport.data").getMruData()
    pinned = require("spaceport.data").getPinnedData()
    if require("spaceport")._getMaxRecentFiles() ~= 0 then
        local tmpMru = {}
        local i = 1
        while #tmpMru + #pinned < require("spaceport")._getMaxRecentFiles() and #mru > 0 and #tmpMru < #mru do
            table.insert(tmpMru, mru[i])
            i = i + 1
        end
        mru = tmpMru
    end
    -- error("asdf")
    local lastView = require("spaceport").getConfig().lastViewTime
    ---@type (string|SpaceportWord[])[]
    local lines = {}
    local i = 1
    local largestLen = 0
    for _, v in ipairs(mru) do
        local len = #v.prettyDir + #(i .. "")
        if len > largestLen then
            largestLen = len
        end
    end
    for _, v in ipairs(pinned) do
        local len = #v.prettyDir + #(i .. "")
        if len > largestLen then
            largestLen = len
        end
    end
    largestLen = largestLen + 10
    if #pinned > 0 then
        lines = {
            "",
            { { require("spaceport")._getIcon("pinned") .. "Pinned", colorOpts = { _name = "SpaceportRecentsTitle" } } },
        }
        for _, v in ipairs(pinned) do
            linesToDir[#lines+1] = i
            local prefix = require("spaceport")._getIcon("file")
            if v.isDir then prefix = require("spaceport")._getIcon("dir") end
            ---@type SpaceportWord[]
            local words = {
                { prefix .. v.prettyDir, colorOpts = { _name = "SpaceportRecentsProject" } },
                { i .. "",               colorOpts = { _name = "SpaceportRecentsCount" } },
            }
            table.insert(lines,
                require("spaceport.screen").setWidthWords(words, largestLen))
            i = i + 1
        end
    end
    if lastView == "pin" then
        return lines
    end
    local currentTime = ""
    local utils = require("spaceport.utils")
    for _, v in pairs(mru) do
        if utils.isToday(v.time) then
            if currentTime ~= "Today" then
                currentTime = "Today"
                lines[#lines+1] = ""
                lines[#lines+1] = {
                    { require("spaceport")._getIcon("today") .. currentTime, colorOpts = { _name = "SpaceportRecentsTitle" } },
                }
                -- addLine(lines, currentTime, width)
            end
        elseif utils.isYesterday(v.time) then
            if currentTime ~= "Yesterday" then
                currentTime = "Yesterday"
                if lastView == "today" then
                    return lines
                end
                lines[#lines+1] = ""
                lines[#lines+1] = {
                    { require("spaceport")._getIcon("yesterday") .. currentTime, colorOpts = { _name = "SpaceportRecentsTitle" } },
                }
            end
        elseif utils.isPastWeek(v.time) then
            if currentTime ~= "Past Week" then
                currentTime = "Past Week"
                if lastView == "today" or lastView == "yesterday" then
                    return lines
                end
                lines[#lines+1] = ""
                lines[#lines+1] = {
                    { require("spaceport")._getIcon("week") .. currentTime, colorOpts = { _name = "SpaceportRecentsTitle" } },
                }
            end
        elseif utils.isPastMonth(v.time) then
            if currentTime ~= "Past Month" then
                currentTime = "Past Month"
                if lastView == "today" or lastView == "yesterday" or lastView == "pastWeek" then
                    return lines
                end
                lines[#lines+1] = ""
                lines[#lines+1] = {
                    { require("spaceport")._getIcon("month") .. currentTime, colorOpts = { _name = "SpaceportRecentsTitle" } },
                }
            end
        else
            if currentTime ~= "A long time ago" then
                currentTime = "A long time ago"
                if
                    lastView == "today"
                    or lastView == "yesterday"
                    or lastView == "pastWeek"
                    or lastView == "pastMonth"
                then
                    return lines
                end
                lines[#lines+1] = ""
                lines[#lines+1] = {
                    { require("spaceport")._getIcon("long") .. currentTime, colorOpts = { _name = "SpaceportRecentsTitle" } },
                }
            end
        end
        linesToDir[#lines+1] = i
        local prefix = require("spaceport")._getIcon("file")
        if v.isDir then prefix = require("spaceport")._getIcon("dir") end
        local words = {
            { prefix .. v.prettyDir, colorOpts = { _name = "SpaceportRecentsProject" } },
            { i .. "",               colorOpts = { _name = "SpaceportRecentsCount" } },
        }
        local line = require("spaceport.screen").setWidthWords(words, largestLen)
        table.insert(lines, line)
        i = i + 1
    end
    return lines
end

---@type SpaceportScreen
local r = {
    lines = l,
    remaps = {
        {
            key = "p",
            description = "Select project",
            action = function (line, count)
                if count == 0 then
                    count = linesToDir[line] or 0
                end
                if count ~= 0 then
                    if count <= #pinned then
                        require("spaceport.data").cd(pinned[count])
                        return
                    end
                    if count <= #pinned + #mru then
                        require("spaceport.data").cd(mru[count - #pinned])
                        return
                    end
                    print("Invalid number")
                else
                    print("Not hovering over a project")
                end
            end,
            mode = "n",
        },
        {
            key = "dd",
            description = "Delete project",
            action = function (line, count)
                if count == 0 then
                    count = linesToDir[line]
                end
                if count ~= 0 then
                    local data = require("spaceport.data").getRawData()
                    if count <= #pinned then
                        local d = pinned[count].dir
                        require("spaceport.data").removeDir(d)
                        require("spaceport.screen").render()
                    else
                        local d = mru[count - #pinned].dir
                        require("spaceport.data").removeDir(d)
                        require("spaceport.screen").render()
                    end
                else
                    print("Not hovering over a project")
                end
            end,
            mode = "n",
        },
        {
            key = "t",
            description = "Toggle project tag",
            action = function (line, count)
                if count == 0 then
                    count = linesToDir[line]
                end
                if count ~= 0 then
                    local data = require("spaceport.data").getRawData()
                    if count <= #pinned then
                        local d = pinned[count].dir
                        for k, _ in pairs(data) do
                            if k == d then
                                data[k].pinNumber = 0
                                require("spaceport.data").writeData(data)
                                require("spaceport.screen").render()
                                return
                            end
                        end
                        require("spaceport.screen").render()
                    else
                        local d = mru[count - #pinned].dir
                        local maxPin = 0
                        for _, v in pairs(data) do
                            if v.pinNumber > maxPin then
                                maxPin = v.pinNumber
                            end
                        end
                        for k, _ in pairs(data) do
                            if k == d then
                                data[k].pinNumber = maxPin + 1
                                require("spaceport.data").writeData(data)
                                require("spaceport.screen").render()
                                return
                            end
                        end
                    end
                else
                    print("Not hovering over a project")
                end
            end,
            mode = "n",
        },
        {
            key = "J",
            description = "Move pin down",
            mode = "n",
            action = function (line, count)
                line = linesToDir[line]
                if line == nil then
                    print("Not hovering over a project")
                    return
                end
                if count == 0 then
                    count = 1
                end
                local data = require("spaceport.data").getRawData()
                if line > #pinned then
                    print("Not hovering over a pinned project")
                    return
                end
                -- print("line: " .. line)
                -- print("count: " .. count)
                local upperBound = line + count
                local lowerBound = line
                -- print("upperBound: " .. upperBound)
                -- print("lowerBound: " .. lowerBound)
                if lowerBound > #pinned then
                    lowerBound = #pinned
                end
                -- print(vim.inspect(pinned))
                for i = upperBound, lowerBound, -1 do
                    pinned[i].pinNumber = pinned[i].pinNumber - 1
                    data[pinned[i].dir].pinNumber = pinned[i].pinNumber
                end
                pinned[line].pinNumber = upperBound
                data[pinned[line].dir].pinNumber = upperBound
                -- print(vim.inspect(pinned))
                require("spaceport.data").writeData(data)

                require("spaceport.screen").render()
            end,
        },
        {
            key = "K",
            description = "Move pin up",
            mode = "n",
            action = function (line, count)
                line = linesToDir[line]
                if line == nil then
                    print("Not hovering over a project")
                    return
                end
                if count == 0 then
                    count = 1
                end
                local data = require("spaceport.data").getRawData()
                if line > #pinned then
                    print("Not hovering over a pinned project")
                    return
                end
                -- print("line: " .. line)
                -- print("count: " .. count)
                local upperBound = line
                local lowerBound = line - count
                -- print("upperBound: " .. upperBound)
                -- print("lowerBound: " .. lowerBound)
                if lowerBound < 1 then
                    lowerBound = 1
                end

                -- print(vim.inspect(pinned))
                for i = upperBound, lowerBound, -1 do
                    pinned[i].pinNumber = pinned[i].pinNumber + 1
                    data[pinned[i].dir].pinNumber = pinned[i].pinNumber
                end
                pinned[line].pinNumber = lowerBound
                data[pinned[line].dir].pinNumber = pinned[line].pinNumber
                -- print(vim.inspect(pinned))
                require("spaceport.data").writeData(data)

                require("spaceport.screen").render()
            end,
        },
    },
    title = nil,
    topBuffer = 0,
}
return r
