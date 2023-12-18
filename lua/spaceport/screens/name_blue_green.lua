---@type (string)[]
local topSection = {
	"### ###  #  ### ### ### ### ###  ###",
	"#   # # # # #   #   # # # # #  #  # ",
	"### ### ### #   ##  ### # # ###   # ",
	"  # #   # # #   #   #   # # #  #  # ",
	"### #   # # ### ### #   ### #  #  # ",
}

local getLines = function()
	local ret = {}
	local base = 100
	local redDepth = (255 - base) / #topSection
	for j, v in pairs(topSection) do
		---@type SpaceportWord[]
		local line = {}
		for i = 1, #v do
			local blueDepth = (255 - base) / #v
			local color = {
				blue = math.floor(redDepth * (#topSection - j) + base),
				red = 0,
				green = math.floor(blueDepth * i + base),
			}
			local hex = string.format("#%02x%02x%02x", color.red, color.green, color.blue)
			local char = v:sub(i, i)
			---@type SpaceportWord
			local word = { char, colorOpts = { foreground = hex } }
			-- if char == "#" then
			-- 	word.colorOpts = {}
			-- end
			-- if char == " " then
			-- 	word.colorOpts = {}
			-- end
			table.insert(line, word)
		end
		table.insert(ret, line)
	end
	return ret
end
---@type SpaceportScreen
local r = {
	lines = getLines,
	remaps = {},
	title = nil,
	topBuffer = 1,
}

return r
