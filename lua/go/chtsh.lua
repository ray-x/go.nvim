local utils = require("go.utils")
local log = utils.log
local curl = "curl"
local run = function(...)
  local query = select(1, ...)
  local cmd = string.format('%s cht.sh/go/%s?T', curl, query)

  local data = vim.fn.systemlist(cmd, vim.fn.bufnr('%'))

  data = utils.handle_job_data(data)
  if not data then
    return
  end
  -- log(data)
  if #data > 0 then
    data = vim.list_slice(data, 4, #data)
    local name = vim.fn.tempname() .. ".go"
    vim.fn.writefile(data, name)
    cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    vim.cmd('e')
  end
end
return {run = run}
