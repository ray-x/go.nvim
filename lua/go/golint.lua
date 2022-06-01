-- local ts_utils = require 'nvim-treesitter.ts_utils'
local utils = require("go.utils")

local golangci_lint = "golangci-lint"
local run = function(...)
  require("go.install").install(golangci_lint)
  local fname = vim.fn.expand("%:p") -- %:p:h ? %:p

  local cmd = string.format("golangci-lint -pos %d", byte_offset)

  local data = vim.fn.systemlist(cmd, vim.fn.bufnr("%"))

  data = utils.handle_job_data(data)
  if not data then
    return
  end

  local pos = vim.fn.getcurpos()[2]
  vim.fn.append(pos, data)

  vim.cmd("silent normal! j=2j")
  vim.fn.setpos(".", pos)
  vim.cmd("silent normal! 4j")
  --
end
return { run = run }
