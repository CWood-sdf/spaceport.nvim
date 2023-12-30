---@class (exact) SpaceportRemap
---@field key string
---@field mode string | string[]
---@field action string | fun(line: number, count: number)
---@field description string
---@field visible? boolean -- Is it visible in the remaps screen?
---@field callOutside? boolean -- Determines whether this acion can be called with the cursor outside of the viewport
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
---@field remaps? SpaceportRemap[]
---@field title? string | fun(): string
---@field topBuffer number
---@field position? SpaceportScreenPosition
---@field onExit? fun()
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
                local indexCopy = i
                vim.keymap.set(remap.mode, remap.key, function()
                    local line = (vim.fn.line(".") or 0) - startLineCopy - (v.topBuffer or 0) -
                        (v.title ~= nil and 1 or 0)
                    local callOutside = remap.callOutside
                    if callOutside == nil then
                        callOutside = true
                    end
                    -- print("sdfsf: " .. vim.inspect(callOutside))
                    if not callOutside and line > 0 and line <= viewport[indexCopy].rowEnd - viewport[indexCopy].rowStart + 1 then
                        remap.action(line, vim.v.count)
                        return
                    elseif callOutside then
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


---@param screen SpaceportScreen
---@param gridLines SpaceportWord[][]
---@param centerRow number
---@return SpaceportWord[][],  SpaceportViewport
local function renderGrid(screen, gridLines, centerRow)
    --Make startCol max length, bc it will be minimized later
    local i = 0
    ---@type (SpaceportWord[]|string)[]
    local lines = {}

    -- add top buffer
    local topBuffer = screen.topBuffer or 0
    while i < topBuffer do
        table.insert(lines, {})
        i = i + 1
    end

    -- render title
    if screen.title ~= nil then
        ---@type string|fun(): string
        local title = screen.title
        if type(title) == "function" then
            title = title()
        end
        table.insert(lines, { { title } })
    end

    --render lines
    local screenLines = screen.lines
    if type(screenLines) == "function" then
        screenLines = screenLines()
    end
    for _, line in ipairs(screenLines) do
        table.insert(lines, line)
    end

    local maxHeight = #lines
    local maxWidth = 0
    for _, l in ipairs(lines) do
        local len = #M.wordArrayToString(l)
        if len > maxWidth then
            maxWidth = len
        end
    end
    local row = nil
    local col = nil

    -- just make it so that the row and col arent negative
    if screen.position ~= nil then
        row = screen.position.row
        col = screen.position.col
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
    else
        row = centerRow
    end

    local startRow = row
    local startCol = col
    local endCol = 0
    if col == nil then
        -- col is nil when position is nil, so we have to get the startCol as half the max width from the center
        startCol = math.floor((vim.api.nvim_win_get_width(0) - maxWidth) / 2)
        -- endCol is the last column that is rendered
        endCol = startCol + maxWidth - 1
    else
        endCol = col + maxWidth - 1
    end

    -- make it so that the gridLines is big enough to fit everything
    while #gridLines < startRow + maxHeight do
        local newLine = {}
        while #newLine < width - 2 do
            table.insert(newLine, { " " })
        end
        table.insert(gridLines, newLine)
    end

    local currentRow = startRow
    for _, line in ipairs(lines) do
        local newLine = gridLines[currentRow + 1]
        local words = M.rowToWordArray(line)

        if screen.position == nil then
            words = M.centerWords(words)
        end
        local spot = 1
        if screen.position ~= nil then
            spot = startCol or 1
        end
        for _, w in ipairs(words) do
            local colorOpts = w.colorOpts
            for q = 1, #w[1] do
                local char = w[1]:sub(q, q)
                -- basically don't have the buffer spaces overriding actual text beneath it
                if (spot < startCol or char == " ") and screen.position == nil then
                    spot = spot + 1
                    goto continue
                end
                if colorOpts ~= nil then
                    newLine[spot] = { char, colorOpts = colorOpts }
                else
                    newLine[spot] = { char }
                end
                spot = spot + 1
                :: continue ::
            end
        end
        gridLines[currentRow + 1] = newLine
        currentRow = currentRow + 1
        -- table.insert(lines, words)
    end
    return gridLines, {
        rowStart = startRow,
        rowEnd = currentRow - 1,
        colStart = startCol,
        colEnd = endCol,
    }
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
    if hlNs ~= nil then
        vim.api.nvim_buf_clear_namespace(0, hlNs, 0, -1)
        hlNs = nil
    end
    hlId = 0
    hlNs = vim.api.nvim_create_namespace("Spaceport")
    vim.api.nvim_win_set_hl_ns(0, hlNs)
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
    vim.api.nvim_set_current_buf(buf)
    vim.cmd("setlocal norelativenumber nonumber")
    -- local totalTime = 0
    local centerRow = 0
    for index, v in ipairs(screens) do
        gridLines, remapsViewport[index] = renderGrid(v, gridLines, centerRow)
        if v.position == nil then
            centerRow = remapsViewport[index].rowEnd + 1
        end
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
                local optsStr = vim.inspect(word.colorOpts)
                if usedHighlights[optsStr] ~= nil then
                    hlGroup = usedHighlights[optsStr]
                else
                    hlGroup = "spaceport_hl_" .. hlId
                    vim.api.nvim_set_hl(hlNs, hlGroup, word.colorOpts)
                    hlId = hlId + 1
                    usedHighlights[optsStr] = hlGroup
                end
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
end

return M
