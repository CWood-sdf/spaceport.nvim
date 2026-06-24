local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

return function (opts)
    opts = opts or require("telescope.themes").get_dropdown({})
    local data = require("spaceport.data").getAllData()
    data = vim.tbl_filter(function (v)
        ---@cast v SpaceportDir
        return v.tmuxWindowName ~= nil
    end, data)
    pickers
        .new(opts, {
            prompt_title = "Spaceport Tmux Windows",
            finder = finders.new_table({
                results = data,

                entry_maker = function (entry)
                    return {
                        value = entry,
                        display = entry.tmuxWindowName,
                        ordinal = entry.tmuxWindowName,
                    }
                end,
            }),
            sorter = conf.generic_sorter(opts),
            ---@diagnostic disable-next-line: unused-local
            attach_mappings = function (prompt_bufnr, map)
                actions.select_default:replace(function ()
                    local selection = action_state.get_selected_entry()
                    if selection == nil then
                        return
                    end
                    actions.close(prompt_bufnr)
                    require("spaceport.data").cd(selection.value)
                end)
                return true
            end,
        })
        :find()
end
