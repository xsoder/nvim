vim.g.mapleader = " "

vim.cmd([[nnoremap <C-h> <C-w>h]])
vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

vim.keymap.set("n", "<leader>h", ":nohlsearch<CR>")
vim.keymap.set("n", "<leader>o", ":Ex<CR>")
vim.keymap.set("n", "<leader>w", ":w<CR>")
vim.keymap.set("n", "<Leader>q", "<cmd>q!<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>fq", function()
    vim.diagnostic.setqflist({})
end, { noremap = true, silent = true, desc = "Send diagnostics to quickfix (no UI)" })

vim.api.nvim_set_keymap(
    "n",
    "<Leader><leader>r",
    ":luafile ~/.config/nvim/init.lua<CR>",
    { noremap = true, silent = true }
)

vim.api.nvim_set_keymap("v", "y", '"+y', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "yy", '"+yy', { noremap = true, silent = true })

vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- Movement and selection
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Special features
vim.keymap.set("n", "<leader>zig", "<cmd>LspRestart<cr>")

-- Register operations
vim.keymap.set("x", "<leader>p", [["_dP]])
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d')

--vim.keymap.set("n", "<leader>tt", "<cmd>TodoQuickFix<CR>")
-- Navigation and quickfix list
-- vim.keymap.set("n", "<C-j>", "<cmd>cnext<CR>zz")
-- vim.keymap.set("n", "<C-k>", "<cmd>cprev<CR>zz")
-- vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
-- vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

-- Error handling snippets
vim.keymap.set("n", "<leader>ee", "oif err != nil {<CR>}<Esc>Oreturn err<Esc>")
vim.keymap.set("n", "<leader>ea", 'oassert.NoError(err, "")<Esc>F";a')
vim.keymap.set("n", "<leader>el", 'oif err != nil {<CR>}<Esc>O.logger.Error("error", "error", err)<Esc>F.;i')

-- Misc mappings
vim.keymap.set("i", "<C-c>", "<Esc>")
vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

vim.api.nvim_set_keymap(
    "n",
    "<Leader>tp",
    ':silent !tmux new-window "fish -c \\"exec fish\\"" <CR>',
    { noremap = true, silent = true }
)

-- Local Plugins mapping
vim.keymap.set("n", "<leader>td", function()
    vim.cmd("Td")
end, { noremap = true, silent = true, desc = "Todo mode" })

vim.keymap.set("n", "<leader>mm", function()
    vim.cmd("FollowMarkdownLink")
end, { noremap = true, silent = true, desc = "Todo" })
-- Keybind to show all custom keymaps
vim.keymap.set("n", "<leader>?", function()
    require("telescope.builtin").keymaps({
        modes = { "n", "i", "v", "x", "s", "o", "t", "c" },
        show_plug = false,
    })
end, { desc = "Show all keybindings" })
-- Toggle task completion
vim.keymap.set("n", "<leader>tt", function()
  local line = vim.api.nvim_get_current_line()
  if line:match("%[ %]") then
    line = line:gsub("%[ %]", "[x]")
  elseif line:match("%[x%]") then
    line = line:gsub("%[x%]", "[ ]")
  else
    line = "- [ ] " .. line
  end
  vim.api.nvim_set_current_line(line)
end, { desc = "Toggle todo checkbox" })
-- Move completed task to # Completed
vim.keymap.set("n", "<C-e>", function()
  local line_num = vim.fn.line(".")
  local line = vim.fn.getline(line_num)

  -- Mark as completed
  if not line:match("%[x%]") then
    line = line:gsub("%[ %]", "[x]")
    if not line:match("%[x%]") then
      line = "- [x] " .. line
    end
  end

  -- Remove current line
  vim.fn.setline(line_num, "")
  vim.cmd(line_num .. "delete")

  -- Find "# Completed"
  local target_line = -1
  local total = vim.fn.line("$")
  for i = 1, total do
    if vim.fn.getline(i):match("^# Completed") then
      target_line = i
      break
    end
  end

  if target_line > 0 then
    vim.fn.append(target_line, line)
  else
    vim.fn.append(total, { "# Completed", line })
  end
end, { desc = "Complete and move task to # Completed" })

-- Move task from # Completed back to # Todo
vim.keymap.set("n", "<C-r>", function()
  local line_num = vim.fn.line(".")
  local line = vim.fn.getline(line_num)

  if not line:match("%[x%]") then return end

  -- Mark as not completed
  line = line:gsub("%[x%]", "[ ]")

  -- Remove current line
  vim.fn.setline(line_num, "")
  vim.cmd(line_num .. "delete")

  -- Find "# Todo"
  local target_line = -1
  local total = vim.fn.line("$")
  for i = 1, total do
    if vim.fn.getline(i):match("^# Todo") then
      target_line = i
      break
    end
  end

  if target_line > 0 then
    vim.fn.append(target_line, line)
  else
    vim.fn.append(0, { "# Todo", line })
  end
end, { desc = "Restore task to # Todo" })
vim.keymap.set('n', '<leader>cc', function()
  vim.cmd('belowright Compile')
end, { desc = 'Run Compile with belowright split' })

