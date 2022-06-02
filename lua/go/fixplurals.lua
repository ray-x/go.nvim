-- lua implementation of the fixplurals

local ts_utils = require("nvim-treesitter.ts_utils")

local info = require("go.utils").info
local get_node_text = vim.treesitter.query.get_node_text
local function fixplurals()
  local n = ts_utils.get_node_at_cursor()
  local p = n:parent()
  if p:type() ~= "parameter_declaration" then
    return info("not in parameter declaration")
  end
  if p:named_child_count() ~= 2 then
    return info("no plural parameter")
  end
  local type_node = p:named_child(1)
  local type = get_node_text(type_node, 0)
  local edits = {}
  while ts_utils.get_next_node(p) ~= nil do
    local next_node = ts_utils.get_next_node(p)
    if next_node:type() == "parameter_declaration" then
      local type_node2 = next_node:named_child(1)
      local type_next = get_node_text(type_node2, 0)
      if type == type_next then
        local range1 = ts_utils.node_to_lsp_range(p:named_child(1))
        range1["start"]["character"] = range1["start"]["character"] - 1
        local edit1 = { range = range1, newText = "" }
        table.insert(edits, 1, edit1)
      end

      p = next_node
    else
      break
    end
  end

  if #edits == 0 then
    return info("no plural parameter")
  end
  vim.lsp.util.apply_text_edits(edits, 0, "utf-8")
end
return { fixplurals = fixplurals }
