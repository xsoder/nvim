-- Minimal compile mode for Neovim with error line highlighting and navigation.

local M = {}

-- Compile command history
local compile_history = {}
local MAX_HISTORY = 20 -- Maximum number of commands to store in history

-- Stores the ID of the compile output buffer for reuse across runs
local compile_output_buf_id = nil
-- Stores the ID of the window where the compile output is displayed
local compile_output_win_id = nil

--- Adds a command to the compile history, ensuring no duplicates at the top
--- and maintaining a maximum history size.
-- @param command string The command string to add.
local function add_to_history(command)
    if #compile_history == 0 or compile_history[1] ~= command then
        table.insert(compile_history, 1, command)
        if #compile_history > MAX_HISTORY then
            table.remove(compile_history) -- Remove the oldest command if history is full
        end
    end
end

--- Checks if the current working directory contains a 'CMakeLists.txt' file,
--- indicating a CMake project.
-- @return boolean True if 'CMakeLists.txt' exists, false otherwise.
local function is_cmake_project()
    return vim.fn.filereadable("CMakeLists.txt") == 1
end

--- Prompts the user to enter a compile command.
--- Provides command history completion using a custom Lua function.
-- @return string The command entered by the user. Returns an empty string if cancelled.
local function get_user_command()
    local prompt = "[Compile] Enter command: "
    return vim.fn.input(prompt, "", "custom,v:lua.require'nvim_compile'.get_completions")
end

--- Shows the first error in the status bar
-- @param error_entry table The error to display
local function show_error_in_statusline(error_entry)
    if not error_entry then return end
    local status_msg = string.format("%s:%d:%d: %s: %s",
        error_entry.filename, error_entry.lnum, error_entry.col,
        error_entry.type == "E" and "error" or "warning",
        error_entry.text)
    vim.api.nvim_echo({ { status_msg, error_entry.type == "E" and "ErrorMsg" or "WarningMsg" } }, false, {})
end

--- Jumps to the specified error location.
--- This function will open the file in the *most appropriate existing window*
--- or a new split if the file is not open, and then move the cursor.
-- @param error_entry table The error entry to jump to (must contain filename, lnum, col)
local function jump_to_error(error_entry)
    if not error_entry then return end

    local filepath = error_entry.filename
    local target_lnum = error_entry.lnum
    local target_col = error_entry.col

    -- Resolve the file path relative to the current working directory
    -- if the file is not directly readable.
    if vim.fn.filereadable(filepath) == 0 then
        local cwd = vim.fn.getcwd()
        local new_filepath = cwd .. "/" .. filepath
        -- On Windows, replace forward slashes with backslashes
        if vim.fn.has("win32") == 1 then
            new_filepath = new_filepath:gsub("/", "\\")
        end
        if vim.fn.filereadable(new_filepath) == 1 then
            filepath = new_filepath
        else
            vim.api.nvim_echo({ { "File not found: " .. filepath, "ErrorMsg" } }, false, {})
            return
        end
    end

    -- Find an existing window displaying the target file, or open it
    local target_buf_id = vim.fn.bufnr(filepath)
    local target_win_id = nil

    if target_buf_id ~= -1 then
        -- Check if the buffer is already open in any window
        for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(win_id) == target_buf_id then
                target_win_id = win_id
                break
            end
        end
    end

    local original_win_id = vim.api.nvim_get_current_win() -- Store current window ID

    if target_win_id then
        -- If the file is already open, jump to that window
        vim.api.nvim_set_current_win(target_win_id)
    else
        -- If not open, open it in a new split (e.g., horizontal split)
        -- You can change this to 'vsplit' or 'edit' based on preference
        vim.cmd("split")
        vim.cmd(string.format("buffer %d", target_buf_id ~= -1 and target_buf_id or vim.fn.bufadd(filepath)))
        vim.api.nvim_set_current_buf(vim.fn.bufnr(filepath))
    end

    -- Move cursor to the error location
    -- lnum is 1-based, col is 1-based, but nvim_win_set_cursor expects 0-based column
    vim.api.nvim_win_set_cursor(0, { target_lnum, target_col - 1 })
    vim.cmd("normal! zz") -- Center the view on the cursor line
    vim.cmd("normal! ^")  -- Move to the first non-blank character of the line
end

