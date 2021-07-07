-- local ts_utils = require 'nvim-treesitter.ts_utils'
local util = require("go.util")

local iferr = "iferr"
local run = function(...)
  require("go.install").install(iferr)
  local fname = vim.fn.expand("%:p") -- %:p:h ? %:p

  local byte_offset = vim.fn.wordcount().cursor_bytes

  local setup = {iferr, "-pos", byte_offset, vim.fn.bufnr('%')}

  vim.fn.jobstart(
    setup,
    {
      on_stdout = function(jobid, data, event)
        data = util.handle_job_data(data)
        if not data then return end
        local pos = vim.fn.getcurpos()[1]
        vim.fn.append(pos, data)

        vim.cmd('silent normal! j=2j')
        vim.fn.setpos('.', pos)
        vim.cmd('ssilent normal! 4j')
      end
    }
  )
end
return {run = run}
