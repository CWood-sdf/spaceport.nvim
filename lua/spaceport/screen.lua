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
---@field config? { [string]: any }
---@field lines (string|SpaceportWord[])[] | (fun(config?: { [string]: any }): (string|SpaceportWord[])[]) | (fun(config?: { [string]: any }): string[]) | (fun(config?: { [string]: any }): SpaceportWord[][])
---@field remaps? SpaceportRemap[]
---@field title? string | fun(): string
---@field topBuffer? number
---@field position? SpaceportScreenPosition
---@field onExit? fun()
local SpaceportScreen = {}

local M = {}
local winid = 0

local log = require("spaceport").log

-- Sanitize functions {
---@param remap SpaceportRemap
local function sanitizeRemap(remap)
    if remap.mode == nil then
        log("Invalid remap: " .. vim.inspect(remap))
    elseif remap.key == nil then
        log("Invalid remap: " .. vim.inspect(remap))
    elseif remap.action == nil then
        log("Invalid remap: " .. vim.inspect(remap))
    elseif remap.description == nil then
        log("Invalid remap: " .. vim.inspect(remap))
    else
        return true
    end
    return false
end
local function sanitizeScreenPosition(pos)
    if pos.row == nil then
        log("Invalid screen position: " .. vim.inspect(pos))
    elseif pos.col == nil then
        log("Invalid screen position: " .. vim.inspect(pos))
    else
        return true
    end
    return false
end
---@param ignoreFn boolean
local function sanitizeLines(lines, ignoreFn)
    if lines == nil then
        return false
    end
    if type(lines) == "function" and ignoreFn then
        -- Can't sanitize functions bc we get stack overflow
        return true
    end
    if type(lines) ~= "table" then
        log("Invalid lines: " .. vim.inspect(lines))
        return false
    end
    for _, line in ipairs(lines) do
        if type(line) == "string" then
            -- pass
        elseif type(line) == "table" then
            --- line is SpaceportWord[]
            for _, word in ipairs(line) do
                -- word is SpaceportWord
                if type(word) == "table" then
                    word = word ---@as SpaceportWord
                    if word[1] == nil then
                        log("Invalid word: " .. vim.inspect(word))
                        return false
                    end
                    if type(word[1]) ~= "string" then
                        log("Invalid word: " .. vim.inspect(word))
                        return false
                    end
                else
                    log("Invalid word: " .. vim.inspect(word))
                    return false
                end
            end
        else
            log("Invalid line: " .. vim.inspect(line))
            return false
        end
    end
    return true
end
local function sanitizeScreen(screen)
    if not sanitizeLines(screen.lines, true) then
        log("Invalid screen: " .. vim.inspect(screen))
        return false
    elseif screen.remaps ~= nil then
        for _, remap in ipairs(screen.remaps) do
            if not sanitizeRemap(remap) then
                return false
            end
        end
    elseif screen.position ~= nil then
        if not sanitizeScreenPosition(screen.position) then
            return false
        end
    end
    return true
end
-- }

local buf = nil
local width = 0
local height = 0
local hlNs = nil
local hlId = 0
local isExiting = false
function M.isRendering()
    return buf ~= nil and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf and not isExiting
end

function M.exit()
    isExiting = true
    if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, {
            force = true,
        })
    end
    buf = nil
end

