local utils = require 'go.utils'
local log = utils.log

local M = {}
-- https://go.googlesource.com/tools/+/refs/heads/master/gopls/doc/commands.md
-- "executeCommandProvider":{"commands":["gopls.add_dependency","gopls.add_import","gopls.apply_fix","gopls.check_upgrades","gopls.gc_details","gopls.generate","gopls.generate_gopls_mod","gopls.go_get_package","gopls.list_known_packages","gopls.regenerate_cgo","gopls.remove_dependency","gopls.run_tests","gopls.start_debugging","gopls.test","gopls.tidy","gopls.toggle_gc_details","gopls.update_go_sum","gopls.upgrade_dependency","gopls.vendor","gopls.workspace_metadata"]}

local gopls_cmds = {
  "gopls.add_dependency", "gopls.add_import", "gopls.apply_fix", "gopls.check_upgrades",
  "gopls.gc_details", "gopls.generate", "gopls.generate_gopls_mod", "gopls.go_get_package",
  "gopls.list_known_packages", "gopls.regenerate_cgo", "gopls.remove_dependency", "gopls.run_tests",
  "gopls.start_debugging", "gopls.test", "gopls.tidy", "gopls.toggle_gc_details",
  "gopls.update_go_sum", "gopls.upgrade_dependency", "gopls.vendor", "gopls.workspace_metadata"
}

local function check_for_error(msg)
  if msg ~= nil and type(msg[1]) == 'table' then
    for k, v in pairs(msg[1]) do
      if k == 'error' then
        log.error('LSP', v.message)
        break
      end
    end
  end
end

for _, value in ipairs(gopls_cmds) do
  local fname = string.sub(value, #'gopls.' + 1)
  M[fname] = function(arg)
    log(fname)
    local b = vim.api.nvim_get_current_buf()
    local uri = vim.uri_from_bufnr(b)
    local arguments = {{URI = uri, URIs = {uri}}}
    arguments = vim.tbl_extend('keep', arguments, arg or {})

    local resp = vim.lsp.buf_request_sync(b, 'workspace/executeCommand', {
      command = value,
      arguments = arguments
    })
    check_for_error(resp)
    log(resp)
    return resp
  end
end

M.list_pkgs = function()
  local resp = M.list_known_packages()

  local pkgs = {}
  for _, response in pairs(resp) do
    if response.result ~= nil then
      pkgs = response.result.Packages
      break
    end
  end
  return pkgs
end

-- check_for_upgrades({Modules = {'package'}})

return M
