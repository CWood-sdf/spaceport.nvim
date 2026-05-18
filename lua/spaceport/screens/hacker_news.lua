local storyCount = 5
local topStories = {}
local hasDone = false
local stdout = ""
local substdout = {}
for i = 1, storyCount do
    topStories[i] = { title = "Loading..." }
    substdout[i] = ""
end
vim.fn.jobstart("curl https://hacker-news.firebaseio.com/v0/topstories.json -s",
    {
        on_exit = function (_, _)

            local data = vim.json.decode(stdout) or {}
            for i = 1, storyCount do
                topStories[i] = { title = "Loading..." }
                local iCopy = i + 1 - 1
                vim.fn.jobstart(
                    "curl https://hacker-news.firebaseio.com/v0/item/" ..
                    data[i] .. ".json -s", {
                        on_exit = function (_, _) 

                            local item = vim.json.decode(substdout[i])
                            topStories[iCopy] = item
                            if not hasDone then
                                require("spaceport.screen").render()
                            end
                        end,
                        on_stdout = function (_, d, _)
                            if d[1] == "" then
                                return
                            end
                            substdout[i] = substdout[i] .. d[1]
                        end,
                    })
            end

        end,
        on_stdout = function (_, data, e)
            if e ~= "stdout" then
                return
            end
            stdout = stdout .. data[1]
            if data[1] == "" then
                return
            end
            local str = data[1]
        end,
    })



---@type SpaceportScreen
return {
    position = { row = -1, col = 1 },
    onExit = function ()
        hasDone = true
    end,
    remaps = {
        {
            key = ";",
            description = "Hacker News",
            mode = "n",
            action = function (line, count)
                if count == 0 then
                    local topStory = topStories[line]
                    if topStory then
                        vim.ui.open(topStory.url)
                    end
                elseif topStories[count] == nil then
                    print("Error getting story number " .. count)
                else
                    vim.ui.open(topStories[count].url)
                end
            end,
            visible = true,
        },
    },
    lines = function ()
        local lines = {}
        for _, item in ipairs(topStories) do
            table.insert(lines, {
                { item.title, colorOpts = { link = "String" } },
            })
        end
        while #lines < storyCount do
            table.insert(lines, {
                { " " },
            })
        end
        return lines
    end,
    title = { { require("spaceport")._getIcon("news") .. "Hacker News" } },
    topBuffer = 0,
}
