local m = {}

local function getSpinnerConfig()
	local width = 30
	local editor_width = vim.api.nvim_get_option("columns")
	local col = math.floor((editor_width - width) / 2)
	return {
		relative = "editor",
		width = width,
		height = 1,
		row = 1,
		col = col,
		style = "minimal",
		border = "single",
		zindex = 100,
	}
end

m.run = function()
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname:match("%.py$") then
		-- Create a new buffer for the spinner
		local spinner_buf = vim.api.nvim_create_buf(false, true)
		local spinner_win = vim.api.nvim_open_win(spinner_buf, true, getSpinnerConfig())

		-- Spinner frames
		local spinner_frames = {
			"⠋ running python script ⠋",
			"⠙ running python script ⠙",
			"⠹ running python script ⠹",
			"⠸ running python script ⠸",
			"⠼ running python script ⠼",
			"⠴ running python script ⠴",
			"⠦ running python script ⠦",
			"⠧ running python script ⠧",
			"⠇ running python script ⠇",
			"⠏ running python script ⠏",
			"⠋ running python script ⠋", -- Duplicate instance
		}
		local frame = 1

		-- Function to update the spinner
		local function update_spinner()
			vim.api.nvim_buf_set_lines(spinner_buf, 0, -1, false, { spinner_frames[frame] })
			frame = frame % #spinner_frames + 1
		end

		-- Start the spinner
		local spinner_timer = vim.loop.new_timer()
		spinner_timer:start(0, 100, vim.schedule_wrap(update_spinner))

		-- Create a new buffer for the output
		local output_buf = vim.api.nvim_create_buf(false, true)
		local output_win = vim.api.nvim_open_win(output_buf, true, {
			relative = "editor",
			width = math.ceil(vim.api.nvim_get_option("columns") * 0.7),
			height = math.ceil(vim.api.nvim_get_option("lines") * 0.8),
			row = math.ceil(vim.api.nvim_get_option("lines") * 0.1),
			col = math.ceil(vim.api.nvim_get_option("columns") * 0.1),
			style = "minimal",
			border = "single",
		})

		-- Run the Python script asynchronously
		local stdout = vim.loop.new_pipe(false)
		local stderr = vim.loop.new_pipe(false)
		local handle
		handle = vim.loop.spawn("python3", {
			args = { bufname },
			stdio = { nil, stdout, stderr },
		}, function(code, signal)
			spinner_timer:stop()
			spinner_timer:close()

			-- Defer the call to nvim_win_close
			vim.schedule(function()
				vim.api.nvim_win_close(spinner_win, true)
			end)

			if code == 0 then
				print("Python script executed successfully")
			else
				print("Failed to execute Python script")
			end

			handle:close()
			stdout:close()
			stderr:close()
		end)

		print("starting read out")
		-- Read stdout incrementally and update the buffer
		vim.loop.read_start(stdout, function(err, data)
			assert(not err, err)
			if data then
				vim.schedule(function()
					local lines = vim.split(data, "\n", true)
					vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, lines)
				end)
			end
		end)

		-- Read stderr incrementally and update the buffer
		vim.loop.read_start(stderr, function(err, data)
			assert(not err, err)
			if data then
				vim.schedule(function()
					local lines = vim.split(data, "\n", true)
					vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, lines)
				end)
			end
		end)
	else
		print("Not a Python file")
	end
end

return m
