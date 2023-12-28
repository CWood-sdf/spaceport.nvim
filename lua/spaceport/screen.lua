---@class (exact) SpaceportRemap
---@field key string
---@field mode string | string[]
---@field action string | fun(line: number, count: number)
---@field description string
---@field visible boolean|nil
---@field callOutside boolean | nil
local SpaceportRemap = {}

--This is supposed to be able to allow highlighting of words
---@class (exact) SpaceportWord
---@field [1] string
---@field colorOpts table | nil

---@class (exact) SpaceportScreenPosition
---@field row number
---@field col number

---@class (exact) SpaceportScreen
---@field lines (string|SpaceportWord[])[] | (fun(): (string|SpaceportWord[])[]) | (fun(): string[]) | (fun(): SpaceportWord[][])
---@field remaps SpaceportRemap[] | nil
---@field title string | nil | fun(): string
---@field topBuffer number
---@field position SpaceportScreenPosition | nil
---@field onExit fun() | nil
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
---@param w? number
function M.centerString(str, w)
	w = w or width
	local len = #str
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
		len = len + #v[1]
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
	require("spaceport.data").refreshData()
	local startTime = vim.uv.hrtime()
	if hlNs ~= nil then
		vim.api.nvim_buf_clear_namespace(0, hlNs, 0, -1)
		hlNs = nil
	end
	hlId = 0
	-- if hlNs == nil then
	hlNs = vim.api.nvim_create_namespace("Spaceport")
	vim.api.nvim_win_set_hl_ns(0, hlNs)
	-- end
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
	---@type string[]
	local actualLines = {}
	---@type SpaceportWord[][]
	local lines = {}
	local totalTime = 0
	for _, v in ipairs(screens) do
		if v.position ~= nil then
			goto continue
		end
		local i = 0
		while i < v.topBuffer do
			table.insert(actualLines, string.rep(" ", width - 2))
			table.insert(lines, { { string.rep(" ", width - 2) } })
			i = i + 1
		end
		if v.title ~= nil then
			---@type string|fun(): string
			local title = v.title
			if type(title) == "function" then
				title = title()
			end
			local centered = M.centerString(title)
			local extra = string.rep(" ", width - #centered - 2)
			centered = centered .. extra
			table.insert(actualLines, centered)
			local centeredWords = M.centerWords({ { title }, { extra } })
			table.insert(lines, centeredWords)
		end
		local screenLines = v.lines
		if type(screenLines) == "function" then
			local start = vim.uv.hrtime()
			screenLines = screenLines()
			totalTime = totalTime + (vim.uv.hrtime() - start) / 1000000
		end
		---@cast screenLines (string|SpaceportWord[])[]
		for _, line in ipairs(screenLines) do
			local centeredString = M.centerString(M.wordArrayToString(line))
			centeredString = centeredString .. string.rep(" ", width - #centeredString - 2)
			table.insert(actualLines, centeredString)
			local words = M.rowToWordArray(line)
			words = M.centerWords(words)
			local extra = string.rep(" ", width - #M.wordArrayToString(words) - 2)
			words[#words + 1] = { extra }
			table.insert(lines, words)
		end
		::continue::
	end
	while #lines < vim.api.nvim_win_get_height(0) do
		table.insert(actualLines, string.rep(" ", width - 2))
		table.insert(lines, { { string.rep(" ", width - 2) } })
	end
	-- print((vim.uv.hrtime() - startTime) / 1000000 .. "ms")
	-- print("Total time: " .. totalTime .. "ms")
	for _, v in ipairs(screens) do
		if v.position == nil then
			goto continue
		end
		local tempLines = {}
		if v.title ~= nil then
			---@type string|fun(): string
			local title = v.title
			if type(title) == "function" then
				title = title()
			end
			local centeredWords = { { title } }
			table.insert(tempLines, centeredWords)
		end
		local screenLines = v.lines
		if type(screenLines) == "function" then
			screenLines = screenLines()
		end
		---@cast screenLines (string|SpaceportWord[])[]
		for _, line in ipairs(screenLines) do
			-- local centeredString = M.centerString(M.wordArrayToString(line))
			-- centeredString = centeredString .. string.rep(" ", width - #centeredString - 2)
			local words = M.rowToWordArray(line)
			-- words = M.centerWords(words)
			-- local extra = string.rep(" ", width - #M.wordArrayToString(words) - 2)
			-- words[#words + 1] = { extra }
			table.insert(tempLines, words)
		end
		local maxWidth = 0
		for _, l in ipairs(tempLines) do
			local len = #M.wordArrayToString(l)
			if len > maxWidth then
				maxWidth = len
			end
		end
		local maxHeight = #tempLines
		local row = v.position.row
		local col = v.position.col
		if row < 0 then
			row = vim.api.nvim_win_get_height(0) + row - maxHeight + 1
		end
		if row < 0 then
			print("row < 0")
		end
		if row + maxHeight > vim.api.nvim_win_get_height(0) then
			row = vim.api.nvim_win_get_height(0) - maxHeight + 1
		end
		if col < 0 then
			col = vim.api.nvim_win_get_width(0) + col - maxWidth - 1
		end
		if col < 0 then
			print("col < 0")
		end
		if col + maxWidth > vim.api.nvim_win_get_width(0) then
			col = vim.api.nvim_win_get_width(0) - maxWidth
		end
		local i = 1
		for r = row, row + maxHeight - 1 do
			local actualLine = actualLines[r + 1]
			local tempLine = tempLines[i]
			local tempLineStr = M.wordArrayToString(tempLine)
			local newLine = {}
			actualLine = actualLine:sub(1, col) .. tempLineStr .. actualLine:sub(col + #tempLineStr + 1)
			actualLines[r + 1] = actualLine
			local totalLen = 0
			local foundLen = -1
			local skipLen = 0
			for j = 1, #lines[r + 1] do
				local word = lines[r + 1][j]
				totalLen = totalLen + #word[1]
				if totalLen <= foundLen + skipLen then
					goto continue2
				end
				if totalLen >= col and foundLen == -1 then
					foundLen = totalLen
					local wordSegment = word[1]:sub(1, col - (totalLen - #word[1]))
					local newWord = { wordSegment, colorOpts = word.colorOpts }
					newLine[#newLine + 1] = newWord
					skipLen = 0
					-- print("tl: '" .. tempLineStr .. "'")
					for _, tl in ipairs(tempLine) do
						newLine[#newLine + 1] = tl
						skipLen = skipLen + #tl[1]
					end
				elseif totalLen > foundLen + skipLen and totalLen - #word[1] < foundLen + skipLen then
					local wordSegment = word[1]:sub(totalLen - foundLen - skipLen + 1)
					local newWord = { wordSegment, colorOpts = word.colorOpts }
					newLine[#newLine + 1] = newWord
				else
					newLine[#newLine + 1] = word
				end
				::continue2::
			end
			lines[r + 1] = newLine
			i = i + 1
		end

		::continue::
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
	local endTime = vim.uv.hrtime()
	-- print("Render time: " .. (endTime - startTime) / 1000000 .. "ms")
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
				local startLineCopy = startLine - v.topBuffer - (v.title ~= nil and 1 or 0) - #lines
				vim.keymap.set(remap.mode, remap.key, function()
					local line = (vim.fn.line(".") or 0) - startLineCopy
					local callOutside = remap.callOutside or true
					if not callOutside and line > 0 and line <= #lines then
						remap.action(line, vim.v.count)
						return
					end
					if callOutside then
						remap.action(line, vim.v.count)
					end
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
