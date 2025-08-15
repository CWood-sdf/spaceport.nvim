local allCmds = {
    Spaceport = {},
}
local cmds = {
    renameWindow = function (args)
        local value = args[1]
        require("spaceport.data").renameWindow(value)
    end,
    renameSession = function (args)
        local value = args[1]
        require("spaceport.data").renameSession(value)
    end,
    verticalSplit = function (_)
        require("spaceport.data").tmuxSplitWindowDown()
    end,
    horizontalSplit = function (_)
        require("spaceport.data").tmuxSplitWindowLeft()
    end,
    importOldfiles = function (args)
        local countStr = args[1]
        local count = nil
        if countStr ~= nil then
            count = tonumber(countStr)
        end
        require("spaceport.data").importOldfiles(count)
        if require("spaceport.screen").isRendering() then
            require("spaceport.screen").render()
        end
    end,
}
for k, _ in pairs(cmds) do
    allCmds.Spaceport[k] = {}
end
vim.api.nvim_create_user_command("Spaceport", function (opts)
    if #opts.fargs == 0 or opts.fargs == nil then
        vim.api.nvim_exec_autocmds("User", {
            pattern = "SpaceportEnter",
        })
        require("spaceport.screen").render()
    else
        local args = opts.fargs
        local command = args[1]
        local i = 2
        while type(command) == "table" do
            command = command[args[i]]
            i = i + 1
        end
        local actualArgs = {}
        while i <= #args do
            table.insert(actualArgs, args[i])
            i = i + 1
        end
        if cmds[command] ~= nil then
            cmds[command](actualArgs)
        else
            print("Bad command " .. command)
        end
    end
end, {
    nargs = "*",
    complete = function (working, current, _)
        local tempCmds = allCmds
        local i = 1
        local cmdStr = ""
        while i <= #current do
            local c = current:sub(i, i)
            if c == " " then
                if tempCmds[cmdStr] ~= nil then
                    tempCmds = tempCmds[cmdStr]
                    cmdStr = ""
                else
                    return {}
                end
            else
                cmdStr = cmdStr .. c
            end
            i = i + 1
        end
        if tempCmds ~= nil then
            local ret = {}
            for k, _ in pairs(tempCmds) do
                table.insert(ret, k)
            end
            local clean = false
            while not clean do
                clean = true
                for p, v in ipairs(ret) do
                    if v:sub(1, #working) ~= working then
                        table.remove(ret, p)
                        clean = false
                        break
                    end
                end
            end

            return ret
        end
    end,
})
vim.api.nvim_create_autocmd({ "UiEnter" }, {
    callback = function ()
        require("spaceport").__timeStartup()

        local uis = vim.api.nvim_list_uis()

        -- headless
        if #uis == 0 then return end

        -- Following stuff is yoinked from folke/snacks.nvim/lua/dashboard.lua
        -- don't open the dashboard if in TUI and input is piped
        if uis[1].stdout_tty and not uis[1].stdin_tty then
            return
        end

        local buf = vim.api.nvim_get_current_buf()

        local win = vim.api.nvim_get_current_win()

        local isFloating = not require("spaceport.screen").isMainWin(win)

        -- don't open the dashboard if there is any text in the buffer
        if vim.bo.filetype ~= "netrw" and not isFloating then
            local currentDir = vim.fn.getcwd()
            if vim.api.nvim_buf_line_count(buf) > 1 or #(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "") > 0 then
                vim.api.nvim_exec_autocmds("User", {
                    pattern = "SpaceportDonePre",
                    data = currentDir,
                })
                vim.api.nvim_exec_autocmds("User", {
                    pattern = "SpaceportDone",
                    data = currentDir,
                })
                return
            end
        end

        if vim.fn.argc() == 0 or isFloating then
            vim.api.nvim_exec_autocmds("User", {
                pattern = "SpaceportEnter",
            })
            require("spaceport.screen").render()
        elseif vim.fn.argc() > 0 then
            -- dir = vim.fn.argv()[1]
            require("spaceport.data").refreshData()
            local dataToWrite = require("spaceport.data").getRawData()
            if dataToWrite == nil then
                dataToWrite = {}
            end
            local time = require("spaceport.utils").getSeconds()
            local argv = vim.fn.argv() or {}
            if type(argv) == "string" then
                argv = { argv }
            end
            local dir = nil
            for _, v in pairs(argv) do
                local oilStart = "oil://"
                if v == "." or v:sub(1, #oilStart) == oilStart then
                    v = vim.fn.getcwd()
                end
                local isDir = require("spaceport.data").isdir(v)
                if not require("spaceport.data").isdir(v) then
                    v = vim.fn.fnamemodify(v, ":p") or ""
                end
                if dataToWrite[v] == nil then
                    dataToWrite[v] = {
                        time = time,
                        isDir = isDir,
                        pinNumber = 0,
                    }
                else
                    dataToWrite[v].time = time
                    dataToWrite[v].isDir = isDir
                end
                if isDir then
                    require("spaceport")._projectEntryCommand()
                end
                dir = v
                break
            end
            require("spaceport.data").writeData(dataToWrite)
            require("spaceport.data").refreshData()
            require("spaceport.data").setCurrentDir(dir)
            local screens = require("spaceport.screen").getActualScreens()
            for _, screen in pairs(screens) do
                if screen.onExit ~= nil then
                    screen.onExit()
                end
            end
        end
        require("spaceport").__timeStartupEnd()
    end,
})
vim.api.nvim_create_autocmd({ "VimResized" }, {
    callback = function ()
        if require("spaceport.screen").isRendering() then
            require("spaceport.screen").render()
        end
    end,
})
vim.api.nvim_create_autocmd({ "BufLeave" }, {
    callback = function ()
        if require("spaceport.screen").isRendering() then
            require("spaceport.screen").render()
        end
    end,
})
vim.api.nvim_create_autocmd({ "BufEnter" }, {
    callback = function ()
        if require("spaceport.screen").isRendering() then
            require("spaceport.screen").render()
        end
    end,
})

vim.api.nvim_create_autocmd({ "QuitPre", "ExitPre" }, {
    callback = function ()
        -- This is needed bc if there's an animation, it's calls to render() will override the quit
        if require("spaceport.screen").isRendering() then
            local screens = require("spaceport.screen").getActualScreens()
            -- Kill all the screens gracefully
            for _, screen in pairs(screens) do
                if screen.onExit ~= nil then
                    screen.onExit()
                end
            end
            -- Force quit
            require("spaceport.screen").exit()
        end
    end,
})
