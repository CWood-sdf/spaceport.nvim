local topStories = {}
local hasDone = false
vim.fn.jobstart("curl https://hacker-news.firebaseio.com/v0/topstories.json -s", {
	on_exit = function(_, _) end,
	on_stdout = function(_, data, _)
		data = vim.fn.json_decode(data)
		for i = 1, 5 do
			topStories[i] = { title = "Loading..." }
			local iCopy = i + 1 - 1
			vim.fn.jobstart("curl https://hacker-news.firebaseio.com/v0/item/" .. data[i] .. ".json -s", {
				on_exit = function(_, _) end,
				on_stdout = function(_, d, _)
					local item = vim.fn.json_decode(d)
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
			action = function(_, count)
				if count == 0 then
					return
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
