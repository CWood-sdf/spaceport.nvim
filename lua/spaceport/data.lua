local spaceport = require("spaceport")
local M = {}
local dataPath = vim.fn.stdpath("data")
local dataDir = dataPath .. "/spaceport.json"
---@class (exact) SpaceportDir
---@field dir string
---@field time number
---@field isDir boolean
---@field pinNumber number
---@field prettyDir string
---@field tmuxWindowName string|nil
---@field tmuxSessionName string|nil

---@type SpaceportDir|nil
local currentDir = nil

---@type SpaceportDir[]
local data = {}
---@type SpaceportDir[]
local pinnedData = {}
---@type table<string, {time: number, isDir: boolean, pinNumber: number, tmuxWindowName: string|nil, tmuxSessionName: string|nil}>
local rawData = {}
function M.exists(file)
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
function M.isdir(path)
	-- "/" works on both Unix and Windows
	return M.exists(path .. "/")
end
function M.readData()
	if not M.exists(dataDir) then
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
	local fileContents = file:read("*all")
	file:close()
	local ret = vim.fn.json_decode(fileContents)
	for k, _ in pairs(ret) do
		if ret[k].pinNumber == nil then
			ret[k].pinNumber = 0
		end
		if ret[k].pinned ~= nil then
			ret[k].pinned = nil
		end
	end
	if ret == nil then
		print("Error getting spaceport data")
		return {}
	end
	return ret
end

---@param dir string
function M.setCurrentDir(dir)
	M.refreshData()
	local d = M.getAllData()
	for _, v in pairs(d) do
		if v.dir == dir then
			currentDir = v
			return
		end
	end
	M.doTmuxActions()
	vim.api.nvim_exec_autocmds("User", {
		pattern = "SpaceportDone",
		data = currentDir,
	})
end

function M.writeData(d)
	local file = io.open(dataDir, "w")
	if file == nil then
		print("Can not create file at " .. dataDir .. "")
		return
	end
	file:write(vim.fn.json_encode(d))
	file:close()
end

function M.refreshData()
	data = {}
	pinnedData = {}
	rawData = M.readData()
	if rawData == nil then
		return
	end
	for k, v in pairs(rawData) do
		local insert = {
			dir = k,
			time = v.time,
			isDir = v.isDir,
			pinNumber = v.pinNumber,
			prettyDir = spaceport._fixDir(k),
			tmuxWindowName = v.tmuxWindowName,
			tmuxSessionName = v.tmuxSessionName,
		}
		if v.pinNumber == 0 then
			table.insert(data, insert)
		else
			table.insert(pinnedData, insert)
		end
	end
	table.sort(data, function(a, b)
		return a.time > b.time
	end)

	table.sort(pinnedData, function(a, b)
		return a.pinNumber < b.pinNumber
	end)
end

---@return SpaceportDir[]
function M.getAllData()
	M.refreshData()
	local ret = {}
	for _, v in pairs(data) do
		table.insert(ret, v)
	end
	for _, v in pairs(pinnedData) do
		table.insert(ret, v)
	end
	table.sort(ret, function(a, b)
		return a.time > b.time
	end)
	return ret
end
---@return SpaceportDir[]
function M.getMruData()
	M.refreshData()
	local ret = {}
	if require("spaceport")._getMaxRecentFiles() == 0 then
		return data
	end
	for i = 1, require("spaceport")._getMaxRecentFiles() do
		if data[i] == nil then
			break
		end
		table.insert(ret, data[i])
	end
	return ret
end
---@return SpaceportDir[]
function M.getAllMruData()
	M.refreshData()
	return data
end
---@return SpaceportDir[]
function M.getPinnedData()
	M.refreshData()
	return pinnedData
end
function M.getRawData()
	M.refreshData()
	return rawData
end

function M.renameSession(str)
	M.refreshData()
	if currentDir == nil then
		print("No spaceport directory selected yet")
		return
	end
	currentDir.tmuxSessionName = str
	if os.getenv("TMUX") ~= nil then
		vim.system({ "tmux", "rename-session", currentDir.tmuxSessionName }, { text = true })
	else
		print("Not currently in tmux")
	end
	rawData[currentDir.dir].tmuxSessionName = currentDir.tmuxSessionName
end

function M.renameWindow(str)
	M.refreshData()
	if currentDir == nil then
		print("No spaceport directory selected yet")
		return
	end
	currentDir.tmuxWindowName = str
	if os.getenv("TMUX") ~= nil then
		vim.system({ "tmux", "rename-window", currentDir.tmuxWindowName }, { text = true })
	else
		print("Not currently in tmux")
	end
	rawData[currentDir.dir].tmuxWindowName = currentDir.tmuxWindowName
	M.writeData(rawData)
end

function M.doTmuxActions()
	if currentDir == nil then
		print("No spaceport directory selected yet")
		return
	end
	if currentDir.tmuxSessionName ~= nil then
		M.renameSession(currentDir.tmuxSessionName)
	end
	if currentDir.tmuxWindowName ~= nil then
		M.renameWindow(currentDir.tmuxWindowName)
	end
end

---@param str string
function M.removeDir(str)
	local d = M.getRawData()
	d[str] = nil
	M.writeData(d)
end

---@param dir SpaceportDir
function M.cd(dir)
	M.refreshData()
	rawData[dir.dir].time = require("spaceport.utils").getSeconds()
	M.writeData(rawData)
	if dir.isDir then
		vim.cmd("cd " .. dir.dir)
		spaceport._projectEntryCommand()
	else
		vim.cmd("edit " .. dir.dir)
	end

	currentDir = dir
	M.doTmuxActions()
	vim.api.nvim_exec_autocmds("User", {
		pattern = "SpaceportDone",
		data = currentDir,
	})
end
return M
