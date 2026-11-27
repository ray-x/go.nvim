-- lua implementation of the fixplurals

local info = require('go.utils').info
local get_node_text = vim.treesitter.get_node_text
local function fixplurals()
  local n = vim.treesitter.get_node({ bufnr = 0 })
  if not n then
    return info('no node found')
  end
  local p = n:parent()
  if p:type() ~= 'parameter_declaration' then
    return info('not in parameter declaration')
  end
  if p:named_child_count() ~= 2 then
    return info('no plural parameter')
  end
  local type_node = p:named_child(1)
  local type = get_node_text(type_node, 0)
  local edits = {}
  
  -- Neovim 0.13+ changed get_sibling() to next_sibling()
  local get_next_sibling = p.next_sibling and function(node) return node:next_sibling() end
                            or function(node) return node:get_sibling() end
  
  while get_next_sibling(p) ~= nil do
    local next_node = get_next_sibling(p)
    if next_node:type() == 'parameter_declaration' then
      local type_node2 = next_node:named_child(1)
      local type_next = get_node_text(type_node2, 0)
      if type == type_next then
        local range1 = vim.treesitter.get_node_range(p:named_child(1))
        range1['start']['character'] = range1['start']['character'] - 1
        local edit1 = { range = range1, newText = '' }
        table.insert(edits, 1, edit1)
      end

      p = next_node
    else
      break
    end
  end

  if #edits == 0 then
    return info('no plural parameter')
  end
  local bufnr = vim.api.nvim_get_current_buf()
  vim.lsp.util.apply_text_edits(edits, bufnr, 'utf-8')
end
return { fixplurals = fixplurals }
