# Neovim
## Neovim Configuration

My personal Neovim configuration focused on development workflow.

## Installation

1. Clone this repository to your Neovim config directory:
```bash
git clone https://github.com/xsoder/nvim.git ~/.config/nvim
```

2. Open Neovim and install plugins:
```bash
nvim
:PackerSync
```

3. Install LSP servers:
```bash
:Mason
```

## Key Bindings

Leader key: `<Space>`

### Navigation
- `<leader>pf` - Find files
- `<C-p>` - Git files
- `<leader>ps` - Search text
- `<leader>o` - File explorer
- `<C-h>/<C-l>` - Switch windows

### Code
- `gd` - Go to definition
- `gr` - Show references
- `K` - Show documentation
- `<leader>rn` - Rename symbol
- `<leader>ca` - Code actions

### Utilities
- `<leader>c` - Compile mode
- `<leader>gs` - Git status
- `<leader>u` - Undo tree
- `<leader>w` - Save file
- `<leader>h` - Clear search highlight

## Features

- **LSP support** with Mason for server management
- **Fuzzy finding** with Telescope
- **Git integration** with Fugitive
- **Autocompletion** with COQ
- **Syntax highlighting** with TreeSitter
- **Custom compile mode** for building projects
- **Auto-formatting** on save

## Supported Languages

- Lua (stylua)
- Python (black, pyright)
- JavaScript/TypeScript (prettier, ts_ls)
- C/C++ (clang-format, clangd)
- Shell (shfmt, bashls)

## Compile Mode

Custom interactive build system that detects project type and suggests commands:

- Rust: `cargo run`, `cargo build`, `cargo test`
- Make: `make`, `make build`
- C++: `g++ % -o %:r && ./%:r`
- Python: `python3 %`

Usage: `<leader>c` or `:CompileMode`

