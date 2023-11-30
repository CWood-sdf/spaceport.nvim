---@return (string|SpaceportWord[])[]
local function l()
	local sections = require("spaceport.screen").getActualScreens()
	local lines = {}
	local largestLen = 0
	for _, section in ipairs(sections) do
		local remaps = section.remaps or {}
		for _, remap in ipairs(remaps) do
			if not remap.allowOutsideBuffer and remap.allowOutsideBuffer ~= nil then
				goto continue
			end
			local len = #remap.key + #remap.description
			if len > largestLen then
				largestLen = len
			end
			::continue::
		end
	end
	largestLen = largestLen + 10

	for _, section in ipairs(sections) do
		local remaps = section.remaps or {}
		for _, remap in ipairs(remaps) do
			if not remap.allowOutsideBuffer and remap.allowOutsideBuffer ~= nil then
				goto continue
			end
			table.insert(lines, require("spaceport.screen").setWidth({ remap.description, remap.key }, largestLen))
			::continue::
		end
	end
	return lines
end

---@type SpaceportScreen
local r = {
	lines = l,
	remaps = {},
	title = "Remaps",
	topBuffer = 1,
}

return r
