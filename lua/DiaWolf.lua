local M = {}

function M.say_hello()
	print("Hello from Neovim!")
  local bufnr = vim.api.nvim_get_current_buf()
  print(vim.inspect(require("diawolf.model").get_model(bufnr)))
end

local defaults = {
	plantuml_jar = nil,
	keymaps = {
		render_svg = "<leader>dwrs",
		HelloWorld = "<leader>dwhw",
		create_entity = "<leader>dwce",
		create_relationship = "<leader>dwcr",
		create_field = "<leader>dwcf",
		toggle_key = "<leader>dwk",
		alias = "<leader>dwa",
	},
}

local config = {}
local state = {}

-- Snippets
local chen_snippets = require("diawolf.chen_elements")

--Render

local render = require("diawolf.render")

function M.render_svg()
    render.render_svg(config.plantuml_jar)
end

-- Setup 
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
	-- :DiaCreateEntity <name>  -> inserts the entity block below the cursor line
	vim.api.nvim_create_user_command("DiaCreateEntity", function(opts)
		chen_snippets.create_entity(opts.fargs[1], vim.fn.line(".") + 1)
	end, { nargs = 1, desc = "Insert an entity below the cursor" })

	-- :DiaCreateRelationship <name>  -> inserts the relationship block below the cursor line
	vim.api.nvim_create_user_command("DiaCreateRelationship", function(opts)
		chen_snippets.create_relation(opts.fargs[1], vim.fn.line(".") + 1)
	end, { nargs = 1, desc = "Insert a relationship below the cursor" })

	-- :DiaCreateField <name>  -> adds a field to the block under the cursor
	-- Everything after the command is the field, e.g. :DiaCreateField Nr <<key>>
	vim.api.nvim_create_user_command("DiaCreateField", function(opts)
		chen_snippets.create_field(opts.args)
	end, { nargs = "+", desc = "Add a field to the entity/relationship under the cursor" })

	vim.keymap.set("n", config.keymaps.create_field, chen_snippets.create_field_snippet,
		{ desc = "Add field snippet to the entity/relationship under the cursor", silent = true })

	-- :DiaToggleKey  -> adds/removes <<key>> on the field under the cursor
	vim.api.nvim_create_user_command("DiaToggleKey", chen_snippets.toggle_key,
		{ desc = "Toggle <<key>> on the field under the cursor" })
	vim.keymap.set("n", config.keymaps.toggle_key, chen_snippets.toggle_key,
		{ desc = "Toggle <<key>> on the field under the cursor", silent = true })

	-- :DiaSetupChen [name]  -> wraps the buffer in @startchen ... @endchen
	vim.api.nvim_create_user_command("DiaSetupChen", function(opts)
		chen_snippets.setup_chen(opts.args)
	end, { nargs = "?", desc = "Wrap the buffer in a chen diagram (name defaults to file name)" })

	-- :DiaAlias <label>  -> Name becomes "label" as Name (header or field under cursor)
	vim.api.nvim_create_user_command("DiaAlias", function(opts)
		chen_snippets.alias(opts.args)
	end, { nargs = "+", desc = 'Rewrite name under cursor to "label" as name' })
	vim.keymap.set("n", config.keymaps.alias, chen_snippets.alias_snippet,
		{ desc = 'Rewrite name under cursor to "label" as name (snippet)', silent = true })

	-- Opens an empty line below the cursor, moves there, then expands the snippet
	local function snippet_below_cursor(snippet_fn)
		return function()
			local row = vim.fn.line(".")
			vim.api.nvim_buf_set_lines(0, row, row, false, { "" })
			vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
			snippet_fn()
		end
	end

	vim.keymap.set("n", config.keymaps.create_entity, snippet_below_cursor(chen_snippets.create_entity_snippet),
		{ desc = "Insert entity snippet below the cursor", silent = true })
	vim.keymap.set("n", config.keymaps.create_relationship, snippet_below_cursor(chen_snippets.create_relation_snippet),
		{ desc = "Insert relationship snippet below the cursor", silent = true })

	-- :DiaCreateRelation <entity1> <card1> <relation> <card2> <entity2>
	vim.api.nvim_create_user_command("DiaCreateRelation", function(opts)
		local a = opts.fargs
		if #a ~= 5 then
			vim.notify("Usage: DiaCreateRelation <entity1> <card1> <relation> <card2> <entity2>", vim.log.levels.WARN)
			return
		end
		chen_snippets.create_entity_relation(a[1], a[2], a[3], a[4], a[5])
	end, {
		nargs = "+",
		desc = "Connect two entities through a relationship",
		-- Tab-completes entity names for arg 1 and 5, relationship names for arg 3
		complete = function(_, cmdline)
			local model = require("diawolf.model").get_model(vim.api.nvim_get_current_buf())
			if not model then return {} end
			local argn = #vim.split(cmdline, "%s+", { trimempty = false }) - 1
			local list = (argn == 3) and model.relationships
				or (argn == 1 or argn == 5) and model.entities
				or nil
			if not list then return {} end
			local names = {}
			for _, item in ipairs(list) do names[#names + 1] = item.name end
			return names
		end,
	})

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

return M
