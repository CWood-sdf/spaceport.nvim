---@class (exact) SpaceportRemap
---@field key string
---@field mode string | string[]
---@field action string | fun(line: number, count: number)
---@field description string
---@field visible boolean|nil
---@field callOutside boolean | nil
local SpaceportRemap = {}

--This is supposed to be able to allow highlighting of words
---@class (exact) SpaceportWord
---@field [1] string
---@field colorOpts table | nil

---@class (exact) SpaceportScreenPosition
---@field row number
---@field col number

---@class (exact) SpaceportScreen
---@field lines (string|SpaceportWord[])[] | (fun(): (string|SpaceportWord[])[]) | (fun(): string[]) | (fun(): SpaceportWord[][])
---@field remaps SpaceportRemap[] | nil
---@field title string | nil | fun(): string
---@field topBuffer number
---@field position SpaceportScreenPosition | nil
---@field onExit fun() | nil
local SpaceportScreen = {}

local M = {}

local buf = nil
local width = 0
local hlNs = nil
local hlId = 0
local log = require("spaceport").log
function M.isRendering()
    return buf ~= nil and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf
end

---@return SpaceportScreen[]
function M.getActualScreens()
    log("spaceport.screen.getActualScreens()")
    local configScreens = require("spaceport")._getSections()
    ---@type SpaceportScreen[]
    local screens = {}
    for _, screen in ipairs(configScreens) do
        if type(screen) == "string" then
            log("screen: " .. screen)
            local ok, s = pcall(require, "spaceport.screens." .. screen)
            if not ok then
                log("Invalid screen: " .. screen)
                error("Invalid screen: " .. screen)
            end
            screen = s
        end
        table.insert(screens, screen)
    end
    return screens
end

---@return string
---@param str string
---@param w? number
function M.centerString(str, w)
    w = w or width
    local len = #str
    local pad = math.floor((w - len) / 2)
    return string.rep(" ", pad) .. str
end

---@return SpaceportWord[]
---@param arr SpaceportWord[]
---@param w? number
function M.centerWords(arr, w)
    w = w or width
    local len = 0
    for _, v in pairs(arr) do
        len = len + #v[1]
    end
    local pad = math.floor((w - len) / 2)
    ---@type SpaceportWord[]
    local ret = {}
    table.insert(ret, { string.rep(" ", pad) })
    for _, v in pairs(arr) do
        table.insert(ret, v)
    end
    return ret
end

---@return string|SpaceportWord[]
---@param row string|SpaceportWord[]
function M.centerRow(row)
    if type(row) == "string" then
        return M.centerString(row)
    else
        return M.centerWords(row)
    end
end

---@return string
---@param str string[]
---@param w number
---@param ch? string
---Concats two strings to be a certain width by inserting spaces between them
function M.setWidth(str, w, ch)
    ch = ch or " "
    local len = #str[1] + #str[2]
    local pad = w - len
    local ret = ""
    ret = ret .. str[1] .. string.rep(ch, pad) .. str[2]
    return ret
end

---@return string
---@param line SpaceportWord[]|string
function M.wordArrayToString(line)
    if type(line) == "string" then
        return line
    end
    local ret = ""
    for _, v in ipairs(line) do
        ret = ret .. v[1]
    end
    return ret
end

---@return SpaceportWord[]
---@param words SpaceportWord[]
---@param w number
---@param ch? string
function M.setWidthWords(words, w, ch)
    ch = ch or " "
    ---@type SpaceportWord[]
    local ret = {}
    local left = words[1]
    local right = words[2]
    local leftLen = #left[1]
    local rightLen = #right[1]
    local pad = w - (leftLen + rightLen)
    local spaces = string.rep(ch, pad)
    ret[1] = words[1]
    ret[2] = { spaces }
    ret[3] = words[2]
    return ret
end

---@return SpaceportWord[]
---@param row string|SpaceportWord[]
function M.rowToWordArray(row)
    ---@type SpaceportWord[]
    local ret = {}
    if type(row) == "string" then
        ret = { { row } }
    else
        ret = row
    end
    return ret
end

local needsRemap = true

---@param viewport SpaceportViewport[]
local function setRemaps(viewport)
    require("spaceport.data").refreshData()
    local screens = M.getActualScreens()

    -- local startLine = 0
    for i, v in ipairs(screens) do
        for _, remap in ipairs(v.remaps or {}) do
            if type(remap.action) == "function" then
                local startLineCopy = viewport[i].rowStart
                vim.keymap.set(remap.mode, remap.key, function()
                    local line = (vim.fn.line(".") or 0) - startLineCopy
                    local callOutside = remap.callOutside or true
                    if not callOutside and line > 0 and line <= viewport[i].rowStart - viewport[i].rowEnd then
                        remap.action(line, vim.v.count)
                        return
                    end
                    if callOutside then
                        remap.action(line, vim.v.count)
                    end
                end, {
                    silent = true,
                    buffer = true,
                })
            else
                vim.keymap.set(remap.mode, remap.key, remap.action, {
                    silent = true,
                    buffer = true,
                })
            end
        end
        -- startLine = startLine + v.topBuffer + (v.title ~= nil and 1 or 0) + #lines
    end
