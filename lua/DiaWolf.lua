local M = {}

function M.say_hello()
	print("Hello from Neovim!")
end

local defaults = {
	plantuml_jar = nil,
	keymaps = {
		render_svg = "<leader>dwrs",
		HelloWorld = "<leader>dwhw",
	},
}

local config = {}
local state = {}

local render = require("diawolf.render")

function M.render_svg()
    render.render_svg(config.plantuml_jar)
end

-- Function to set up the plugin (Most package managers expect the plugin to have a setup function)
function M.setup(opts)
	config = vim.tbl_deep_extend("force", {}, defaults, opts or {})

	if config.plantuml_jar then
		config.plantuml_jar = vim.fn.expand(config.plantuml_jar)

		if vim.fn.filereadable(config.plantuml_jar) ~= 1 then
			error("diawolf.nvim: plantuml_jar not found: " .. config.plantuml_jar)
		end
	end

	-- Create the user command
	vim.api.nvim_create_user_command("HelloWorld", M.say_hello, {})

	-- Create the keymap
	vim.keymap.set("n", config.keymaps.HelloWorld, M.say_hello, {
		desc = "Say hello from our plugin",
		silent = true, -- Prevents the command from being echoed in the command line
	})

	-- SVG Render
	vim.api.nvim_create_user_command("DiaRenderSvg", M.render_svg, {})

	vim.keymap.set("n", config.keymaps.render_svg, M.render_svg, {
		desc = "render current file to svg",
		silent = true, -- Prevents the command from being echoed in the command line
	})
end

-- Return the module
return M
