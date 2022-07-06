-- todo
-- for func name(args) rets {}
-- add cmts // name : rets
local comment = {}
local placeholder = _GO_NVIM_CFG.comment_placeholder or ""
local ulog = require "go.utils".log
local gen_comment = function(row, col)
  local comments = nil

  local ns = require("go.ts.go").get_package_node_at_pos(row, col)
  if ns ~= nil and ns ~= {} then
    -- utils.log("parnode" .. vim.inspect(ns))
    comments = "// Package " .. ns.name .. " provides " .. ns.name
    return comments, ns
  end
  ns = require("go.ts.go").get_func_method_node_at_pos(row, col)
  if ns ~= nil and ns ~= {} then
    -- utils.log("parnode" .. vim.inspect(ns))
    comments = "// " .. ns.name .. " " .. ns.type
    return comments, ns
  end
  ns = require("go.ts.go").get_struct_node_at_pos(row, col)
  if ns ~= nil and ns ~= {} then
    comments = "// " .. ns.name .. " " .. ns.type
    return comments, ns
  end
  ns = require("go.ts.go").get_interface_node_at_pos(row, col)
  if ns ~= nil and ns ~= {} then
    -- utils.log("parnode" .. vim.inspect(ns))
    comments = "// " .. ns.name .. " " .. ns.type
    return comments, ns
  end

  ns = require("go.ts.go").get_type_node_at_pos(row, col)
  if ns ~= nil and ns ~= {} then
    -- utils.log("parnode" .. vim.inspect(ns))
    comments = "// " .. ns.name .. " " .. ns.type
    return comments, ns
  end
  return ""
end

local wrap_comment = function(comment_line, ns)
  if string.len(comment_line)>0 and placeholder ~= nil and string.len(placeholder)>0 then
    return comment_line .. " " .. placeholder, ns
  end
  return comment_line, ns
end

comment.gen = function(row, col)
  if row == nil or col == nil then
    row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row, col = row + 1, col + 1
  end
  local c, ns = wrap_comment(gen_comment(row, col))
  --ulog(vim.inspect(ns))
  row, col = ns.dim.s.r, ns.dim.s.c
  ulog("set cursor " .. tostring(row))
  vim.api.nvim_win_set_cursor(0, {row, col})
  -- insert doc
  vim.fn.append(row - 1, c)
  -- set curosr
  vim.fn.cursor(row, #c+1)
  -- enter into insert mode
  vim.api.nvim_command('startinsert!')
  return c
end



return comment