--- Parses a specific line in the compile output buffer to extract error information.
--- This is used by the custom <CR> mapping in the output buffer.
-- @param buf_id number The buffer ID of the compile output buffer.
-- @param line_num number The 1-based line number to parse.
-- @return table|nil The error entry if the line matches any known error pattern, nil otherwise.
local function parse_error_line(buf_id, line_num)
    local line = vim.api.nvim_buf_get_lines(buf_id, line_num - 1, line_num, false)[1]
    if not line then return nil end

    -- Define multiple patterns to handle various compiler/linter outputs
    local patterns = {
        -- Standard GCC/Clang: file:line:col: type: message
        "([^:]+):(%d+):(%d+):%s*(error|warning):%s*(.*)",
        -- GCC/Clang without column: file:line: type: message
        "([^:]+):(%d+):%s*(error|warning):%s*(.*)",
        -- Some compilers with range: file:line.start-line.end: type: message
        "([^:]+):(%d+)%.%d+%-(%d+)%.%d+:%s*(error|warning):%s*(.*)",
        -- MSVC/some others: file(line): type: message
        "([^%(]+)%((%d+)%)%s*:%s*(error|warning):%s*(.*)",
        -- Python/Lua tracebacks (basic): file:line: message
        "([^:]+):(%d+):%s*(.*)",
    }

    for _, pattern in ipairs(patterns) do
        local file, line_num_str, col_num_str, type_str, text
        -- Try to match with different capture groups based on pattern
        if pattern == "([^:]+):(%d+):(%d+):%s*(error|warning):%s*(.*)" then
            file, line_num_str, col_num_str, type_str, text = line:match(pattern)
        elseif pattern == "([^:]+):(%d+):%s*(error|warning):%s*(.*)" then
            file, line_num_str, type_str, text = line:match(pattern)
            col_num_str = "1" -- Default column to 1 if not present
        elseif pattern == "([^:]+):(%d+)%.%d+%-(%d+)%.%d+:%s*(error|warning):%s*(.*)" then
            -- For ranges, we'll just take the start line/col for simplicity
            local start_line, start_col
            file, start_line, start_col, type_str, text = line:match(pattern)
            line_num_str = start_line
            col_num_str = start_col or "1"
        elseif pattern == "([^%(]+)%((%d+)%)%s*:%s*(error|warning):%s*(.*)" then
            file, line_num_str, type_str, text = line:match(pattern)
            col_num_str = "1"                          -- Default column to 1 if not present
        elseif pattern == "([^:]+):(%d+):%s*(.*)" then -- Generic file:line: message (e.g., Python tracebacks)
            file, line_num_str, text = line:match(pattern)
            col_num_str = "1"
            type_str = "E" -- Assume error for generic case
        end


        if file then
            return {
                filename = file,
                lnum = tonumber(line_num_str),
                col = tonumber(col_num_str) or 1,                      -- Ensure column is at least 1
                type = type_str and type_str:sub(1, 1):upper() or "E", -- Default to Error if type not captured
                text = text,
            }
        end
    end
    return nil
end

--- Sets up a key mapping for <CR> (Enter) in the compile output buffer.
--- When <CR> is pressed, it attempts to parse the current line as an error
--- and jumps to the corresponding file location.
-- @param buf_id number The buffer ID of the compile output buffer.
local function setup_compile_buffer_keymaps(buf_id)
    local opts = { buffer = buf_id, noremap = true, silent = true }
    vim.keymap.set('n', '<CR>', function()
        local cursor_pos = vim.api.nvim_win_get_cursor(0) -- Get cursor position in current window
        local line_num = cursor_pos[1]                    -- 1-based line number
        local error_entry = parse_error_line(buf_id, line_num)
        if error_entry then
            jump_to_error(error_entry)
        else
            vim.api.nvim_echo({ { "No error on this line", "WarningMsg" } }, false, {})
        end
    end, opts)
end

