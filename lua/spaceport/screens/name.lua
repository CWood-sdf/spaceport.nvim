---@class SpaceportGradient
---@field start string|{ red: number, blue: number, green: number }
---@field stop string|{ red: number, blue: number, green: number }
---@field dir "left"|"right"|"up"|"down"

---@param str string
---@return { red: number, blue: number, green: number }?
local function str2rgb(str)
	if str:sub(1, 1) ~= "#" then return nil end
	if #str ~= 7 then return nil end
	local red = tonumber(str:sub(2, 3), 16) or 0
	local green = tonumber(str:sub(4, 5), 16) or 0
	local blue = tonumber(str:sub(6, 7), 16) or 0
	return { red = red, blue = blue, green = green }
end

local topSectionPipe = {
	"╔═╗┌─┐┌─┐┌─┐┌─┐┌─┐┌─┐┬─┐┌┬┐",
	"╚═╗├─┘├─┤│  ├┤ ├─┘│ │├┬┘ │ ",
	"╚═╝┴  ┴ ┴└─┘└─┘┴  └─┘┴└─ ┴ ",
}
local topSectionLite = {
	" _____                       ______          _   ",
	"/  ___|                      | ___ \\        | |  ",
	"\\ `--. _ __   __ _  ___ ___  | |_/ /__  _ __| |_ ",
	" `--. \\ '_ \\ / _` |/ __/ _ \\ |  __/ _ \\| '__| __|",
	"/\\__/ / |_) | (_| | (_|  __/ | | | (_) | |  | |_ ",
	"\\____/| .__/ \\__,_|\\___\\___| \\_|  \\___/|_|   \\__|",
	"      | |                                        ",
	"      |_|                                        ",
}
local topSectionHash = {
	"### ###  #  ### ### ### ### ###  ###",
	"#   # # # # #   #   # # # # #  #  # ",
	"### ### ### #   ##  ### # # ###   # ",
	"  # #   # # #   #   #   # # #  #  # ",
	"### #   # # ### ### #   ### #  #  # ",
}

---@type { [string]: string[] }
local styles = {
	pipe = topSectionPipe,
	lite = topSectionLite,
	hash = topSectionHash,
}

for _, v in pairs(styles) do
	local maxLen = 0
	-- equalize the length of each line
	for _, str in ipairs(v) do
		maxLen = math.max(require('spaceport.screen').utf8Len(str), maxLen)
	end
	for i, str in ipairs(v) do
		local extra = maxLen - require('spaceport.screen').utf8Len(str)
		local extraStr = string.rep(' ', extra)
		v[i] = v[i] .. extraStr
	end
end

---@type { [string]: SpaceportGradient[] }
local gradients = {
	blue = {
		{
			start = "#0000ff",
			stop = "#eeeeff",
			dir = "up",
		},
	},
	blue_green = {
		{
			start = "#000064",
			stop = "#0000ff",
			dir = "down",
		},
		{
			start = "#006400",
			stop = "#00ff00",
			dir = "left",
		}
	},

}



---@param grad SpaceportGradient
---@param pct number
---@return { red: number, green: number, blue: number }
local function lerpColor(grad, pct)
	if type(grad.stop) == "string" then
		---@diagnostic disable-next-line: param-type-mismatch
		grad.stop = str2rgb(grad.stop) or {}
	end
	if type(grad.start) == "string" then
		---@diagnostic disable-next-line: param-type-mismatch
		grad.start = str2rgb(grad.start) or {}
	end
	return {
		red = (grad.stop.red - grad.start.red) * pct + grad.start.red,
		green = (grad.stop.green - grad.start.green) * pct + grad.start.green,
		blue = (grad.stop.blue - grad.start.blue) * pct + grad.start.blue,
	}
end

---@param grad SpaceportGradient
---@param row number
---@param col number
---@param w number
---@param h number
---@return { red: number, green: number, blue: number }
local function getGradientColorAt(grad, row, col, w, h)
	local pct = 0
	if grad.dir == "left" or grad.dir == "right" then
		pct = (col - 1) / (w - 1)
	end
	if grad.dir == "up" or grad.dir == "down" then
		pct = (row - 1) / (h - 1)
	end
	if grad.dir == "right" or grad.dir == "down" then
		pct = 1 - pct
	end
	return lerpColor(grad, pct)
end

---@param c { red: number, green: number, blue: number }
---@param o { red: number, green: number, blue: number }
---@return { red: number, green: number, blue: number }
local function addColors(c, o)
	return {
		red = c.red + o.red,
		green = c.green + o.green,
		blue = c.blue + o.blue
	}
end

local function l(config)
	---@type string[]
	local style = {}
	if type(config.style) == "table" then
		style = config.style
	else
		style = styles[config.style or ""] or styles.pipe
	end
	if
		config.gradient == "none" or
		config.gradient == nil or
		(gradients[config.gradient] == nil and
			type(config.gradient) == "string") then
		return style
	end
	local topSection = style
	local gradient = gradients[config.gradient]
	if type(config.gradient) == "table" then
		gradient = config.gradient
	end
	local ret = {}
	for j, v in pairs(topSection) do
		---@type SpaceportWord[]
		local line = {}
		local actualI = 1
		local i = 1
		while actualI <= #v do
			local color = { red = 0, green = 0, blue = 0 }
			for _, grad in ipairs(gradient) do
				color = addColors(color, getGradientColorAt(grad, j, i, #topSection[1], #topSection))
			end
			local hex = string.format("#%02x%02x%02x", color.red, color.green, color.blue)
			local cplen = require("spaceport.screen").codepointLen(v:sub(actualI, actualI))
			local char = v:sub(actualI, actualI + cplen - 1)
			---@type SpaceportWord
			local word = { char, colorOpts = { foreground = hex } }
			table.insert(line, word)
			actualI = actualI + cplen
			i = i + 1
		end
		table.insert(ret, line)
	end
	return ret
end

---@type SpaceportScreen
local r = {
	lines = l,
	remaps = {},
	title = nil,
	topBuffer = 1,
	config = {
		style = "hash",
		gradient = "none"
	},

}

return r