end
---@class (exact) SpaceportViewport
---@field rowStart number
---@field rowEnd number
---@field colStart number
---@field colEnd number

function M.render()
    ---@type SpaceportWord[][]
    local gridLines = {}
    ---@type table<integer, SpaceportViewport>
    local remapsViewport = {}
    require("spaceport.data").refreshData()
    -- local startTime = vim.loop.hrtime()
    if hlNs ~= nil then
        vim.api.nvim_buf_clear_namespace(0, hlNs, 0, -1)
        hlNs = nil
    end
    hlId = 0
    -- if hlNs == nil then
    hlNs = vim.api.nvim_create_namespace("Spaceport")
    vim.api.nvim_win_set_hl_ns(0, hlNs)
    -- end
    width = vim.api.nvim_win_get_width(0)

    local screens = M.getActualScreens()
    if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
        buf = vim.api.nvim_create_buf(false, true)
        needsRemap = true
    end
    vim.api.nvim_set_option_value("buftype", "nofile", {
        buf = buf,
    })
    vim.api.nvim_set_option_value("bufhidden", "wipe", {
        buf = buf,
    })
    vim.api.nvim_set_option_value("swapfile", false, {
        buf = buf,
    })
    -- vim.api.nvim_buf_set_option(buf, "number", false)
    vim.api.nvim_set_current_buf(buf)
    vim.cmd("setlocal norelativenumber nonumber")
    -- local totalTime = 0
    for index, v in ipairs(screens) do
        if v.position ~= nil then
            goto continue
        end
        local startRow = #gridLines
        --Make startCol max length, bc it will be minimized later
        local startCol = width
        local endCol = 0
        local i = 0
        while i < v.topBuffer do
            -- table.insert(actualLines, string.rep(" ", width - 2))
            -- table.insert(lines, { { string.rep(" ", width - 2) } })
            local newLine = {}
            for _ = 1, width - 2 do
                table.insert(newLine, { " " })
            end
            table.insert(gridLines, newLine)
            i = i + 1
        end
        if v.title ~= nil then
            local newLine = {}
            for _ = 1, width - 2 do
                table.insert(newLine, { " " })
            end

            ---@type string|fun(): string
            local title = v.title
            if type(title) == "function" then
                title = title()
            end
            local centered = M.centerString(title)
            local extra = string.rep(" ", width - #centered - 2)
            if #extra < startCol then
                startCol = #extra
            end
            if #extra + #centered > endCol then
                endCol = #extra + #centered
            end
            for q = 1, #centered do
                newLine[q] = { centered:sub(q, q) }
            end
            table.insert(gridLines, newLine)
            centered = centered .. extra
            -- table.insert(actualLines, centered)
            local centeredWords = M.centerWords({ { title } })
            centeredWords[#centeredWords + 1] = { extra }
            -- table.insert(lines, centeredWords)
        end
        local screenLines = v.lines
        if type(screenLines) == "function" then
            -- local start = vim.loop.hrtime()
            screenLines = screenLines()
            -- totalTime = totalTime + (vim.loop.hrtime() - start) / 1000000
        end
        ---@cast screenLines (string|SpaceportWord[])[]
        for _, line in ipairs(screenLines) do
            local newLine = {}
            for _ = 1, width - 2 do
                table.insert(newLine, { " " })
            end
            -- local centeredString = M.centerString(M.wordArrayToString(line))
            -- centeredString = centeredString .. string.rep(" ", width - #centeredString - 2)
            -- table.insert(actualLines, centeredString)
            local words = M.rowToWordArray(line)
            words = M.centerWords(words)
            local extra = string.rep(" ", width - #M.wordArrayToString(words) - 2)
            if #extra < startCol then
                startCol = #extra
            end
            if #extra + #M.wordArrayToString(words) > endCol then
                endCol = #extra + #M.wordArrayToString(words)
            end
            words[#words + 1] = { extra }
            local spot = 1
            for _, w in ipairs(words) do
                local colorOpts = w.colorOpts
                for q = 1, #w[1] do
                    if colorOpts ~= nil then
                        newLine[spot] = { w[1]:sub(q, q), colorOpts = colorOpts }
                    else
                        newLine[spot] = { w[1]:sub(q, q) }
                    end
                    spot = spot + 1
                end
            end
            table.insert(gridLines, newLine)
            -- table.insert(lines, words)
        end
        local endRow = #gridLines
        remapsViewport[index] = {
            rowStart = startRow,
            rowEnd = endRow,
            colStart = startCol,
            colEnd = endCol,
        }
        :: continue ::
    end
    while #gridLines < vim.api.nvim_win_get_height(0) do
        -- table.insert(actualLines, string.rep(" ", width - 2))
        local newLine = {}
        while #newLine < width - 2 do
            table.insert(newLine, { " " })
        end
        table.insert(gridLines, newLine)
    end
    -- print((vim.loop.hrtime() - startTime) / 1000000 .. "ms")
    -- print("Total time: " .. totalTime .. "ms")
    for index, v in ipairs(screens) do
        if v.position == nil then
            goto continue
        end
        local tempLines = {}
        if v.title ~= nil then
            ---@type string|fun(): string
            local title = v.title
            if type(title) == "function" then
                title = title()
            end
            local centeredWords = { { title } }
            table.insert(tempLines, centeredWords)
        end
        local screenLines = v.lines
        if type(screenLines) == "function" then
            screenLines = screenLines()
        end
        ---@cast screenLines (string|SpaceportWord[])[]
        for _, line in ipairs(screenLines) do
            -- local centeredString = M.centerString(M.wordArrayToString(line))
            -- centeredString = centeredString .. string.rep(" ", width - #centeredString - 2)
            local words = M.rowToWordArray(line)
            -- words = M.centerWords(words)
            -- local extra = string.rep(" ", width - #M.wordArrayToString(words) - 2)
            -- words[#words + 1] = { extra }
            table.insert(tempLines, words)
        end
        local maxWidth = 0
        for _, l in ipairs(tempLines) do
            local len = #M.wordArrayToString(l)
            if len > maxWidth then
                maxWidth = len
            end
        end
        local maxHeight = #tempLines
        local row = v.position.row
        local col = v.position.col
        if row < 0 then
            row = vim.api.nvim_win_get_height(0) + row - maxHeight + 1
        end
        if row < 0 then
            print("row < 0")
        end
        if row + maxHeight > vim.api.nvim_win_get_height(0) then
            row = vim.api.nvim_win_get_height(0) - maxHeight + 1
        end
        if col < 0 then
            col = vim.api.nvim_win_get_width(0) + col - maxWidth - 1
        end
        if col < 0 then
            print("col < 0")
        end
        if col + maxWidth > vim.api.nvim_win_get_width(0) then
            col = vim.api.nvim_win_get_width(0) - maxWidth
        end
        local startRow = row
        local startCol = col
        local endRow = row + maxHeight - 1
        local endCol = col + maxWidth - 1
        local i = 1
        for r = row, row + maxHeight - 1 do
            local words = M.rowToWordArray(tempLines[i])

            local c = startCol
            for _, w in ipairs(words) do
                local colorOpts = w.colorOpts
                for q = 1, #w[1] do
                    if colorOpts ~= nil then
                        gridLines[r + 1][c] = { w[1]:sub(q, q), colorOpts = colorOpts }
                    else
                        gridLines[r + 1][c] = { w[1]:sub(q, q) }
                    end
                    c = c + 1
                end
            end
            i = i + 1
        end
        remapsViewport[index] = {
            rowStart = startRow,
            rowEnd = endRow,
            colStart = startCol,
            colEnd = endCol,
        }

        :: continue ::
    end
    vim.api.nvim_set_option_value("modifiable", true, {
        buf = buf,
    })
    local lines2 = {}
    for _, v in ipairs(gridLines) do
        table.insert(lines2, M.wordArrayToString(v))
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines2)
    vim.api.nvim_set_option_value("modifiable", false, {
        buf = buf,
    })

    local row = 0
    local col = 0
    ---@type table<string, string>
    local usedHighlights = {}
    for _, v in ipairs(gridLines) do
        for _, word in ipairs(v) do
            if word.colorOpts ~= nil then
                local hlGroup = ""
                -- print("hlGroup: " .. hlGroup)
                if usedHighlights[vim.inspect(word.colorOpts)] ~= nil then
                    hlGroup = usedHighlights[vim.inspect(word.colorOpts)]
                else
                    hlGroup = "spaceport_hl_" .. hlId
                    vim.api.nvim_set_hl(hlNs, hlGroup, word.colorOpts)
                    hlId = hlId + 1
                    usedHighlights[vim.inspect(word.colorOpts)] = hlGroup
                end
                -- print("highlighting yo")
                -- print(buf, hlNs, hlGroup, row, col, col + #word[1])
                --2 4 1 62 98
                vim.api.nvim_buf_add_highlight(buf, hlNs, hlGroup, row, col, col + #word[1])
            end
            col = col + #word[1]
        end
        col = 0
        row = row + 1
    end
    if needsRemap then
        setRemaps(remapsViewport)
        needsRemap = false
    end
    -- local endTime = vim.loop.hrtime()
    -- print("Render time: " .. (endTime - startTime) / 1000000 .. "ms")
end

return M
