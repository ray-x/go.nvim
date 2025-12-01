-- todo
-- for func name(args) rets {}
-- add cmts // name : rets
local comment = {}
local placeholder = _GO_NVIM_CFG.comment_placeholder or ''
local ulog = require('go.utils').log
local api = vim.api

local ok, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
if not ok then
  ts_utils = require('guihua.ts_obsolete.ts_utils')
end
local gen_comment = function()
  local comments = nil

  local ns = require('go.ts.go').get_package_node_at_pos()
  if ns ~= nil and ns ~= {} then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// Package ' .. ns.name .. ' provides ' .. ns.name
    return comments, ns
  end
  ns = require('go.ts.go').get_func_method_node_at_pos()
  if ns ~= nil and ns ~= {} then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end
  ns = require('go.ts.go').get_struct_node_at_pos()
  if ns ~= nil and ns ~= {} then
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end
  ns = require('go.ts.go').get_interface_node_at_pos()
  if ns ~= nil and ns ~= {} then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end

  ns = require('go.ts.go').get_type_node_at_pos()
  if ns ~= nil and ns ~= {} then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end
  return ''
end

local wrap_comment = function(comment_line, ns)
  if string.len(comment_line) > 0 and placeholder ~= nil and string.len(placeholder) > 0 then
    return comment_line .. ' ' .. placeholder, ns
  end
  return comment_line, ns
end

comment.gen = function()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  local c, ns = wrap_comment(gen_comment())
  local bufnr = api.nvim_get_current_buf()
  if ns == nil then
    -- nothing found
    ns = ts_utils.get_node_at_cursor()
    local node_text = require('go.utils').get_node_text(ns, bufnr)

    local line = api.nvim_get_current_line()
    local regex = '^(%s+)'
    local q = line:match(regex)
    c = (q or '') .. '// ' .. node_text
    c, _ = wrap_comment(c, {})
    vim.fn.append(row - 1, c)
    vim.fn.cursor(row, #c + 1)
    return
  end
  ulog(vim.inspect(ns))
  row, col = ns.dim.s.r, ns.dim.s.c
  ulog('set cursor ' .. tostring(row))
  api.nvim_win_set_cursor(0, { row, col })
  -- insert doc
  vim.fn.append(row - 1, c)
  -- set curosr
  vim.fn.cursor(row, #c + 1)
  -- enter into insert mode
  api.nvim_command('startinsert!')
  return c
end

return comment
