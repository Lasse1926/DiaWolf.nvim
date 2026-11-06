-- lua/diawolf/model.lua
local cache = {}

local parser = require("diawolf.parsers")

local function parse_diagram(lines)
  return parser.parse_diagram(lines)
end

local function get_model(bufnr)
    local tick = vim.api.nvim_buf_get_changedtick(bufnr)
    local cached = cache[bufnr]

    if cached and cached.tick == tick then
        return cached.model
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local model,error = parse_diagram(lines) -- your parser

    cache[bufnr] = { tick = tick, model = model }
    return model
end

vim.api.nvim_create_autocmd("BufWipeout", {
    callback = function(event)
        cache[event.buf] = nil
    end,
})

return {
    get_model = get_model,
}

