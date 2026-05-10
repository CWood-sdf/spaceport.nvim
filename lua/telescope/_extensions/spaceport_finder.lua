local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

---@param gitDir string
---@return string
local function toProjectDir(gitDir)
    local normalized = gitDir:gsub("/+$", "")
    if normalized:sub(-5) == "/.git" then
        return normalized:sub(1, -6)
    end
    return vim.fn.fnamemodify(normalized, ":h")
end

return function (opts)
    opts = opts or require("telescope.themes").get_dropdown({})
    local projectHomes = require("spaceport")._getProjectHomes()
    local cmd = {
        "fd",
        "--type", "d",
        "--hidden",
        "--no-follow",
        "--absolute-path",
        "--regex", "^\\.git$",
    }
    for _, home in ipairs(projectHomes) do
        table.insert(cmd, home)
    end

    local fdMatches = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 then
        require("spaceport").log("spaceport.find failed to run fd")
        return
    end

    local seen = {}
    local projects = {}
    for _, gitDir in ipairs(fdMatches) do
        local projectDir = toProjectDir(gitDir)
        if not seen[projectDir] then
            seen[projectDir] = true
            table.insert(projects, projectDir)
        end
    end

    pickers
        .new(opts, {
            prompt_title = "Find Spaceport Directory",
            finder = finders.new_table({
                results = projects,
                entry_maker = function (entry)
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
