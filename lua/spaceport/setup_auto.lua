vim.api.nvim_create_user_command("Spaceport", function(opts)
	-- print(opts.fargs)
	if #opts.fargs == 0 or opts.fargs == nil then
		require("spaceport.screen").render()
		require("spaceport.screen").remap()
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
			require("spaceport.screen").remap()
		elseif vim.fn.argc() > 0 then
			-- dir = vim.fn.argv()[1]
			local dataToWrite = require("spaceport.data").readData()
			local time = require("spaceport.utils").getSeconds()
			local argv = vim.fn.argv() or {}
			if type(argv) == "string" then
				argv = { argv }
			end
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
				require("spaceport.data").setCurrentDir(v)
				if isDir then
					require("spaceport")._projectEntryCommand()
				end
				break
			end
			require("spaceport.data").writeData(dataToWrite)
		end
		require("spaceport").timeStartupEnd()
	end,
})
vim.api.nvim_create_autocmd({ "VimResized" }, {
	callback = function()
		require("spaceport.screen").render()
	end,
})
