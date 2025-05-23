-- Local plugins configuration
local M = {}

-- Load local plugins
M.load = function()
	-- Load nvim_compile plugin
	require("csode.local_plugins.nvim_compile")
	require("csode.local_plugins.markdown_link_nav")
	require("csode.local_plugins.todo")
end

return M

