local fn = vim.fn
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
	PACKER_BOOTSTRAP = fn.system({
		"git",
		"clone",
		"--depth",
		"1",
		"https://github.com/wbthomason/packer.nvim",
		install_path,
	})
	print("Installing packer... Restart Neovim when complete")
	vim.cmd([[packadd packer.nvim]])
end

vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]])

local status_ok, packer = pcall(require, "packer")
if not status_ok then
	return
end

packer.init({
	display = {
		open_fn = function()
			return require("packer.util").float({ border = "rounded" })
		end,
	},
})

--PLUGINS
return packer.startup(function(use)
	use("wbthomason/packer.nvim")
	use("rose-pine/neovim")
	use({
		"mbbill/undotree",
		config = function()
			require("csode.plugin_config.undotree")
		end,
	})

	use({
		"tyru/open-browser.vim",
		config = function()
			require("csode.plugin_config.browser")
		end,
	})
	use({
		"nvim-lualine/lualine.nvim",
		requires = { "nvim-tree/nvim-web-devicons", opt = true },
		config = function()
			require("csode.plugin_config.lualine")
		end,
	})
	-- packer
	use({
		"folke/todo-comments.nvim",
		requires = "nvim-lua/plenary.nvim",
		config = function()
			require("csode.plugin_config.todo")
		end,
	})
	use({
		"L3MON4D3/LuaSnip",
		config = function()
			require("csode.plugin_config.luasnip")
		end,
	})

	use("nvim-lua/plenary.nvim")
	use("nvim-lua/popup.nvim")

	use({
		"iamcco/markdown-preview.nvim",
		run = function()
			vim.fn["mkdp#util#install"]()
		end,
		setup = function()
			require("csode.plugin_config.markdown_preview")
		end,
		ft = { "markdown" },
	})

	use("kyazdani42/nvim-web-devicons") -- Icons

	use({
		"VonHeikemen/lsp-zero.nvim",
		branch = "v3.x",
		requires = {
			{ "neovim/nvim-lspconfig" },
			{ "williamboman/mason.nvim" },
			{ "williamboman/mason-lspconfig.nvim" },
			{ "hrsh7th/nvim-cmp" },
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "L3MON4D3/LuaSnip" },
		},
		config = function()
			require("csode.plugin_config.lsp-zero") -- or your config file path
		end,
	})

	use({
		"nvim-treesitter/nvim-treesitter",
		run = ":TSUpdate",
		config = function()
			require("csode.plugin_config.treesitter")
		end,
	})

	use({
		"nvim-orgmode/orgmode",
		ft = { "org" },
		config = function()
			require("csode.plugin_config.orgmode")
		end,
	})

	use({
		"nvim-telescope/telescope.nvim",
		-- Telescope + extensions
		tag = "0.1.5",
		requires = {
			"nvim-lua/plenary.nvim",
			{ "nvim-telescope/telescope-fzf-native.nvim", run = "make" },
		},
		config = function()
			require("csode.plugin_config.telescope")
		end,
	})

	use({
		"xsoder/buffer-manager.nvim",
		config = function()
			require("csode.plugin_config.buffer-manager")
		end,
	})

	use({
		"folke/tokyonight.nvim",
		config = function()
			require("csode.plugin_config.tokyonight")
		end,
	})
	use({
		"ms-jpq/coq_nvim",
		branch = "coq",
		requires = {
			{ "ms-jpq/coq.artifacts", branch = "artifacts" }, -- required for completions
			{ "ms-jpq/coq.thirdparty", branch = "3p" }, -- optional: third-party sources
		},
	})
	use({
		"tpope/vim-fugitive",
		config = function()
			require("csode.plugin_config.fugitive")
		end,
	})

	-- Org Bullets (Prettier headlines)
	use({
		"akinsho/org-bullets.nvim",
		ft = "org",
		config = function()
			require("org-bullets").setup({
				symbols = {
					headlines = { "◉", "○", "✸", "◆" }, -- Custom bullet symbols
					checkboxes = {
						cancelled = "",
						done = "✓",
						todo = "˟",
					},
				},
			})
		end,
	})

	use({
		"stevearc/conform.nvim",
		config = function()
			require("csode.plugin_config.conform")
		end,
	})

	if PACKER_BOOTSTRAP then
		require("packer").sync()
	end
end)
