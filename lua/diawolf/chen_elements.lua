local M = {}
function M.create_entity_snippet()
  vim.snippet.expand([[
entity ${1:name} #FFB300{
}]])
end

function M.create_relation_snippet()
  vim.snippet.expand([[
relationship ${1:name} #7CC520 {
}]])
end

-- Inserts lines so the first one lands on `line` (1-based).
-- Existing lines from `line` onward move down. Nothing is replaced.
-- To insert after a block found with find_element, pass end_line + 1.
local function insert_lines(line, lines)
  local bufnr = vim.api.nvim_get_current_buf()
  local idx = line - 1
  vim.api.nvim_buf_set_lines(bufnr, idx, idx, false, lines)
end

function M.create_entity(name, line)
  insert_lines(line, { "entity " .. name .. " #FFB300 {", "}" })
end

function M.create_relation(name, line)
  insert_lines(line, { "relationship " .. name .. " #7CC520 {", "}" })
end

-- Finds an entity or relationship by name in the current buffer's model.
-- kind: "entity", "relationship", or nil (searches both).
-- Returns start_line, end_line (1-based, end_line = line of "}"), item.
-- Returns nil if not found.
function M.find_element(name, kind)
  local bufnr = vim.api.nvim_get_current_buf()
  local model = require("diawolf.model").get_model(bufnr)
  if not model then return nil end

  local lists = {}
  if kind ~= "relationship" then lists[#lists + 1] = model.entities end
  if kind ~= "entity" then lists[#lists + 1] = model.relationships end

  for _, list in ipairs(lists) do
    for _, item in ipairs(list) do
      if item.name == name or item.label == name then
        return item.line, item.end_line, item
      end
    end
  end
  return nil
end

-- Inserts the link `rel -card- entity` below the relationship block,
-- after any links that already belong to it.
-- Returns the entity/relationship whose block contains `line` (1-based), or nil.
function M.find_element_at(line)
  local model = require("diawolf.model").get_model(vim.api.nvim_get_current_buf())
  if not model then return nil end
  for _, list in ipairs({ model.entities, model.relationships }) do
    for _, item in ipairs(list) do
      if line >= item.line and line <= item.end_line then return item end
    end
  end
  return nil
end

-- Finds the block under the cursor and returns the 1-based line where a new
-- field goes (the "}" line, which moves down) and the indent to use.
-- Returns nil and notifies if that is not possible.
local function field_target()
  local item = M.find_element_at(vim.fn.line("."))
  if not item then
    vim.notify("diawolf: cursor is not inside an entity/relationship", vim.log.levels.WARN)
    return nil
  end
  if item.end_line == item.line then
    vim.notify("diawolf: " .. item.name .. " has no { } body on its own lines", vim.log.levels.WARN)
    return nil
  end
  local close_text = vim.api.nvim_buf_get_lines(0, item.end_line - 1, item.end_line, false)[1]
  local base = close_text:match("^%s*")
  local step = vim.bo.expandtab and string.rep(" ", vim.fn.shiftwidth()) or "\t"
  return item.end_line, base .. step
end

-- Inserts `name` as the last field of the block under the cursor.
function M.create_field(name)
  local line, indent = field_target()
  if not line then return false end
  insert_lines(line, { indent .. name })
  return true
end

-- Same as create_field, but expands a snippet so you type the name.
function M.create_field_snippet()
  local line, indent = field_target()
  if not line then return false end
  -- Empty line + indent inside the snippet: in normal mode the cursor
  -- can't sit after trailing whitespace, so it can't start at column #indent.
  insert_lines(line, { "" })
  vim.api.nvim_win_set_cursor(0, { line, 0 })
  vim.snippet.expand(indent .. "${1:name}")
  return true
end

-- Toggles <<key>> on the field under the cursor.
-- Adds " <<key>>" at the end of the line, or removes it if present.
function M.toggle_key()
  local row = vim.fn.line(".")
  local item = M.find_element_at(row)
  local attr
  for _, a in ipairs(item and item.attrs or {}) do
    if a.line == row then attr = a break end
  end
  if not attr then
    vim.notify("diawolf: cursor is not on a field", vim.log.levels.WARN)
    return false
  end

  local text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  local new_text
  if text:find("<<key>>", 1, true) then
    new_text = text:gsub("%s*<<key>>", "")
  elseif attr.key then
    vim.notify("diawolf: " .. attr.label .. " is a key via <b>, remove it by hand", vim.log.levels.WARN)
    return false
  else
    new_text = text:gsub("%s*$", "") .. " <<key>>"
  end
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_text })
  return true
end

