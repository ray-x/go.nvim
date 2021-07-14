-- local ts_utils = require 'nvim-treesitter.ts_utils'
local utils = require("go.utils")

local iferr = "iferr"
local run = function(...)
  require("go.install").install(iferr)
  local fname = vim.fn.expand("%:p") -- %:p:h ? %:p

  local byte_offset = vim.fn.wordcount().cursor_bytes

  local cmd = string.format('iferr -pos %d', byte_offset)

  local data = vim.fn.systemlist(cmd, vim.fn.bufnr('%'))

  data = utils.handle_job_data(data)
  if not data then
    return
  end

  local pos = vim.fn.getcurpos()[2]
  vim.fn.append(pos, data)

  vim.cmd('silent normal! j=2j')
  vim.fn.setpos('.', pos)
  vim.cmd('silent normal! 4j')
  --

end
return {run = run}
