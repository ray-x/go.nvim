-- part of the code from polarmutex/contextprint.nvim
local ts_utils = require("nvim-treesitter.ts_utils")
local ts_query = require("nvim-treesitter.query")
local parsers = require("nvim-treesitter.parsers")
local locals = require("nvim-treesitter.locals")
local utils = require("go.ts.utils")
local ulog = require("go.utils").log
local warn = require("go.utils").warn
-- local vim_query = require("vim.treesitter.query")

local M = {}

local function get_node_text(bufnr, node)
  if vim.treesitter.query ~= nil and vim.treesitter.query.get_node_text ~= nil then
    return vim.treesitter.query.get_node_text(bufnr, node)
  end
  return ts_utils.get_node_text(node)[1]
end

-- Array<node_wrapper>
M.intersect_nodes = function(nodes, row, col)
  local found = {}
  for idx = 1, #nodes do
    local node = nodes[idx]
    local sRow = node.dim.s.r
    local sCol = node.dim.s.c
    local eRow = node.dim.e.r
    local eCol = node.dim.e.c

    if utils.intersects(row, col, sRow, sCol, eRow, eCol) then
      table.insert(found, node)
    end
  end

  return found
end

M.count_parents = function(node)
  local count = 0
  local n = node.declaring_node
  while n ~= nil do
    n = n:parent()
    count = count + 1
  end
  return count
end

-- @param nodes Array<node_wrapper>
-- perf note.  I could memoize some values here...
M.sort_nodes = function(nodes)
  table.sort(nodes, function(a, b)
    return M.count_parents(a) < M.count_parents(b)
  end)
  return nodes
end

