vim.api.nvim_create_user_command("Pyrun", function()
	require("pyrun").run()
end, {})
