-- local ts_utils = require 'nvim-treesitter.ts_utils'
local utils = require("go.utils")
local vfn = vim.fn

local iferr = "iferr"
local run = function()
  require("go.install").install(iferr)

  local byte_offset = vfn.wordcount().cursor_bytes

  local cmd = string.format('iferr -pos %d', byte_offset)

  local data = vfn.systemlist(cmd, vfn.bufnr('%'))

  data = utils.handle_job_data(data)
  if not data then
    return
  end
  if vim.v.shell_error ~= 0 then
    utils.warn("iferr failed" .. vim.inspect(data))
    return
  end

  local pos = vfn.getcurpos()[2]
  vfn.append(pos, data)

  vim.cmd('silent normal! j=2j')
  vfn.setpos('.', pos)
  vim.cmd('silent normal! 4j')
  --

end
return {run = run}