--- Highlights error and warning lines in the compile output buffer using Neovim's extmarks.
--- Also shows the first error in the status line and a summary message.
-- @param output string The complete output string from the executed compile command.
-- @param output_buf number The buffer ID of the compile output buffer.
local function highlight_errors(output, output_buf)
    local first_error = nil
    local error_count = 0
    local warning_count = 0

    -- Reuse the same patterns as parse_error_line for consistency
    local patterns_for_highlight = {
        "([^:]+):(%d+):(%d+):%s*(error|warning):%s*(.*)",
        "([^:]+):(%d+):%s*(error|warning):%s*(.*)",
        "([^:]+):(%d+)%.%d+%-(%d+)%.%d+:%s*(error|warning):%s*(.*)",
        "([^%(]+)%((%d+)%)%s*:%s*(error|warning):%s*(.*)",
        "([^:]+):(%d+):%s*(.*)", -- Generic file:line: message
    }

    local line_number = 0
    local ns_id = vim.api.nvim_create_namespace("compile_errors")
    vim.api.nvim_buf_clear_namespace(output_buf, ns_id, 0, -1) -- Clear previous highlights

    for line in output:gmatch("([^\n]+)") do
        line_number = line_number + 1
        for _, pattern in ipairs(patterns_for_highlight) do
            local file, line_num_str, col_num_str, type_str, text
            -- Re-apply the matching logic to correctly extract info for highlighting
            if pattern == "([^:]+):(%d+):(%d+):%s*(error|warning):%s*(.*)" then
                file, line_num_str, col_num_str, type_str, text = line:match(pattern)
            elseif pattern == "([^:]+):(%d+):%s*(error|warning):%s*(.*)" then
                file, line_num_str, type_str, text = line:match(pattern)
                col_num_str = "1"
            elseif pattern == "([^:]+):(%d+)%.%d+%-(%d+)%.%d+:%s*(error|warning):%s*(.*)" then
                local sl, sc, el, ec
                file, sl, sc, el, ec, type_str, text = line:match(pattern)
                line_num_str = sl
                col_num_str = sc or "1"
            elseif pattern == "([^%(]+)%((%d+)%)%s*:%s*(error|warning):%s*(.*)" then
                file, line_num_str, type_str, text = line:match(pattern)
                col_num_str = "1"
            elseif pattern == "([^:]+):(%d+):%s*(.*)" then
                file, line_num_str, text = line:match(pattern)
                col_num_str = "1"
                type_str = "E"
            end

            if file then
                local error_entry = {
                    filename = file,
                    lnum = tonumber(line_num_str),
                    col = tonumber(col_num_str) or 1,
                    type = type_str and type_str:sub(1, 1):upper() or "E",
                    text = text,
                }
                if not first_error then
                    first_error = error_entry                                           -- Store the first error found
                end
                local hl_group = error_entry.type == "E" and "ErrorMsg" or "WarningMsg" -- Use WarningMsg for warnings
                -- Add highlight to the entire line in the output buffer
                vim.api.nvim_buf_add_highlight(output_buf, ns_id, hl_group, line_number - 1, 0, -1)
                if error_entry.type == "E" then
                    error_count = error_count + 1
                else
                    warning_count = warning_count + 1
                end
                break -- Found a match for this line, move to next line
            end
        end
    end

    -- Display summary messages
    if first_error then
        show_error_in_statusline(first_error) -- Show the first error in status line
        local summary = string.format("Found %d error(s) and %d warning(s).",
            error_count, warning_count)
        -- Defer this message slightly so it doesn't immediately overwrite the first error
        vim.defer_fn(function()
            vim.api.nvim_echo({ { summary, "MoreMsg" } }, false, {})
        end, 1000)
    else
        vim.api.nvim_echo({ { "No errors or warnings found!", "MoreMsg" } }, false, {})
    end
end