-- local lang = vim.api.nvim_buf_get_option(bufnr, 'ft')
-- node_wrapper
-- returns [{
--   declaring_node = tsnode
--   dim: {s: {r, c}, e: {r, c}},
--   name: string
--   type: string
-- }]
M.get_nodes = function(query, lang, defaults, bufnr)
  bufnr = bufnr or 0
  local success, parsed_query = pcall(function()
    return vim.treesitter.parse_query(lang, query)
  end)
  if not success then
    warn("treesitter parse failed, make sure treesitter installed and setup correctly")
    return nil
  end

  local parser = parsers.get_parser(bufnr, lang)
  local root = parser:parse()[1]:root()
  local start_row, _, end_row, _ = root:range()
  -- local n = ts_utils.get_node_at_cursor()
  -- local a, b, c, d = ts_utils.get_node_range(n)
  local results = {}
  for match in ts_query.iter_prepared_matches(parsed_query, root, bufnr, start_row, end_row) do
    local sRow, sCol, eRow, eCol
    local declaration_node
    local type = "nil"
    local name = "nil"
    locals.recurse_local_nodes(match, function(_, node, path)
      local idx = string.find(path, ".", 1, true)
      local op = string.sub(path, idx + 1, #path)

      -- local a1, b1, c1, d1 = ts_utils.get_node_range(node)

      type = string.sub(path, 1, idx - 1)
      if name == nil then
        name = defaults[type] or "empty"
      end

      if op == "name" then
        name = get_node_text(node, bufnr)
      elseif op == "declaration" then
        declaration_node = node
        sRow, sCol, eRow, eCol = node:range()
        sRow = sRow + 1
        eRow = eRow + 1
        sCol = sCol + 1
        eCol = eCol + 1
      end
    end)

    if declaration_node ~= nil then
      table.insert(results, {
        declaring_node = declaration_node,
        dim = { s = { r = sRow, c = sCol }, e = { r = eRow, c = eCol } },
        name = name,
        type = type,
      })
    end
  end

  return results
end

M.get_all_nodes = function(query, lang, defaults, bufnr, pos_row, pos_col, type_only)
  bufnr = bufnr or 0
  -- todo a huge number
  pos_row = pos_row or 30000
  local success, parsed_query = pcall(function()
    return vim.treesitter.parse_query(lang, query)
  end)
  if not success then
    return nil
  end

  local parser = parsers.get_parser(bufnr, lang)
  local root = parser:parse()[1]:root()
  local start_row, _, end_row, _ = root:range()
  local results = {}
  local node_type
  for match in ts_query.iter_prepared_matches(parsed_query, root, bufnr, start_row, end_row) do
    local sRow, sCol, eRow, eCol
    local declaration_node
    local type_node
    local type = ""
    local name = ""
    local op = ""
    -- local method_receiver = ""

    locals.recurse_local_nodes(match, function(_, node, path)
      -- local idx = string.find(path, ".", 1, true)
      -- The query may return multiple nodes, e.g.
      -- (type_declaration (type_spec name:(type_identifier)@type_decl.name type:(type_identifier)@type_decl.type))@type_decl.declaration
      -- returns { { @type_decl.name, @type_decl.type, @type_decl.declaration} ... }
      local idx = string.find(path, ".[^.]*$") -- find last `.`
      op = string.sub(path, idx + 1, #path)
      local a1, b1, c1, d1 = ts_utils.get_node_range(node)
      local dbg_txt = get_node_text(node, bufnr) or ""
      if #dbg_txt > 100 then
        dbg_txt = string.sub(dbg_txt, 1, 100) .. "..."
      end
      type = string.sub(path, 1, idx - 1) -- e.g. struct.name, type is struct
      if type:find("type") and op == "type" then -- type_declaration.type
        node_type = get_node_text(node, bufnr)
        ulog("type: " .. type)
      end

      -- stylua: ignore
      ulog(
        "node ", vim.inspect(node), "\n path: " .. path .. " op: " .. op
          .. "  type: " .. type .. "\n txt: " .. dbg_txt .. "\n range: " .. tostring(a1 or 0)
          .. ":" .. tostring(b1 or 0) .. " TO " .. tostring(c1 or 0) .. ":" .. tostring(d1 or 0)
      )
      -- stylua: ignore end
      --
      -- may not handle complex node
      if op == "name" then
        -- ulog("node name " .. name)
        name = get_node_text(node, bufnr) or ""
        type_node = node
      elseif op == "declaration" or op == "clause" then

        declaration_node = node
        sRow, sCol, eRow, eCol = ts_utils.get_vim_range({ ts_utils.get_node_range(node) }, bufnr)
      else
        ulog("unknown op: " .. op)
      end
    end)
    if declaration_node ~= nil then
      ulog(name .. " " .. op)
      -- ulog(sRow, pos_row)
      if sRow > pos_row then
        ulog(tostring(sRow) .. " beyond " .. tostring(pos_row))
        -- break
      end
      table.insert(results, {
        declaring_node = declaration_node,
        dim = { s = { r = sRow, c = sCol }, e = { r = eRow, c = eCol } },
        name = name,
        operator = op,
        type = node_type or type,
      })
    end
    if type_node ~= nil and type_only then
      ulog("type_only")
      sRow, sCol, eRow, eCol = ts_utils.get_vim_range({ ts_utils.get_node_range(type_node) }, bufnr)
      table.insert(results, {
        type_node = type_node,
        dim = { s = { r = sRow, c = sCol }, e = { r = eRow, c = eCol } },
        name = name,
        operator = op,
        type = type,
      })
    end
  end
  ulog("total nodes got: " .. tostring(#results))
  return results
end

M.nodes_in_buf = function(query, default, bufnr, row, col)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
  if row == nil or col == nil then
    row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row, col = row, col + 1
  end
  local nodes = M.get_all_nodes(query, ft, default, bufnr, row, col, true)
  if nodes == nil then
    vim.notify("Unable to find any nodes.", vim.lsp.log_levels.DEBUG)
    ulog("Unable to find any nodes. place your cursor on a go symbol and try again")
    return nil
  end

  return nodes
end

M.nodes_at_cursor = function(query, default, bufnr)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
  local nodes = M.get_all_nodes(query, ft, default, bufnr, row, col)
  if nodes == nil then
    vim.notify("Unable to find any nodes. place your cursor on a go symbol and try again", vim.lsp.log_levels.DEBUG)
    ulog("Unable to find any nodes. place your cursor on a go symbol and try again")
    return nil
  end

  local nodes_at_cursor = M.sort_nodes(M.intersect_nodes(nodes, row, col))
  ulog(nodes, row, col, nodes_at_cursor)
  if nodes_at_cursor == nil or #nodes_at_cursor == 0 then
    vim.notify("Unable to find any nodes at pos. " .. tostring(row) .. ":" .. tostring(col), vim.lsp.log_levels.DEBUG)
    ulog("Unable to find any nodes at pos. " .. tostring(row) .. ":" .. tostring(col))
    return nil
  end

  return nodes_at_cursor
end

function M.inside_function()
  local current_node = ts_utils.get_node_at_cursor()
  if not current_node then
    return false
  end
  local expr = current_node

  while expr do
    if expr:type() == "function_declaration" or expr:type() == "method_declaration" then
      return true
    end
    expr = expr:parent()
  end
  return false
end

return M
