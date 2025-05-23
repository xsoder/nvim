local M = {}

-- Store compile history
local compile_history = {}
local MAX_HISTORY = 20

local function add_to_history(command)
	-- Don't add duplicates of the last command
	if #compile_history > 0 and compile_history[1] == command then
		return
	end

	table.insert(compile_history, 1, command)
	if #compile_history > MAX_HISTORY then
		table.remove(compile_history)
	end
end

local function detect_project_type()
	if vim.fn.filereadable("Cargo.toml") == 1 then
		return "rust"
	end
	if vim.fn.filereadable("CMakeLists.txt") == 1 then
		return "cmake"
	end
	if vim.fn.filereadable("Makefile") == 1 then
		return "make"
	end
	if vim.fn.glob("*.cpp") ~= "" then
		return "cpp"
	end
	if vim.fn.glob("*.py") ~= "" then
		return "python"
	end
	return "generic"
end

local function get_suggested_commands()
	local type = detect_project_type()
	local suggestions = {}

	if type == "rust" then
		suggestions = {
			"cargo run",
			"cargo build",
			"cargo test",
			"cargo clean",
			"cargo build --release",
		}
	elseif type == "cmake" then
		suggestions = {
			"cmake -S . -B build && cmake --build build",
			"cmake --build build",
			"ctest --test-dir build",
		}
	elseif type == "make" then
		suggestions = {
			"make",
			"make build",
			"make clean",
			"make install",
			"make test",
		}
	elseif type == "cpp" then
		suggestions = {
			"g++ % -o %:r && ./%:r",
			"g++ -O2 % -o %:r",
			"g++ -g -Wall % -o %:r",
		}
	elseif type == "python" then
		suggestions = {
			"python3 %",
			"python3 -m pytest",
		}
	else
		suggestions = {
			"make",
			"make build",
		}
	end

	return suggestions
end

local function execute_command(command)
	if not command or command == "" then
		return
	end

	-- Expand vim variables like % (current file), %:r (current file without extension)
	local expanded_cmd = vim.fn.expand(command)

	-- Add to history
	add_to_history(command)

	-- Execute the command
	vim.cmd("!" .. expanded_cmd)
end

local function get_command_input()
	-- Get all completion options
	local all_completions = {}

	-- Add history
	for _, cmd in ipairs(compile_history) do
		table.insert(all_completions, cmd)
	end

	-- Add suggestions
	local suggestions = get_suggested_commands()
	for _, cmd in ipairs(suggestions) do
		table.insert(all_completions, cmd)
	end

	-- Set up completion function
	vim.fn.setreg("z", table.concat(all_completions, "\n"))

	-- Show colored prompt

	-- Custom input with history navigation
	local history_index = 0
	local current_input = ""
	local original_input = ""

	local function get_input_with_history()
		vim.cmd("echon ''") -- Clear the line
		vim.api.nvim_echo({ { string.format("[Compile Mode - %s] ", type), "Special" } }, false, {})

		local input = vim.fn.input("", current_input)
		return input
	end

	-- Simple input with tab completion
	local prompt = string.format("Enter a command [%s]: ", detect_project_type())
	local command = vim.fn.input(prompt, "", "custom,v:lua.require'nvim_compile'.get_completions")

	return command
end

local function compile_mode()
	while true do
		local command = get_command_input()

		-- Exit on empty command or ESC (which returns empty string)
		if not command or command == "" then
			-- Clear the command line completely
			vim.cmd("echo ''")
			vim.cmd("redraw")
			break
		end

		execute_command(command)
		-- Automatically continue to next command - no prompt
	end
end

-- Completion function
function M.get_completions(ArgLead, CmdLine, CursorPos)
	local all_completions = {}

	-- Add history
	for _, cmd in ipairs(compile_history) do
		table.insert(all_completions, cmd)
	end

	-- Add suggestions
	local suggestions = get_suggested_commands()
	for _, cmd in ipairs(suggestions) do
		table.insert(all_completions, cmd)
	end

	-- Filter based on what user has typed
	if ArgLead and ArgLead ~= "" then
		local filtered = {}
		for _, completion in ipairs(all_completions) do
			if completion:lower():find(ArgLead:lower(), 1, true) then
				table.insert(filtered, completion)
			end
		end
		return filtered
	end

	return all_completions
end

M.compile_mode = compile_mode

-- Create command to access compile mode
vim.api.nvim_create_user_command("CompileMode", function()
	compile_mode()
end, {
	desc = "Enter compile mode - directly input commands",
})

-- Quick command to execute a compile command directly
vim.api.nvim_create_user_command("Compile", function(args)
	local command = table.concat(args.fargs, " ")
	if command and command ~= "" then
		add_to_history(command)
		vim.cmd("!" .. vim.fn.expand(command))
	else
		vim.api.nvim_echo({ { "Usage: :Compile <command>", "ErrorMsg" } }, false, {})
	end
end, {
	desc = "Execute a compile command directly",
	nargs = "+",
	complete = function(ArgLead, CmdLine, CursorPos)
		return M.get_completions(ArgLead, CmdLine, CursorPos)
	end,
})

return M
