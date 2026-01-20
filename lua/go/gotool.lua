local runner = require('go.runner')
local utils = require('go.utils')
local vfn = vim.fn
local M = {}

M.subcmds = {
  'addr2line',
  'asm',
  'buildid',
  'cgo',
  'compile',
  'covdata',
  'cover',
  'dist',
  'distpack',
  'doc',
  'fix',
  'link',
  'nm',
  'objdump',
  'pack',
  'pprof',
  'preprofile',
  'test2json',
  'trace',
  'vet',
}

M.toolsubcmds_need_rerun = true

function M.run(args)
  args = args or {}
  for i, arg in ipairs(args) do
    local m = string.match(arg, '^https?://(.*)$') or arg
    table.remove(args, i)
    table.insert(args, i, m)
  end

  local cmd = { 'go', 'tool' }
  vim.list_extend(cmd, args)
  utils.log(cmd)

  local workfolder = utils.get_gopls_workspace_folders()[1] or vfn.getcwd()
  local modfile = workfolder .. utils.sep() .. 'go.mod'
  local opts = {
    update_buffer = true,
    on_exit = function()
      vim.schedule(function()
        -- utils.restart()
        require('go.lsp').watchFileChanged(modfile)
      end)
    end,
  }
  runner.run(cmd, opts)
  return cmd, opts
end

function M.autocomplete(a, l)
  if M.toolsubcmds_need_rerun then
    local out = vfn.systemlist('go tool')
    if vim.v.shell_error ~= 0 then
      utils.warn('go tool failed', vim.inspect(out), vim.inspect(vim.v.shell_error))
    else
      M.subcmds = out
      M.toolsubcmds_need_rerun = false
      end
  end
  -- return string of subcommands separated by \n
  utils.log(M.subcmds)
  return M.subcmds
end

return M