-- Helper functions {

-- Returns the length in bytes of the utf8 character
-- Copilot wrote this and it actually works :O
local function codepointLen(utf8Char)
    if utf8Char:byte() < 128 then
        return 1
    elseif utf8Char:byte() < 224 then
        return 2
    elseif utf8Char:byte() < 240 then
        return 3
    else
        return 4
    end
end


---@param str string
---@return number
local function utf8Len(str)
    local len = 0
    local i = 1
    while i <= #str do
        local c = str:sub(i, i)
        local inc = 1
        len = len + 1
        if c:byte() < 128 then
            inc = 1
        elseif c:byte() < 224 then
            inc = 2
        elseif c:byte() < 240 then
            inc = 3
        else
            inc = 4
        end
        i = i + inc
    end
    return len
end
---@type SpaceportScreen[]?
local screenCache = nil
---@return SpaceportScreen[]
function M.getActualScreens()
    if screenCache ~= nil then
        return screenCache
    end
    -- log("spaceport.screen.getActualScreens()")
    local configScreens = require("spaceport")._getSections()
    ---@type SpaceportScreen[]
    local screens = {}
    local unfoundRemaps = {}
    local remapKeys = {}
    for _, screen in ipairs(configScreens) do
        ---@type SpaceportScreen
        local conf
        if type(screen) == "string" then
            -- log("screen: " .. screen)
            local ok, s = pcall(require, "spaceport.screens." .. screen)
            if not ok then
                log("Invalid screen (require not found): " .. screen)
            end
            ---@cast s SpaceportScreen
            conf = s
            for _, v in ipairs(s.remaps or {}) do
                remapKeys[v.key] = screen
            end
        elseif type(screen) == "function" then
            conf = screen()
        else
            if screen[1] ~= nil and type(screen[1]) == "string" then
                ---@type boolean, SpaceportScreen
                local ok, s = pcall(require, "spaceport.screens." .. screen[1])
                if not ok then
                    log("Invalid screen (require not found): " .. screen[1])
                end
                conf = s
                ---@diagnostic disable-next-line: cast-type-mismatch
                ---@cast screen SpaceportScreenConfig
                for k, v in pairs(screen) do
                    if tonumber(k) ~= nil then
                        goto continue
                    end
                    if k == "remaps" or k == "lines" then
                        goto continue
                    end
                    conf[k] = v
                    ::continue::
                end
                for _, v in ipairs(s.remaps or {}) do
                    remapKeys[v.key] = screen[1]
                end
                if screen.remaps ~= nil then
                    for _, v in ipairs(screen.remaps) do
                        if v.ogkey ~= nil then
                            local found = false
                            for i, r in ipairs(conf.remaps) do
                                if r.key == v.ogkey then
                                    found = true
                                    for k, val in pairs(v) do
                                        r[k] = val
                                    end
                                    if v.key == "" then
                                        table.remove(conf.remaps, i)
                                    end
                                    break
                                end
                            end
                            if not found then
                                table.insert(unfoundRemaps, v.ogkey)
                            end
                        else
                            table.insert(conf.remaps, v)
                        end
                    end
                end
            else
                conf = screen
            end
        end
        if sanitizeScreen(conf) then
            table.insert(screens, conf)
        else
            table.insert(screens, {
                lines = {
                    "Invalid screen",
                },
                remaps = {},
                title = nil,
                topBuffer = 0,
            })
        end
    end
    for _, v in ipairs(unfoundRemaps) do
        local msg = "Could not modify remap with key '" .. v .. "'"
        if remapKeys[v] ~= nil then
            msg = msg .. " (Note: remap key was found in section '" .. remapKeys[v] .. "')"
        else
            msg = msg ..
                " (Note: could not find any remap in a named section with that key, perhaps you meant to make a new map. If that's the case, replace `ogkey` with `key`)"
        end
        msg = msg .. "\n"
        vim.notify(msg)
    end
    screenCache = screens
    return screens
end

-- }


-- Word/string manipulation functions {
---@return string
---@param str string
---@param w? number
function M.centerString(str, w)
    w = w or width
    local len = utf8Len(str)
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
        len = len + utf8Len(v[1])
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
    local len = utf8Len(str[1]) + utf8Len(str[2])
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

---@return number
---@param line string|SpaceportWord[]
function M.wordArrayUtf8Len(line)
    if type(line) == "string" then
        return utf8Len(line)
    end
    local ret = 0
    for _, v in ipairs(line) do
        ret = ret + utf8Len(v[1])
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
    local leftLen = utf8Len(left[1])
    local rightLen = utf8Len(right[1])
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

-- }

local needsRemap = true

---@param viewport SpaceportViewport[]
---@param screens SpaceportScreen[]
local function setRemaps(viewport, screens)
    require("spaceport.data").refreshData()
    -- local screens = M.getActualScreens()

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
                    buffer = buf,
                })
            else
                vim.keymap.set(remap.mode, remap.key, remap.action, {
                    silent = true,
                    buffer = buf,
                })
            end
        end
        -- startLine = startLine + v.topBuffer + (v.title ~= nil and 1 or 0) + #lines
    end
    for _, v in ipairs(require('spaceport').getConfig().shortcuts) do
        -- print("Setting shortcut " .. v .. " to index " .. i)
        if type(v) ~= "table" then
            log("Invalid shortcut: " .. vim.inspect(v) .. " expected string[2]")
            goto continue
        end
        if type(v[1]) ~= "string" then
            log("Invalid shortcut: " .. vim.inspect(v) .. " expected string[2]")
            return
        end
        if type(v[2]) ~= "string" then
            log("Invalid shortcut: " .. vim.inspect(v) .. " expected string[2]")
            return
        end
        -- Basically, if its a table, then first key is key, second is a match to a directory
        vim.keymap.set("n", v[1], function()
            local pinned = require("spaceport.data").getPinnedData()
            for _, dir in ipairs(pinned) do
                if string.match(dir.dir, v[2]) then
                    require('spaceport.data').cd(dir)
                    return
                end
            end
            local mru = require("spaceport.data").getMruData()
            for _, dir in ipairs(mru) do
                if string.match(dir.dir, v[2]) then
                    require('spaceport.data').cd(dir)
                    return
                end
            end
        end, {
            desc = "Spaceport shortcut to " .. v[2],
            silent = true,
            buffer = buf,
        })
        ::continue::
    end
