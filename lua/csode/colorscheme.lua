local colorscheme = "gruber-darker"

local status_ok, _ = pcall(vim.cmd, "colorscheme " .. colorscheme)
	-- vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
if not status_ok then
    vim.notify("colorscheme " .. colorscheme .. " not found!")
    vim.o.background = 'dark'
    return
end

