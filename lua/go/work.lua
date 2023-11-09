local runner = require("go.runner")
local utils = require("go.utils")
local M = {}

-- args: tidy or vendor
function M.run(...)
  local args = { ... }
  local cmd = { "go", "work" }
  cmd = vim.list_extend(cmd, args)
  utils.log(cmd)
  local opts = {
    on_exit = function(code, signal, data)
      if code ~= 0 or signal ~= 0 then
        utils.warn('impl failed' .. vim.inspect(data))
        return
      end
      data = vim.split(data, '\n')
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      vim.schedule(function()
        utils.info('gowork success')
      end)
    end,
    }
  if vim.fn.expand('%:t'):find('go.mod') or vim.fn.expand('%:t'):find('go.work')  then
    opts.cwd = vim.fn.expand('%:p:h')
  end
  runner.run(cmd, opts)
end

return M
