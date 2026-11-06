local M = {}

local TOKEN_RULES = {
  { "comment",    "^'.*" },
  { "string",     '^"[^"]*"' },
  { "directive",  "^@%w+" },
  { "stereotype", "^<<.->>" },
  { "color",      "^#%w+" },
  { "word",       "^[%a_][%w_]*" },
  { "link",       "^[%-=]%w*[%-=]" },
}

local function tokenize(lines)
  local toks = {}
  for lnum, line in ipairs(lines) do
    local col = 1
    while col <= #line do
      local s, e = line:find("^%s+", col)
      if not s then
        local kind
        for _, r in ipairs(TOKEN_RULES) do
          s, e = line:find(r[2], col)
          if s then kind = r[1] break end
        end
        if not kind then s, e, kind = col, col, "symbol" end
        if kind ~= "comment" then
          toks[#toks + 1] = { kind = kind, text = line:sub(s, e), line = lnum, col = s }
        end
      end
      col = e + 1
    end
  end
  return toks
end

-- "<b>Kurs Nr</b>" -> "Kurs Nr", bold = true
local function unquote(text)
  local inner = text:sub(2, -2)
  local bold = inner:find("<[bB]>") ~= nil
  return (inner:gsub("<[^>]*>", "")), bold
end

function M.parse_diagram(lines)
  local toks = tokenize(lines)
  local model = { type = nil, entities = {}, relationships = {}, links = {} }
  local i = 1
  local function peek(n) return toks[i + (n or 0)] end

  -- Reads `Name`, `"Label"`, `"Label" as Alias` or `Name as Alias`.
  -- Returns { name = id used by links, label = display text, bold = bool } or nil.
  local function read_name()
    local t = peek()
    if not t or (t.kind ~= "word" and t.kind ~= "string") then return nil end
    local label, bold = t.text, false
    if t.kind == "string" then label, bold = unquote(t.text) end
    local res = { name = label, label = label, bold = bold }
    i = i + 1
    if peek() and peek().kind == "word" and peek().text == "as"
        and peek(1) and peek(1).kind == "word" then
      res.name = peek(1).text
      i = i + 2
    end
    return res
  end

  -- Parses the `{ ... }` body of an entity/relationship. Cursor is on `{`.
  -- One attribute per line; nested braces (composite attributes) are skipped.
  local function read_attrs(attrs)
    i = i + 1 -- skip {
    local depth = 1
    local last_line = nil
    while peek() do
      local t = peek()
      if t.text == "}" then
        depth = depth - 1
        i = i + 1
        if depth == 0 then return t.line end
      elseif t.text == "{" then
        depth = depth + 1
        i = i + 1
      elseif depth == 1 and t.line ~= last_line
          and (t.kind == "word" or t.kind == "string") then
        last_line = t.line
        local n = read_name()
        local attr = { name = n.name, label = n.label, key = n.bold, line = t.line }
        if peek() and peek().kind == "stereotype" then
          attr.key = attr.key or peek().text == "<<key>>"
          i = i + 1
        end
        attrs[#attrs + 1] = attr
      else
        i = i + 1
      end
    end
  end

  while peek() do
    local t = peek()
    if t.kind == "directive" then
      if t.text == "@startchen" then model.type = "chen" end
      i = i + 1
    elseif t.kind == "word" and (t.text == "entity" or t.text == "relationship")
        and peek(1) and (peek(1).kind == "word" or peek(1).kind == "string") then
      i = i + 1
      local n = read_name()
      local item = { name = n.name, label = n.label, attrs = {}, line = t.line }
      if peek() and peek().kind == "color" then
        item.color = peek().text
        i = i + 1
      end
      -- end_line = line of the closing "}" (or the header line if there is no body)
      item.end_line = t.line
      if peek() and peek().text == "{" then
        item.end_line = read_attrs(item.attrs) or t.line
      end
      local target = t.text == "entity" and model.entities or model.relationships
      target[#target + 1] = item
    elseif t.kind == "word" and peek(1) and peek(1).kind == "link"
        and peek(2) and peek(2).kind == "word" then
      model.links[#model.links + 1] = {
        from = t.text, card = peek(1).text, to = peek(2).text, line = t.line,
      }
      i = i + 3
    else
      i = i + 1
    end
  end

  if not model.type then return nil, "not a chen diagram" end
  return model
end

return M