--- Executes the given compile command.
--- It handles command preparation (e.g., for Windows), captures output,
--- updates the output buffer, and triggers error highlighting/navigation.
-- @param command string The command to execute (e.g., "make", "g++ main.c").
local function execute_compile_command(command)
    if not command or command == "" then return end
    add_to_history(command)

    local original_command = command
    -- If it's a CMake project and a 'build' directory exists, change into it first.
    if is_cmake_project() and vim.fn.isdirectory("build") == 1 then
        command = "cd build && " .. command
    end

    -- Prepare the command for shell execution (important for Windows compatibility)
    local shell_command
    if vim.fn.has("win32") == 1 then
        -- On Windows, use cmd.exe /c to ensure proper execution and output capture
        shell_command = 'cmd.exe /c "' .. command .. ' 2>&1"'
    else
        -- On Unix-like systems, use sh -c
        shell_command = 'sh -c "' .. command .. ' 2>&1"'
    end

    -- --- Output Buffer Management ---
    local output_buf
    -- Check if the output buffer already exists and is valid
    if compile_output_buf_id and vim.api.nvim_buf_is_valid(compile_output_buf_id) then
        output_buf = compile_output_buf_id
        vim.api.nvim_buf_set_option(output_buf, "modifiable", true) -- Allow modifications
        vim.api.nvim_buf_set_option(output_buf, "readonly", false)  -- Allow modifications
        vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, {})    -- Clear old content
    else
        -- Create a new scratch buffer if it doesn't exist or is invalid
        output_buf = vim.api.nvim_create_buf(false, true)            -- Not loaded from file, scratch buffer
        vim.api.nvim_buf_set_name(output_buf, "[Compile Output]")
        vim.api.nvim_buf_set_option(output_buf, "buftype", "nofile") -- Not a real file, won't be saved
        vim.api.nvim_buf_set_option(output_buf, "bufhidden", "wipe") -- Delete buffer when last window to it closes
        vim.api.nvim_buf_set_option(output_buf, "swapfile", false)   -- Don't create a swap file
        compile_output_buf_id = output_buf                           -- Store the ID for reuse
        setup_compile_buffer_keymaps(output_buf)                     -- Set up keymaps for the new buffer
    end

    -- --- Execute Command and Capture Output ---
    -- vim.fn.system executes the command and returns its complete output as a string.
    -- It also sets vim.v.shell_error for the exit code.
    local full_output = vim.fn.system(shell_command)
    local exit_code = vim.v.shell_error

    -- Basic error check for command execution itself
    if exit_code ~= 0 and (full_output == nil or full_output == "") then
        vim.api.nvim_echo(
            { { "Failed to run command (exit code " .. exit_code .. "): " .. original_command, "ErrorMsg" } }, false, {})
        return
    end

    -- Split output into lines for setting buffer content
    local output_lines = {}
    for line in full_output:gmatch("[^\n]+") do
        table.insert(output_lines, line)
    end

    -- --- Write Output to Buffer ---
    vim.api.nvim_buf_set_option(output_buf, "modifiable", true)            -- Unlock to write content
    vim.api.nvim_buf_set_option(output_buf, "readonly", false)             -- Unlock to write content
    vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, output_lines)     -- Write all captured lines
    vim.api.nvim_buf_set_option(output_buf, "modifiable", false)           -- Lock after writing
    vim.api.nvim_buf_set_option(output_buf, "readonly", true)              -- Keep it read-only
    vim.api.nvim_buf_set_option(output_buf, "filetype", "compiler_output") -- Set filetype for potential syntax highlighting

    -- --- Window Management for Output Buffer ---
    local current_win_id = vim.api.nvim_get_current_win()
    local output_window_found = false

    -- Try to find an existing window displaying the output buffer
    for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win_id) == output_buf then
            compile_output_win_id = win_id -- Update the stored window ID
            output_window_found = true
            break
        end
    end

    if not output_window_found then
        -- If no window exists for this buffer, **replace the current window's buffer**
        -- instead of creating a new split.
        vim.api.nvim_win_set_buf(current_win_id, output_buf)
        compile_output_win_id = current_win_id -- The current window now holds the output
        vim.cmd("normal! G")                   -- Scroll to the end of the output
    else
        -- If the window exists, just jump to it
        vim.api.nvim_set_current_win(compile_output_win_id)
        vim.cmd("normal! G") -- Scroll to the end of the output
    end

    -- --- Highlight Errors and Update Status ---
    highlight_errors(full_output, output_buf)

    -- Note: After replacing the current window, we don't automatically jump back
    -- to the original file. The user can navigate as desired.
    -- If you want to jump back *after* highlighting, you would need to store
    -- the original buffer ID and use vim.api.nvim_win_set_buf(current_win_id, original_buf_id)
    -- This can be tricky if the original buffer was modified or closed.
    -- For now, the compile output becomes the active window.
end

--- Provides completion suggestions for compile commands based on history.
--- This function is used by Neovim's built-in `input()` completion mechanism.
-- @param ArgLead string The part of the command already typed by the user.
-- @param CmdLine string The full command line content.
-- @param CursorPos number The cursor position in the command line.
-- @return table A list of strings (matching commands from history).
function M.get_completions(ArgLead, CmdLine, CursorPos)
    local matches = {}
    for _, cmd in ipairs(compile_history) do
        -- Case-insensitive search for matches
        if ArgLead == "" or cmd:lower():find(ArgLead:lower(), 1, true) then
            table.insert(matches, cmd)
        end
    end
    return matches
end

--- Main entry point for the `:CompileMode` user command.
--- Prompts the user for a command and executes it.
function M.compile_mode()
    local cmd = get_user_command()
    if cmd and cmd ~= "" then
        execute_compile_command(cmd)
    end
end

-- --- Neovim User Commands ---

-- `:CompileMode` command: Allows interactive input of a compile command with history.
vim.api.nvim_create_user_command("CompileMode", function()
    M.compile_mode()
end, {
    desc = "Run a compile command (Emacs-like interactive mode)",
})

-- `:Compile <cmd>` command: Directly executes a compile command passed as arguments.
vim.api.nvim_create_user_command("Compile", function(args)
    local cmd = table.concat(args.fargs, " ") -- Concatenate all arguments into a single command string
    if cmd ~= "" then
        execute_compile_command(cmd)
    else
        vim.api.nvim_echo({ { "Usage: :Compile <command>", "ErrorMsg" } }, false, {})
    end
end, {
    desc = "Run a compile command directly",
    nargs = "+", -- Indicates that the command expects one or more arguments
    -- Enable history completion for this direct command as well
    complete = function(ArgLead, CmdLine, CursorPos)
        return M.get_completions(ArgLead, CmdLine, CursorPos)
    end,
})

return M