-- Splits the cursor line into prefix / name / rest, for the "as" rewrite.
--   entity Student #FFB300 {  -> "entity ", "Student", " #FFB300 {"
--     Name <<key>>            -> "  ",      "Name",    " <<key>>"
-- Returns nil and notifies if the cursor is not on a header or field line,
-- or the name is already quoted / aliased.
local function alias_parts()
  local row = vim.fn.line(".")
  local item = M.find_element_at(row)
  if not item then
    vim.notify("diawolf: cursor is not inside an entity/relationship", vim.log.levels.WARN)
    return nil
  end
  local text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]

  local prefix, name, rest
  if row == item.line then
    prefix, name, rest = text:match("^(%s*%a+%s+)([%a_][%w_]*)(.*)$")
  else
    for _, a in ipairs(item.attrs) do
      if a.line == row then
        prefix, name, rest = text:match("^(%s*)([%a_][%w_]*)(.*)$")
        break
      end
    end
  end

  if not name then
    vim.notify("diawolf: no plain name on this line (already quoted, or not a header/field)",
      vim.log.levels.WARN)
    return nil
  end
  return row, prefix, name, rest
end

-- Rewrites the name under the cursor to `"label" as name`.
-- The old name stays as the alias, so existing links keep working.
function M.alias(label)
  local row, prefix, name, rest = alias_parts()
  if not row then return false end
  local new_text = prefix .. '"' .. label .. '" as ' .. name .. rest
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_text })
  return true
end

-- Same as alias, but as a snippet: the label is selected for you to type over.
function M.alias_snippet()
  local row, prefix, name, rest = alias_parts()
  if not row then return false end
  -- $, } and \ are special in snippet syntax, so escape the literal text
  local function esc(s) return (s:gsub("[%$}\\]", "\\%0")) end
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { "" })
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  vim.snippet.expand(esc(prefix) .. '"${1:' .. name .. '}" as ' .. esc(name .. rest))
  return true
end

-- Wraps the whole buffer in a chen diagram:
--   @startchen <Name>          <- name without spaces
--   ' <name as typed>          <- comment, ignored by PlantUML
--   left to right direction
--   ...existing content...
--   @endchen
-- name defaults to the file name without extension.
function M.setup_chen(name)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, l in ipairs(lines) do
    if l:match("^%s*@start%a+") then
      vim.notify("diawolf: file already has " .. l:match("@start%a+"), vim.log.levels.WARN)
      return false
    end
  end

  if not name or name == "" then
    name = vim.fn.expand("%:t:r")
    if name == "" then name = "Diagram" end
  end
  local id = name:gsub("%s+", "")

  -- Bottom first, so the top insert doesn't shift where the bottom goes
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "@endchen" })
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {
    "@startchen " .. id,
    "' " .. name,
    "left to right direction",
    "",
  })
  return true
end

-- Writes `from -card- to`. One side must be an existing relationship.
-- Does not create the relationship. Returns true on success.
-- Example: create_link("Student", "N", "Lehrt") -> "Student -N- Lehrt"
function M.create_link(from, card, to)
  local rel_name = from
  local _, end_line = M.find_element(from, "relationship")
  if not end_line then
    rel_name = to
    _, end_line = M.find_element(to, "relationship")
  end
  if not end_line then
    vim.notify("diawolf: no relationship " .. from .. " or " .. to, vim.log.levels.WARN)
    return false
  end
  local line_text = from .. " -" .. card .. "- " .. to

  local model = require("diawolf.model").get_model(vim.api.nvim_get_current_buf())
  if not model then
    vim.notify("diawolf: not a chen diagram", vim.log.levels.WARN)
    return false
  end
  local insert_after = end_line
  for _, l in ipairs(model.links) do
    if l.from == from and l.to == to and l.card == "-" .. card .. "-" then
      vim.notify("diawolf: link already exists: " .. line_text)
      return false
    end
    if (l.from == rel_name or l.to == rel_name) and l.line > insert_after then
      insert_after = l.line
    end
  end

  insert_lines(insert_after + 1, { line_text })
  return true
end

-- Connects two existing entities through a relationship.
-- Creates the relationship if missing (below the later of the two entities),
-- then adds both links below it. Never creates entities.
-- Example: create_entity_relation("Student", "N", "Lehrt", "1", "Kurs")
--   -> Student -N- Lehrt
--      Lehrt -1- Kurs
function M.create_entity_relation(entity1, card1, rel_name, card2, entity2)
  local _, e1_end = M.find_element(entity1, "entity")
  local _, e2_end = M.find_element(entity2, "entity")
  if not e1_end or not e2_end then
    local missing = not e1_end and entity1 or entity2
    vim.notify("diawolf: no entity " .. missing, vim.log.levels.WARN)
    return false
  end

  if not M.find_element(rel_name, "relationship") then
    M.create_relation(rel_name, math.max(e1_end, e2_end) + 1)
  end

  M.create_link(entity1, card1, rel_name)
  M.create_link(rel_name, card2, entity2)
  return true
end


return M
