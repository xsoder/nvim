return {
    'stevearc/conform.nvim',
    opts = {
        -- Map of filetype to formatters
        formatters_by_ft = {
            -- C/C++
            c = { "clang-format", lsp_format = "fallback" },
            cpp = { "clang-format", lsp_format = "fallback" },

            -- Lua
            lua = { "stylua" },
            -- Go (run multiple formatters sequentially)
            go = { "goimports", "gofmt", "trim_whitespace" },
            -- Alternative: Let gopls handle Go formatting
            -- go = { lsp_format = "prefer" },

            -- Rust
            rust = { "rustfmt", lsp_format = "fallback" },

            -- Python (dynamic formatter selection)
            python = function(bufnr)
                if require("conform").get_formatter_info("ruff_format", bufnr).available then
                    return { "ruff_format" }
                else
                    return { "isort", "black" }
                end
            end,

            -- JavaScript/TypeScript
            javascript = { "prettier", lsp_format = "fallback" },
            typescript = { "prettier", lsp_format = "fallback" },
            javascriptreact = { "prettier", lsp_format = "fallback" },
            typescriptreact = { "prettier", lsp_format = "fallback" },

            -- Web technologies
            html = { "prettier", lsp_format = "fallback" },
            css = { "prettier", lsp_format = "fallback" },
            scss = { "prettier", lsp_format = "fallback" },

            -- Data formats
            json = { "prettier" },
            jsonc = { "prettier" },
            yaml = { "prettier" },
            toml = { "taplo", lsp_format = "fallback" },
            xml = { "xmlformat", lsp_format = "fallback" },

            -- Documentation
            markdown = { "prettier", lsp_format = "fallback" },

            -- Java
            java = { lsp_format = "prefer" },

            -- C#
            cs = { lsp_format = "prefer" },

            -- PHP
            php = { "php_cs_fixer", lsp_format = "fallback" },

            -- Shell scripts
            sh = { "shfmt", lsp_format = "fallback" },
            bash = { "shfmt", lsp_format = "fallback" },

            -- Zig
            zig = { "zigfmt", lsp_format = "fallback" },

            -- Dart
            dart = { "dart_format", lsp_format = "fallback" },

            -- Ruby
            ruby = { "rubocop", lsp_format = "fallback" },

            -- Use the "*" filetype to run formatters on all filetypes.
            ["*"] = { "codespell" },
            -- Use the "_" filetype to run formatters on filetypes that don't
            -- have other formatters configured.
            ["_"] = { "trim_whitespace" },
        },
        -- Set this to change the default values when calling conform.format()
        -- This will also affect the default values for format_on_save/format_after_save
        default_format_opts = {
            lsp_format = "fallback",
        },
        -- Removed format_on_save to avoid conflicts with our custom autocmd
        -- If this is set, Conform will run the formatter asynchronously after save.
        -- It will pass the table to conform.format().
        -- This can also be a function that returns the table.
        format_after_save = {
            lsp_format = "fallback",
        },
        -- Set the log level. Use `:ConformInfo` to see the location of the log file.
        log_level = vim.log.levels.ERROR,
        -- Conform will notify you when a formatter errors
        notify_on_error = true,
        -- Conform will notify you when no formatters are available for the buffer
        notify_no_formatters = false, -- Set to true if you want notifications when no formatters are found
        -- Custom formatters and overrides for built-in formatters
        formatters = {
            my_formatter = {
                -- This can be a string or a function that returns a string.
                -- When defining a new formatter, this is the only field that is required
                command = "my_cmd",
                -- A list of strings, or a function that returns a list of strings
                -- Return a single string instead of a list to run the command in a shell
                args = { "--stdin-from-filename", "$FILENAME" },
                -- If the formatter supports range formatting, create the range arguments here
                range_args = function(self, ctx)
                    return { "--line-start", ctx.range.start[1], "--line-end", ctx.range["end"][1] }
                end,
                -- Send file contents to stdin, read new contents from stdout (default true)
                -- When false, will create a temp file (will appear in "$FILENAME" args). The temp
                -- file is assumed to be modified in-place by the format command.
                stdin = true,
                -- A function that calculates the directory to run the command in
                cwd = require("conform.util").root_file({ ".editorconfig", "package.json" }),
                -- When cwd is not found, don't run the formatter (default false)
                require_cwd = true,
                -- When stdin=false, use this template to generate the temporary file that gets formatted
                tmpfile_format = ".conform.$RANDOM.$FILENAME",
                -- When returns false, the formatter will not be used
                condition = function(self, ctx)
                    return vim.fs.basename(ctx.filename) ~= "README.md"
                end,
                -- Exit codes that indicate success (default { 0 })
                exit_codes = { 0, 1 },
                -- Environment variables. This can also be a function that returns a table.
                env = {
                    VAR = "value",
                },
                -- Set to false to disable merging the config with the base definition
                inherit = true,
                -- When inherit = true, add these additional arguments to the beginning of the command.
                -- This can also be a function, like args
                prepend_args = { "--use-tabs" },
                -- When inherit = true, add these additional arguments to the end of the command.
                -- This can also be a function, like args
                append_args = { "--trailing-comma" },
            },
            -- These can also be a function that returns the formatter
            other_formatter = function(bufnr)
                return {
                    command = "my_cmd",
                }
            end,
        },
    },
    config = function(_, opts)
        require("conform").setup(opts)

        -- Simple and reliable autocmd for format on save
        vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = "*",
            callback = function()
                -- Format the buffer with all applicable formatters
                require("conform").format({
                    lsp_format = "fallback",
                    timeout_ms = 2000, -- Increased timeout for multiple formatters
                    quiet = false,     -- Show errors if any
                })
            end,
        })

        -- Optional: Set up a keymap to manually format (keeping for manual testing)
        vim.keymap.set({ "n", "v" }, "<leader>mp", function()
            require("conform").format({
                lsp_format = "fallback",
                async = false,
                timeout_ms = 2000,
                quiet = false,
            })
        end, { desc = "Format file or range (in visual mode)" })

        -- Debug keymap to check formatter availability
        vim.keymap.set("n", "<leader>ci", function()
            local conform = require("conform")
            local formatters = conform.list_formatters()
            print("Available formatters for " .. vim.bo.filetype .. ":")
            for _, formatter in ipairs(formatters) do
                print("  " .. formatter.name .. " - " .. (formatter.available and "✓" or "✗"))
            end

            -- Show what formatters will actually run
            local bufnr = vim.api.nvim_get_current_buf()
            local selected_formatters = conform.list_formatters(bufnr)
            print("Selected formatters:")
            for _, formatter in ipairs(selected_formatters) do
                print("  " .. formatter.name)
            end
        end, { desc = "Show conform info" })
    end,
}
