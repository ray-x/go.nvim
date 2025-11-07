local M = {}

-- Replacement for ts_utils.get_node_at_cursor()
function M.get_node_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1 -- 0-based
  local parser = vim.treesitter.get_parser(bufnr, 'go')
  if not parser then
    return nil
  end
  local tree = parser:parse()[1]
  local root = tree:root()
  return root:named_descendant_for_range(row, col, row, col)
end

-- Replacement for ts_utils.get_vim_range()
function M.get_vim_range(range, _bufnr)
  local start_row, start_col, end_row, end_col = unpack(range)
  return start_row + 1, start_col + 1, end_row + 1, end_col + 1
end

-- Replacement for ts_utils.is_parent()
function M.is_parent(parent, node)
  if not parent or not node then
    return false
  end
  local n = node:parent()
  while n do
    if n == parent then
      return true
    end
    n = n:parent()
  end
  return false
end

-- Replacement for nvim-treesitter.locals.recurse_local_nodes
function M.recurse_local_nodes(match, cb, prefix)
  prefix = prefix or ''
  for id, nodes in pairs(match) do
    for _, node in ipairs(nodes) do
      local node_type = node:type()
      local path = prefix ~= '' and (prefix .. '.' .. node_type) or node_type
      cb(id, node, path) -- now 'path' is a string
      if node:child_count() > 0 then
        for child in node:iter_children() do
          M.recurse_local_nodes({ [id] = { child } }, cb, path)
        end
      end
    end
  end
end

return M
