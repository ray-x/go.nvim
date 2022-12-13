local runner = require('go.runner')
local utils = require('go.utils')
local log = utils.log
local M = {}

function M.run(args)
  require('go.install').install('govulncheck')
  args = args or {}

  local cmd = { 'govulncheck' }
  local pkg
  if #args > 1 then
    pkg = args[2]
  else
    pkg = './...'
  end
  vim.list_extend(cmd, { pkg })
  log(cmd)
  local opts = {
    update_buffer = true,
    on_exit = function()
      vim.schedule(function()
        utils.restart()
      end)
    end,
  }
  log('running', cmd)
  runner.run(cmd, opts)
  return cmd, opts
end

return M
