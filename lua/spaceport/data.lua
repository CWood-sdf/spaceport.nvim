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

---@type SpaceportDir[]
local data = {}
---@type SpaceportDir[]
local pinnedData = {}
---@type table<string, {time: number, isDir: boolean, pinNumber: number}>
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
function M.getAllMruData()
	M.refreshData()
	return data
end
function M.getPinnedData()
	M.refreshData()
	return pinnedData
end
function M.getRawData()
	M.refreshData()
	return rawData
end

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
	vim.api.nvim_exec_autocmds("User", {
		pattern = "SpaceportDone",
		data = {
			isDir = dir.isDir,
			path = dir.dir,
		},
	})
end
return M
