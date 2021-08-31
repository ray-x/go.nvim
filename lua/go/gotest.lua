local M = {}
local utils = require("go.utils")

M.test_fun = function(args)

  local fpath = vim.fn.expand('%:p:h')
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  local ns = require("go.ts.go").get_func_method_node_at_pos(row, col)
  if ns == nil or ns == {} then
    return
  end

  local tag = ''
  utils.log(args)
  if args ~= nil then
    tag = [[-tags\ ]] .. args .. [[\ ]]
  end

  utils.log("parnode" .. vim.inspect(ns))
  local cmd = [[setl makeprg=go\ test\ ]] .. tag .. [[-v\ -run\ ^]] .. ns.name .. [[\ ]] .. fpath
                  .. [[ | lua require"go.asyncmake".make()]]
  utils.log("test cmd", cmd)
  vim.cmd(cmd)
end

M.test_file = function(args)
  local workfolder = vim.lsp.buf.list_workspace_folders()[1]
  local tag = ''
  utils.log(args)
  if args ~= nil then
    tag = [[-tags\ ]] .. args .. [[\ ]]
  end
  local fpath = vim.fn.expand("%:p:h") .. '/..'
  -- local fpath = './' .. vim.fn.expand('%:h') .. '/...'
  utils.log("fpath" .. fpath)
  local cmd = [[setl makeprg=go\ test\ ]] .. tag .. [[-v\ -run\ ]] .. fpath
                  .. [[| lua require"go.asyncmake".make()]]
  utils.log("test cmd", cmd)
  vim.cmd(cmd)
end

return M
