-- local dir = ""
local dataPath = vim.fn.stdpath("data")
local dataDir = dataPath .. "/spaceport.json"
--- Check if a file or directory exists in this path
local function exists(file)
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

local function readData()
    if not exists(dataDir) then
        local file = io.open(dataDir, "w")
        if file == nil then
            print("Can not create file at " .. dataDir .. "")
            return {}
        end
        file:write(vim.fn.json_encode({}))
        file:close()
        return {}
    end
    local file = io.open(dataDir, "r")
    if file == nil then
        return {}
    end
    local data = file:read("*all")
    file:close()
    return vim.fn.json_decode(data)
end

local function writeData(data)
    local file = io.open(dataDir, "w")
    if file == nil then
        print("Can not create file at " .. dataDir .. "")
        return
    end
    file:write(vim.fn.json_encode(data))
    file:close()
end

--- Check if a directory exists in this path
local function isdir(path)
    -- "/" works on both Unix and Windows
    return exists(path .. "/")
end

local function getSeconds()
    return vim.fn.localtime()
end

local function isToday(time)
    local today = vim.fn.strftime("%Y-%m-%d")
    local t = vim.fn.strftime("%Y-%m-%d", time)
    return today == t
end

local function isYesterday(time)
    local yesterday = vim.fn.strftime("%Y-%m-%d", vim.fn.localtime() - 24 * 60 * 60)
    local t = vim.fn.strftime("%Y-%m-%d", time)
    return yesterday == t
end

local function isPastWeek(time)
    return time > getSeconds() - 7 * 24 * 60 * 60
end

local function isPastMonth(time)
    return time > getSeconds() - 30 * 24 * 60 * 60
end

-- local topSection =
--     "  ____   _____    ___    ____   ____   _____    __    ____   _____ \n" ..
--     " |  __| |  _  |  / _ \\  |  __| | ___| |  _  |  /  \\  |  _ \\ |__  _|\n" ..
--     " | |__  | |_| | | /_\\ | | |    | |_   | |_| | | /\\ | | |_| |  | |  \n" ..
--     " |__  | | ____| |  _  | | |    |  _|  | ____| | || | | __  |  | |  \n" ..
--     "  __| | | |     | | | | | |__  | |__  | |     | \\/ | | | \\ \\  | |  \n" ..
--     " |____| |_|     |_| |_| |____| |____| |_|      \\__/  |_| |_|  |_|  \n"

local topSection =
    "### ###  #  ### ### ### ### ###  ###\n" ..
    "#   # # # # #   #   # # # # #  #  # \n" ..
    "### ### ### #   ##  ### # # ###   # \n" ..
    "  # #   # # #   #   #   # # #  #  # \n" ..
    "### #   # # ### ### #   ### #  #  # \n"
local function addLine(lines, line, width)
    local padding = math.floor((width - #line) / 2)
    local paddingStr = string.rep(" ", padding)
    table.insert(lines, paddingStr .. line)
end
vim.api.nvim_create_autocmd({ "UiEnter" }, {
    callback = function()
        if vim.fn.argc() == 0 then
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
            vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
            vim.api.nvim_buf_set_option(buf, "swapfile", false)
            -- vim.api.nvim_buf_set_option(buf, "number", false)
            vim.api.nvim_set_current_buf(buf)
            vim.cmd("setlocal norelativenumber nonumber")
            local rawData = readData()
            local data = {}
            for k, v in pairs(rawData) do
                table.insert(data, { dir = k, time = v.time, isDir = v.isDir })
            end
            table.sort(data, function(a, b)
                return a.time > b.time
            end)
            vim.keymap.set("n", "p", function()
                local count = vim.v.count
                if count == nil or count == 0 then
                    count = 1
                end
                local dir = data[count]
                if dir == nil then
                    return
                end
                if dir.isDir then
                    vim.cmd("cd " .. dir.dir)
                    vim.cmd("Ex")
                else
                    vim.cmd("edit " .. dir.dir)
                end
                rawData[dir.dir].time = getSeconds()
                writeData(rawData)
            end, {
                buffer = buf,
            })
            local lines = {}
            -- vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Yo sdf", "" })
            local width = vim.o.columns
            local header = vim.fn.split(topSection, "\n")
            addLine(lines, "", width)
            addLine(lines, "", width)
            for _, v in pairs(header) do
                addLine(lines, v, width)
            end
            addLine(lines, "", width)
            addLine(lines, "{count}p" .. string.rep(" ", 20) .. "Select project", width)
            -- addLine(lines, "", width)
            local maxNameLen = 0
            for _, v in pairs(data) do
                if #v.dir > maxNameLen then
                    maxNameLen = #v.dir + 10
                end
            end
            local currentTime = ""
            local index = 1
            for _, v in pairs(data) do
                if isToday(v.time) then
                    if currentTime ~= "Today" then
                        currentTime = "Today"
                        -- vim.api.nvim_buf_setn_lines(buf, -1, -1, false, { currentTime })
                        addLine(lines, "", width)
                        addLine(lines, currentTime, width)
                    end
                elseif isYesterday(v.time) then
                    if currentTime ~= "Yesterday" then
                        currentTime = "Yesterday"
                        -- vim.api.nvim_buf_set_lines(buf, -1, -1, false, { currentTime })
                        addLine(lines, "", width)
                        addLine(lines, currentTime, width)
                    end
                elseif isPastWeek(v.time) then
                    if currentTime ~= "Past Week" then
                        currentTime = "Past Week"
                        -- vim.api.nvim_buf_set_lines(buf, -1, -1, false, { currentTime })
                        addLine(lines, "", width)
                        addLine(lines, currentTime, width)
                    end
                elseif isPastMonth(v.time) then
                    if currentTime ~= "Past Month" then
                        currentTime = "Past Month"
                        -- vim.api.nvim_buf_set_lines(buf, -1, -1, false, { currentTime })
                        addLine(lines, "", width)
                        addLine(lines, currentTime, width)
                    end
                else
                    if currentTime ~= "A long time ago" then
                        currentTime = "A long time ago"
                        -- vim.api.nvim_buf_set_lines(buf, -1, -1, false, { currentTime })
                        addLine(lines, "", width)
                        addLine(lines, currentTime, width)
                    end
                end
                local line = v.dir
                if not isYesterday(v.time) and not isToday(v.time) then
                    line = line .. " " .. vim.fn.strftime("%Y-%m-%d", v.time)
                end
                -- vim.api.nvim_buf_set_lines(buf, -1, -1, false, { line })
                addLine(lines, line .. string.rep(" ", 0 - #line + maxNameLen + 1) .. index, width)
                index = index + 1
            end
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.api.nvim_buf_set_option(buf, "modifiable", false)
        elseif vim.fn.argc() > 0 then
            -- dir = vim.fn.argv()[1]
            local data = readData()
            local time = getSeconds()
            for _, v in pairs(vim.fn.argv()) do
                local isDir = isdir(v)
                if not isdir(v) then
                    v = vim.fn.fnamemodify(v, ":p")
                end
                if data[v] == nil then
                    data[v] = {
                        time = time,
                        isDir = isDir,
                    }
                else
                    data[v].time = time
                    data[v].isDir = isDir
                end
            end
            writeData(data)
        end
    end
})