end


---@param screen SpaceportScreen
---@param gridLines SpaceportWord[][]
---@param centerRow number
---@return SpaceportWord[][], SpaceportViewport
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
        screenLines = screenLines(screen.config)
        if not sanitizeLines(screenLines, false) then
            screenLines = { "Invalid screen" }
        end
    end
    for _, line in ipairs(screenLines) do
        table.insert(lines, line)
    end

    local maxHeight = #lines
    local maxWidth = 0
    for _, l in ipairs(lines) do
        local len = M.wordArrayUtf8Len(l)
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
            row = height + row - maxHeight + 1
        end
        if row < 0 then
            print("row < 0")
        end
        if row + maxHeight > height then
            row = height - maxHeight + 1
        end
        if col < 0 then
            col = width + col - maxWidth - 1
        end
        if col < 0 then
            print("col < 0")
        end
        if col + maxWidth > width then
            col = width - maxWidth
        end
    else
        row = centerRow
    end

    local startRow = row
    local startCol = col
    local endCol = 0
    if col == nil then
        -- col is nil when position is nil, so we have to get the startCol as half the max width from the center
        startCol = math.floor((width - maxWidth) / 2)
        -- endCol is the last column that is rendered
        endCol = startCol + maxWidth - 1
    else
        endCol = col + maxWidth - 1
    end

    -- make it so that the gridLines is big enough to fit everything
    while #gridLines < startRow + maxHeight do
        local newLine = {}
        local k = 0
        while k < width - 2 do
            table.insert(newLine, { " " })
            k = k + 1
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
            -- This whole q business is because of utf8
            local q = 1
            while q <= #w[1] do
                -- The length of the utf8 char is determinable by the first byte
                local len = codepointLen(w[1]:sub(q, q))
                -- The actual utf8 char
                local char = w[1]:sub(q, q + len - 1)
                q = q + len
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

