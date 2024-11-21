---@return (string|SpaceportWord[])[]
local function l()
    local sections = require("spaceport.screen").getActualScreens()
    local lines = { { { "Remaps", colorOpts = { _name = "SpaceportRemapTitle" } } } }
    local largestLen = 0
    for _, section in ipairs(sections) do
        local remaps = section.remaps or {}
        for _, remap in ipairs(remaps) do
            if not remap.visible and remap.visible ~= nil then
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
            if not remap.visible and remap.visible ~= nil then
                goto continue
            end
            ---@type SpaceportWord[]
            local words = {
                { remap.description, colorOpts = { _name = "SpaceportRemapDescription" } },
                { remap.key, colorOpts = { _name = "SpaceportRemapKey" } },
            }
            table.insert(lines, require("spaceport.screen").setWidthWords(words, largestLen))
            ::continue::
        end
    end
    return lines
end

---@type SpaceportScreen
local r = {
    lines = l,
    remaps = {},
    title = nil,
    topBuffer = 1,
}

return r
