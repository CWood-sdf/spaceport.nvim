vim.api.nvim_create_user_command("Spaceport", function(opts)
    -- print(opts.fargs)
    if #opts.fargs == 0 or opts.fargs == nil then
        require("spaceport.screen").render()
    else
        local args = opts.fargs
        local command = args[1]
        if command == "renameWindow" then
            local value = args[2]
            if value == nil then
                value = vim.fn.getcwd()
            end
            require("spaceport.data").renameWindow(value)
        elseif command == "renameSession" then
            local value = args[2]
            if value == nil then
                value = vim.fn.getcwd()
            end
            require("spaceport.data").renameSession(value)
        elseif command == "verticalSplit" then
            require("spaceport.data").tmuxSplitWindowDown()
        elseif command == "horizontalSplit" then
            require("spaceport.data").tmuxSplitWindowLeft()
        else
            print("Bad command " .. command)
        end
    end
end, { nargs = "*" })
vim.api.nvim_create_autocmd({ "UiEnter" }, {
    callback = function()
        require("spaceport").timeStartup()

        if vim.fn.argc() == 0 then
            require("spaceport.screen").render()
        elseif vim.fn.argc() > 0 then
            -- dir = vim.fn.argv()[1]
            require("spaceport.data").refreshData()
            local dataToWrite = require("spaceport.data").readData()
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
            require("spaceport.data").setCurrentDir(dir)
            local screens = require("spaceport.screen").getActualScreens()
            for _, screen in pairs(screens) do
                if screen.onExit ~= nil then
                    screen.onExit()
                end
            end
        end
        require("spaceport").timeStartupEnd()
    end,
})
vim.api.nvim_create_autocmd({ "VimResized" }, {
    callback = function()
        if require("spaceport.screen").isRendering() then
            require("spaceport.screen").render()
        end
    end,
})
