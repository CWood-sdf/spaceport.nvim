vim.api.nvim_create_user_command("Spaceport", function(opts)
    local cmds = {
        renameWindow = function(args)
            local value = args[2]
            require("spaceport.data").renameWindow(value)
        end,
        renameSession = function(args)
            local value = args[2]
            require("spaceport.data").renameSession(value)
        end,
        verticalSplit = function(_)
            require("spaceport.data").tmuxSplitWindowDown()
        end,
        horizontalSplit = function(_)
            require("spaceport.data").tmuxSplitWindowLeft()
        end,
        importOldfiles = function(args)
            local countStr = args[2]
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
    if #opts.fargs == 0 or opts.fargs == nil then
        require("spaceport.screen").render()
    else
        local args = opts.fargs
        local command = args[1]
        if cmds[command] ~= nil then
            cmds[command](args)
        else
            print("Bad command " .. command)
        end
    end
end, { nargs = "*" })
vim.api.nvim_create_autocmd({ "UiEnter" }, {
    callback = function()
        require("spaceport").__timeStartup()

        if vim.fn.argc() == 0 then
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
            require('spaceport.data').refreshData()
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
    callback = function()
        if require("spaceport.screen").isRendering() then
            require("spaceport.screen").render()
        end
    end,
})
