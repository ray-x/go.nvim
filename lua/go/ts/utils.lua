local api = vim.api

local ts_query = vim.treesitter.query
local ts_utils = require("nvim-treesitter.ts_utils")
local log = require("go.utils").log
local M = {}

-- local ulog = require("go.utils").log
M.intersects = function(row, col, sRow, sCol, eRow, eCol)
  -- ulog(row, col, sRow, sCol, eRow, eCol)
  if sRow > row or eRow < row then
    return false
  end

  if sRow == row and sCol > col then
    return false
  end

  if eRow == row and eCol < col then
    return false
  end

  return true
end

local locals = require("nvim-treesitter.locals")
-- copy from nvim-treesitter/treesitter-refactor plugin
--- Get definitions of bufnr (unique and sorted by order of appearance).
local function get_definitions(bufnr)
  local local_nodes = locals.get_locals(bufnr)

  -- Make sure the nodes are unique.
  local nodes_set = {}
  for _, loc in ipairs(local_nodes) do
    if loc.definition then
      locals.recurse_local_nodes(loc.definition, function(_, node, _, match)
        -- lua doesn't compare tables by value,
        -- use the value from byte count instead.
        local _, _, start = node:start()
        nodes_set[start] = { node = node, type = match or "" }
      end)
    end
  end

  -- Sort by order of appearance.
  local definition_nodes = vim.tbl_values(nodes_set)
  table.sort(definition_nodes, function(a, b)
    local _, _, start_a = a.node:start()
    local _, _, start_b = b.node:start()
    return start_a < start_b
  end)

  return definition_nodes
end

-- a hack to treesitter-refactor plugin to return list node for outline
function M.list_definitions_toc(bufnr)
  bufnr = bufnr or api.nvim_win_get_buf(api.nvim_get_current_win())
  vim.api.nvim_buf_set_option(bufnr, "filetype", "go")
  local definitions = get_definitions(bufnr)

  if #definitions < 1 then
    return
  end

  local loc_list = {}

  -- Force some types to act like they are parents
  -- instead of neighbors of the next nodes.
  local containers = {
    ["function"] = true,
    ["type"] = true,
    ["method"] = true,
  }

  local parents = {}

  for _, def in ipairs(definitions) do
    -- Get indentation level by putting all parents in a stack.
    -- The length of the stack minus one is the current level of indentation.
    local n = #parents
    for i = 1, n do
      local index = n + 1 - i
      local parent_def = parents[index]
      if
        ts_utils.is_parent(parent_def.node, def.node)
        or (containers[parent_def.type] and ts_utils.is_parent(parent_def.node:parent(), def.node))
      then
        break
      else
        parents[index] = nil
      end
    end
    parents[#parents + 1] = def

    local lnum, col, _ = def.node:start()
    local type = def.type
    -- local kind = string.upper(def.type:sub(1, 1))
    local text = ts_query.get_node_text(def.node, bufnr) or ""

    local line_before = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]

    local hint = {}
    if line_before and not line_before:find("^%s*//") then
      hint = { line_before }
    end
    -- go pkg hack
    local line_text = api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or text
    table.insert(hint, line_text)
    for i = 1, 5 do
      local line_after = api.nvim_buf_get_lines(bufnr, lnum + i, lnum + i + 1, false)[1]
      if line_after and line_after:find("^%s*//") then
        table.insert(hint, line_after)
      else
        break
      end
    end
    log(text, hint)
    table.insert(loc_list, {
      bufnr = bufnr,
      -- lnum = lnum + 1,
      col = col + 1,
      indent_level = #parents,
      hint = hint,
      text = text,
      type = type,
      -- kind = kind,
    })
  end
  return loc_list

  -- vim.fn.setloclist(winnr, loc_list, "r")
  -- -- The title needs to end with `TOC`,
  -- -- so Neovim displays it like a TOC instead of an error list.
  -- vim.fn.setloclist(winnr, {}, "a", { title = "Definitions TOC" })
  -- api.nvim_command "lopen"
end

return M
