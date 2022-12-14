local runner = require("go.runner")
local utils = require("go.utils")
local M = {}

-- args: tidy or vendor
function M.run(...)
  local args = { ... }
  local cmd = { "go", "mod" }
  cmd = vim.list_extend(cmd, args)
  utils.log(cmd)
  local opts = {
    on_exit = function()
      vim.schedule(function()
        utils.restart()
      end)
    end,
  }
  runner.run(cmd, opts)
end

function M.setup()
  local aug = vim.api.nvim_create_augroup('gomod_save', {})
  local pat = { '*.mod' }
  vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
    group = aug,
    pattern = pat,
    callback = function()
      require('go.lsp').watchFileChanged()
    end,
  })
end

return M
