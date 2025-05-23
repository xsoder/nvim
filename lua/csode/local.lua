-- Local plugins configuration
local M = {}

-- Load local plugins
M.load = function()
    -- Load nvim_compile plugin
    require("csode.local_plugins.nvim_compile")
end

return M 