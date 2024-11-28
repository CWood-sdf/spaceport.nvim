local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

return function (opts)
    opts = opts or require("telescope.themes").get_dropdown({})
    pickers
        .new(opts, {
            prompt_title = "Spaceport Projects",
            finder = finders.new_table({
                results = require("spaceport.data").getAllData(),

                entry_maker = function (entry)
                    return {
                        value = entry,
                        display = entry.prettyDir,
                        ordinal = entry.prettyDir,
                    }
                end,
            }),
            sorter = conf.generic_sorter(opts),
            ---@diagnostic disable-next-line: unused-local
            attach_mappings = function (prompt_bufnr, map)
                actions.select_default:replace(function ()
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    require("spaceport.data").cd(selection.value)
                end)
                return true
            end,
        })
        :find()
end
