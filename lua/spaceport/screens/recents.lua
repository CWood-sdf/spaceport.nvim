local linesToDir = {}
---@return (string|SpaceportWord[])[]
local function l()
	local mru = require("spaceport.data").getMruData()
	local pinned = require("spaceport.data").getPinnedData()
	local lines = {}
	local i = 1
	local largestLen = 0
	for _, v in ipairs(mru) do
		local len = #v.prettyDir + #(i .. "")
		if len > largestLen then
			largestLen = len
		end
	end
	for _, v in ipairs(pinned) do
		local len = #v.prettyDir + #(i .. "")
		if len > largestLen then
			largestLen = len
		end
	end
	largestLen = largestLen + 10
	if #pinned > 0 then
		lines = {
			"",
			"Pinned",
		}
		for _, v in ipairs(pinned) do
			linesToDir[#lines + 1] = v.dir
			table.insert(lines, require("spaceport.screen").setWidth({ v.prettyDir, i .. "" }, largestLen))
			i = i + 1
		end
	end

	return lines
end

---@type SpaceportScreen
local r = {
	lines = l,
	remaps = {
		{
			key = "p",
			description = "Select project",
			action = function(line, count)
				if count ~= 0 then
					local pinned = require("spaceport.data").getPinnedData()
					if count <= #pinned then
						require("spaceport.data").cd(pinned[count])
						return
					end
					local mru = require("spaceport.data").getMruData()
					if count <= #pinned + #mru then
						require("spaceport.data").cd(mru[count - #pinned])
						return
					end
					print("Invalid number")
				else
					if linesToDir[line] == nil then
						print("Not hovering over a project")
						return
					end
					require("spaceport.data").cd(linesToDir[line])
				end
			end,
			mode = "n",
		},
	},
	title = nil,
	topBuffer = 0,
}
return r
