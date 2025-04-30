return {
	{
		dir = "~/Programming/nvim-media-tools",
		name = "media-tools",
		dependencies = {
			"nvim-telescope/telescope.nvim",
		},
		config = function()
			require("media_tools").setup()
		end,
	},
}
