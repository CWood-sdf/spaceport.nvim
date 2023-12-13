---@class (exact) SpaceportRemap
---@field key string
---@field mode string | string[]
---@field action string | fun(line: number, count: number)
---@field description string
---@field allowOutsideBuffer boolean | nil
local SpaceportRemap = {}

--This is supposed to be able to allow highlighting of words
---@class (exact) SpaceportWord
---@field [1] string
---@field colorOpts table | nil

---@class (exact) SpaceportScreen
---@field lines (string|SpaceportWord[])[] | (fun(): (string|SpaceportWord[])[])
---@field remaps SpaceportRemap[] | nil
---@field title string | nil | fun(): string
---@field topBuffer number
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
function M.centerString(str)
	local len = #str
	local pad = math.floor((width - len) / 2)
	return string.rep(" ", pad) .. str
end

---@return SpaceportWord[]
---@param arr SpaceportWord[]
function M.centerWords(arr)
	local len = 0
	for _, v in pairs(arr) do
		len = len + #v[1]
	end
	local pad = math.floor((width - len) / 2)
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

function M.render()
	if hlNs == nil then
		hlNs = vim.api.nvim_create_namespace("Spaceport")
		vim.api.nvim_win_set_hl_ns(0, hlNs)
	end
	width = vim.api.nvim_win_get_width(0)

	local screens = M.getActualScreens()
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		buf = vim.api.nvim_create_buf(false, true)
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
	-- vim.api.nvim_buf_set_option(buf, "number", false)
	vim.api.nvim_set_current_buf(buf)
	vim.cmd("setlocal norelativenumber nonumber")
	-- require("spaceport.data").refreshData()
	---@type string[]
	local actualLines = {}
	---@type SpaceportWord[][]
	local lines = {}
	for _, v in ipairs(screens) do
		local i = 0
		while i < v.topBuffer do
			table.insert(actualLines, "")
			table.insert(lines, {})
			i = i + 1
		end
		if v.title ~= nil then
			---@type string|fun(): string
			local title = v.title
			if type(title) == "function" then
				title = title()
			end
			local centered = M.centerString(title)
			table.insert(actualLines, centered)
			local centeredWords = M.centerWords({ { title } })
			table.insert(lines, centeredWords)
		end
		local screenLines = v.lines
		if type(screenLines) == "function" then
			screenLines = screenLines()
		end
		---@cast screenLines (string|SpaceportWord[])[]
		for _, line in ipairs(screenLines) do
			table.insert(actualLines, M.centerString(M.wordArrayToString(line)))
			local words = M.rowToWordArray(line)
			words = M.centerWords(words)
			table.insert(lines, words)
		end
	end
	vim.api.nvim_set_option_value("modifiable", true, {
		buf = buf,
	})
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, actualLines)
	vim.api.nvim_set_option_value("modifiable", false, {
		buf = buf,
	})

	local row = 0
	local col = 0
	for _, v in ipairs(lines) do
		for _, word in ipairs(v) do
			if word.colorOpts ~= nil then
				local hlGroup = "spaceport_hl_" .. hlId
				-- print("hlGroup: " .. hlGroup)
				vim.api.nvim_set_hl(hlNs, hlGroup, word.colorOpts)
				hlId = hlId + 1
				-- print("highlighting yo")
				-- print(buf, hlNs, hlGroup, row, col, col + #word[1])
				--2 4 1 62 98
				vim.api.nvim_buf_add_highlight(buf, hlNs, hlGroup, row, col, col + #word[1])
			end
			col = col + #word[1]
		end
		col = 0
		row = row + 1
	end
end

function M.remap()
	require("spaceport.data").refreshData()
	local screens = M.getActualScreens()

	local startLine = 0
	for _, v in ipairs(screens) do
		local lines = v.lines
		if type(lines) == "function" then
			lines = lines()
		end
		for _, remap in ipairs(v.remaps or {}) do
			if type(remap.action) == "function" then
				local startLineCopy = startLine + 10 - 10
				vim.keymap.set(remap.mode, remap.key, function()
					remap.action((vim.fn.line(".") or 0) - startLineCopy, vim.v.count)
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
		startLine = startLine + v.topBuffer + (v.title ~= nil and 1 or 0) + #lines
	end
end

return M
