local topStories = {}
local hasDone = false
vim.fn.jobstart("curl https://hacker-news.firebaseio.com/v0/topstories.json -s", {
    on_exit = function(_, _) end,
    on_stdout = function(_, data, e)
        if e ~= "stdout" then
            return
        end
        if data[1] == "" then
            return
        end
        -- -- print(vim.inspect(data))
        -- local o, f = pcall(vim.json.decode, data[1])
        -- if not o then
        --     print(data[1])
        --     return
        -- end
        data = vim.json.decode(data[1]) or {}
        -- print(data)
        for i = 1, 5 do
            topStories[i] = { title = "Loading..." }
            local iCopy = i + 1 - 1
            vim.fn.jobstart("curl https://hacker-news.firebaseio.com/v0/item/" .. data[i] .. ".json -s", {
                on_exit = function(_, _) end,
                on_stdout = function(_, d, _)
                    if d[1] == "" then
                        return
                    end
                    local item = vim.json.decode(d[1])
                    topStories[iCopy] = item
                    -- vim.fn.timer_start(10, function()
                    -- 	print(#topStories)
                    if not hasDone then
                        require("spaceport.screen").render()
                        print(" ")
                    end
                    -- end)
                end,
            })
        end
    end,
})

---@type SpaceportScreen
return {
    position = { row = -1, col = 1 },
    onExit = function()
        hasDone = true
    end,
    remaps = {
        {
            key = ";",
            description = "Hacker News",
            mode = "n",
            action = function(line, count)
                if count == 0 then
                    local topStory = topStories[line]
                    if topStory then
                        print(topStory.url)
                    end
                elseif topStories[count] == nil then
                    print("Error getting story number " .. count)
                else
                    print(topStories[count].url)
                end
            end,
            visible = true,
        },
    },
    lines = function()
        local lines = {}
        print(" ")
        for _, item in ipairs(topStories) do
            table.insert(lines, {
                { item.title, colorOpts = { link = "String" } },
            })
        end
        while #lines < 5 do
            table.insert(lines, {
                { " " },
            })
        end
        return lines
    end,
    title = "Hacker News",
    topBuffer = 0,
}
