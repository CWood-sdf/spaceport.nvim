local M = {}

local opts = {
	ignoreDirs = {},
	replaceHome = true,
	projectEntry = "Ex",
}
local startupStart = 0
local startupTime = 0

M.timeStartup = function()
	startupStart = vim.loop.hrtime()
end

M.timeStartupEnd = function()
	startupTime = vim.loop.hrtime() - startupStart
end

M.getStartupTime = function()
	return startupTime / 1e6
end

M.setup = function(_opts)
	for k, v in pairs(_opts) do
		if not opts[k] then
			error("Invalid option for spaceport config: " .. k)
		end
		opts[k] = v
	end
end

M._getIgnoreDirs = function()
	return opts.ignoreDirs
end

M._swapHomeWithTilde = function(path)
	if opts.replaceHome then
		if jit.os == "Windows" then
			return path:gsub(os.getenv("USERPROFILE"), "~")
		end
		return path:gsub(os.getenv("HOME"), "~")
	end
	return path
end

M._fixDir = function(path)
	local ret = M._swapHomeWithTilde(path)
	for _, dir in ipairs(opts.ignoreDirs) do
		local ok = type(dir) == "table"
		if ok then
			ret = ret:gsub(dir[1], dir[2])
			return ret
		else
			ret = ret:gsub(dir, "")
		end
	end
	return ret
end

M._projectEntryCommand = function()
	return opts.projectEntry
end

return M