---@param gridLines SpaceportWord[][]
local function higlightBuffer(gridLines)
    if hlNs ~= nil then
        vim.api.nvim_buf_clear_namespace(0, hlNs, 0, -1)
        -- hlNs = nil
    end
    hlId = 0
    if hlNs == nil then
        hlNs = vim.api.nvim_create_namespace("Spaceport")
    end
    vim.api.nvim_win_set_hl_ns(winid, hlNs)
    if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
        error("Unreachable (buf is invalid in higlightBuffer)")
    end
    local row = 0
    local col = 0
    ---@type table<string, string>
    local usedHighlights = {}
    for _, v in ipairs(gridLines) do
        for _, word in ipairs(v) do
            if word.colorOpts ~= nil then
                local hlGroup = ""
                local optsStr = vim.inspect(word.colorOpts)
                local ns = hlNs

                if word.colorOpts._name ~= nil then
                    ns = 0
                    hlGroup = word.colorOpts._name
                    local hl = vim.api.nvim_get_hl(ns, {
                        name = hlGroup,
                    })
                    local keysCount = #vim.tbl_keys(word.colorOpts)
                    -- Apparently i have to use json to detect vim.empty_dict()
                    local hlNotExists = vim.json.encode(hl) == "{}"
                    -- If there are default highlight options, and the highlight does not exist, create it
                    if hlNotExists and keysCount > 1 then
                        local opts = vim.deepcopy(word.colorOpts)
                        opts._name = nil
                        if opts == nil then
                            error("Unreachable [highlightBuffer colorOpts is nil]")
                        end
                        vim.api.nvim_set_hl(0, hlGroup, opts)
                        if require('spaceport').getConfig().debug then
                            log("Created global highlight group: " .. hlGroup)
                        end
                    elseif hlNotExists then
                        hlGroup = "Normal"
                    end
                elseif usedHighlights[optsStr] ~= nil then
                    hlGroup = usedHighlights[optsStr]
                else
                    hlGroup = "spaceport_hl_" .. hlId
                    vim.api.nvim_set_hl(hlNs, hlGroup, word.colorOpts)
                    hlId = hlId + 1
                    usedHighlights[optsStr] = hlGroup
                end
                vim.api.nvim_buf_add_highlight(buf, ns, hlGroup, row, col, col + #word[1])
            end
            col = col + #word[1]
        end
        col = 0
        row = row + 1
    end
end


---@param win integer
---@return boolean
function M.isMainWin(win)
    local pos = vim.api.nvim_win_get_position(win)
    --- basically if the window is offset some amount, then it's not a main window
    if pos[1] ~= 0 and pos[2] ~= 0 then
        return false
    end
    return true
end

---@class (exact) SpaceportViewport
---@field rowStart number
---@field rowEnd number
---@field colStart number
---@field colEnd number

function M.render()
    log("spaceport.screen.render()")
    local actualStart = vim.loop.hrtime()
    local startTime = vim.loop.hrtime()
    ---@type SpaceportWord[][]
    local gridLines = {}
    ---@type table<integer, SpaceportViewport>
    local remapsViewport = {}
    require("spaceport.data").refreshData()
    if require('spaceport').getConfig().debug then
        log("Refresh took " .. (vim.loop.hrtime() - startTime) / 1e6 .. "ms")
        startTime = vim.loop.hrtime()
    end

    local screens = M.getActualScreens()
    if require('spaceport').getConfig().debug then
        log("Screens took " .. (vim.loop.hrtime() - startTime) / 1e6 .. "ms")
        startTime = vim.loop.hrtime()
    end
    if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "nofile", {
            buf = buf,
        })
        vim.api.nvim_buf_set_name(buf, "spaceport")
        vim.api.nvim_set_option_value("filetype", "spaceport", {
            buf = buf,
        })
        vim.api.nvim_set_option_value("bufhidden", "wipe", {
            buf = buf,
        })
        vim.api.nvim_set_option_value("swapfile", false, {
            buf = buf,
        })
        winid = vim.api.nvim_get_current_win()
        local wins = vim.api.nvim_list_wins()
        local i = 1
        while not M.isMainWin(winid) do
            local v = wins[i]
            if M.isMainWin(v) then
                winid = v
                break
            end
            i = i + 1
            if i > #wins then
                break
            end
        end
        needsRemap = true
        vim.api.nvim_win_set_buf(winid, buf)
    end
    if not vim.api.nvim_win_is_valid(winid) then
        winid = vim.api.nvim_get_current_win()
        if not M.isMainWin(winid) then
            local wins = vim.api.nvim_list_wins()
            for _, v in ipairs(wins) do
                if M.isMainWin(v) then
                    winid = v
                    break
                end
            end
        end
    end
    width = vim.api.nvim_win_get_width(winid)
    height = vim.api.nvim_win_get_height(winid)
    vim.cmd("setlocal norelativenumber nonumber")
    if require('spaceport').getConfig().debug then
        log("Buf took " .. (vim.loop.hrtime() - startTime) / 1e6 .. "ms")
        startTime = vim.loop.hrtime()
    end

    -- This variable keeps track of the row that the next centered screen should start at for remaps
    local centerRow = 0
    for index, v in ipairs(screens) do
        gridLines, remapsViewport[index] = renderGrid(v, gridLines, centerRow)
        if v.position == nil then
            centerRow = remapsViewport[index].rowEnd + 1
        end
    end
    if require('spaceport').getConfig().debug then
        log("VRender took " .. (vim.loop.hrtime() - startTime) / 1e6 .. "ms")
        startTime = vim.loop.hrtime()
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
    if require('spaceport').getConfig().debug then
        log("Set lines took " .. (vim.loop.hrtime() - startTime) / 1e6 .. "ms")
        startTime = vim.loop.hrtime()
    end

    higlightBuffer(gridLines)
    if require('spaceport').getConfig().debug then
        log("Highlights took " .. (vim.loop.hrtime() - startTime) / 1e6 .. "ms")
        startTime = vim.loop.hrtime()
    end
    if needsRemap then
        setRemaps(remapsViewport, screens)
        needsRemap = false
    end
    if require('spaceport').getConfig().debug then
        log("Remaps took " .. (vim.loop.hrtime() - startTime) / 1e6 .. "ms")
        startTime = vim.loop.hrtime()
    end
    log("Total render took " .. (vim.loop.hrtime() - actualStart) / 1e6 .. "ms")
    if require('spaceport').getConfig().debug then
        log("")
    end
end

return M
