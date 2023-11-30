---@type (string|SpaceportWord[])[]
local topSection = {
	{ { "### ###  #  ### ### ### ### ###  ###" } },
	"#   # # # # #   #   # # # # #  #  # ",
	"### ### ### #   ##  ### # # ###   # ",
	"  # #   # # #   #   #   # # #  #  # ",
	"### #   # # ### ### #   ### #  #  # ",
}
---@type SpaceportScreen
local r = {
	lines = topSection,
	remaps = {},
	title = nil,
	topBuffer = 1,
}

return r
