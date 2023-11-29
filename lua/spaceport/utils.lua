local M = {}
---@return number
function M.getSeconds()
	return vim.fn.localtime()
end

function M.isToday(time)
	local today = vim.fn.strftime("%Y-%m-%d")
	local t = vim.fn.strftime("%Y-%m-%d", time)
	return today == t
end

function M.isYesterday(time)
	local yesterday = vim.fn.strftime("%Y-%m-%d", vim.fn.localtime() - 24 * 60 * 60)
	local t = vim.fn.strftime("%Y-%m-%d", time)
	return yesterday == t
end

function M.isPastWeek(time)
	return time > M.getSeconds() - 7 * 24 * 60 * 60
end

function M.isPastMonth(time)
	return time > M.getSeconds() - 30 * 24 * 60 * 60
end

return M
