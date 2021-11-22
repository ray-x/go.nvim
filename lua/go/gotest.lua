local M = {}
local utils = require("go.utils")

local function get_build_tags(args)
  local tags = {}

  if args ~= nil then
    table.insert(tags, args)
  end

  if _GO_NVIM_CFG.build_tags ~= "" then
    table.insert(tags, _GO_NVIM_CFG.build_tags)
  end

  if #tags == 0 then
    return ""
  end

  return [[-tags\ ]] .. table.concat(tags, ",") .. [[\ ]]
end

M.test_fun = function(args)

  local fpath = vim.fn.expand('%:p:h')
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  local ns = require("go.ts.go").get_func_method_node_at_pos(row, col)
  if ns == nil or ns == {} then
    return false
  end

  utils.log("parnode" .. vim.inspect(ns))
  local cmd = [[setl makeprg=go\ test\ ]] .. get_build_tags(args) .. [[-v\ -run\ ^]] .. ns.name .. [[\ ]] .. fpath
                  .. [[ | lua require"go.asyncmake".make()]]
  utils.log("test cmd", cmd)
  vim.cmd(cmd)
  return true
end

M.test_file = function(args)
  local workfolder = vim.lsp.buf.list_workspace_folders()[1]
  local tag = ''
  utils.log(args)
  local fpath = vim.fn.expand("%:p:h") .. '/..'
  -- local fpath = './' .. vim.fn.expand('%:h') .. '/...'
  utils.log("fpath" .. fpath)
  local cmd = [[setl makeprg=go\ test\ ]] .. get_build_tags(args) .. [[-v\ -run\ ]] .. fpath
                  .. [[| lua require"go.asyncmake".make()]]
  utils.log("test cmd", cmd)
  vim.cmd(cmd)
end

return M
