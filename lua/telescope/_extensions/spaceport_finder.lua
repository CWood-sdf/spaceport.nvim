local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

return function (opts)
    opts = opts or require("telescope.themes").get_dropdown({})
    pickers
        .new(opts, {
            prompt_title = "Find Spaceport Directory",
            finder = finders.new_oneshot_job({ "find" }, {
                entry_maker = function (entry)
                    if entry:gsub(".git", "") ~= entry then
                        return nil
                    end
                    if entry:sub(1, 1) == "." then
                        entry = vim.loop.cwd() .. entry:sub(2)
                    end
                    return {
                        value = entry,
                        display = require("spaceport")._fixDir(entry),
                        ordinal = entry,
                    }
                end,
            }),
            sorter = conf.generic_sorter(opts),
            ---@diagnostic disable-next-line: unused-local
            attach_mappings = function (prompt_bufnr, map)
                actions.select_default:replace(function ()
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    require("spaceport.data").cd({
                        time = require("spaceport.utils").getSeconds(),
                        prettyDir = selection.value,
                        dir = selection.value,
                        isDir = require("spaceport.data").isdir(
                            selection.value),
                        pinNumber = 0,
                    })
                end)
                return true
            end,
        })
        :find()
end
