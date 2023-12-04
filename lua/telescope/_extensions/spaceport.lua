local telescope = require("telescope")

return telescope.register_extension({
	exports = {
		projects = require("telescope._extensions.spaceport_mru"),
	},
})
