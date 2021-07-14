-- local ts_utils = require 'nvim-treesitter.ts_utils'
local utils = require("go.utils")

local impl = "impl"
-- GoImpl f *Foo io.Writer
local run = function(...)
  require("go.install").install(impl)
  local setup = "impl"

  local arg = {...}
  if #arg < 3 then
    print("Usage: GoImpl f *File io.Reader")
  end

  local rec1 = select(1, ...)
  local rec2 = select(2, ...)
  local interface = select(3, ...)

  setup = setup .. " '" .. rec1 .. " " .. rec2 .. "' " .. interface
  local data = vim.fn.systemlist(setup, vim.fn.bufnr('%'))

  data = utils.handle_job_data(data)
  if not data then
    return
  end

  utils.log(data)
  local pos = vim.fn.getcurpos()[2]
  vim.fn.append(pos, data)

  vim.cmd('silent normal! j=2j')
  vim.fn.setpos('.', pos)
  vim.cmd('silent normal! 4j')
  --

end
return {run = run}
