local conform = require("conform")

conform.setup({
  -- Automatically format on save
  format_on_save = {
    lsp_fallback = true,  -- fallback to conform if no LSP formatter available
    timeout_ms = 500,
  },

  -- Define formatters per filetype
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "black" },
    javascript = { "prettier" },
    typescript = { "prettier" },
    json = { "prettier" },
    html = { "prettier" },
    css = { "prettier" },
    sh = { "shfmt" },
    cpp = { "clang_format" },
    c = { "clang_format" },
  },
})

