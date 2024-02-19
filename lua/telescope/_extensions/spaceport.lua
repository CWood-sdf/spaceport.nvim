local telescope = require("telescope")

return telescope.register_extension({
    exports = {
        projects = require("telescope._extensions.spaceport_mru"),
        tmux_windows = require("telescope._extensions.spaceport_tmux_windows"),
        tmux_sessions = require("telescope._extensions.spaceport_tmux_sessions"),
        find = require("telescope._extensions.spaceport_finder"),
    },
})
