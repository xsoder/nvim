vim.keymap.set("n", "<leader>gs", vim.cmd.Git)

local csode_Fugitive = vim.api.nvim_create_augroup("csode_Fugitive", {})

local autocmd = vim.api.nvim_create_autocmd
autocmd("BufWinEnter", {
	group = csode_Fugitive,
	pattern = "*",
	callback = function()
		if vim.bo.filetype ~= "fugitive" then
			return
		end

		local bufnr = vim.api.nvim_get_current_buf()
		local opts = { buffer = bufnr, remap = false }

		vim.keymap.set("n", "<leader>p", function()
			vim.cmd.Git("push")
		end, opts)

		vim.keymap.set("n", "<leader>P", function()
			vim.cmd.Git({ "pull", "--rebase" })
		end, opts)

		vim.keymap.set("n", "<leader>tt", ":Git push -u origin ", opts)
	end,
})

vim.keymap.set("n", "gu", "<cmd>diffget //2<CR>")
vim.keymap.set("n", "gh", "<cmd>diffget //3<CR>")
