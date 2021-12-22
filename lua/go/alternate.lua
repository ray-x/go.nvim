local M = {}
function M.switch(bang, cmd)
  local file = vim.fn.expand('%')
  local root = ""
  local alt_file = ""
  if #file <= 1 then
    vim.notify("no buffer name", vim.lsp.log_levels.ERROR)
    return
  end
  local s, e = string.find(file, "_test%.go$")
  local s2, e2 = string.find(file, "%.go$")
  if s ~= nil then
    root = vim.fn.split(file, '_test.go')[1]
    alt_file = root .. '.go'
  elseif s2 ~= nil then
    root = vim.fn.split(file, '.go')[1]
    alt_file = root .. '_test.go'
  else
    vim.notify('not a go file', vim.lsp.log_levels.ERROR)
  end
  if not vim.fn.filereadable(alt_file) and not vim.fn.bufexists(alt_file) and not bang then
    vim.notify("couldn't find " .. alt_file, vim.lsp.log_levels.ERROR)
    return
  elseif #cmd <= 1 then
    local ocmd = "e " .. alt_file
    vim.cmd(ocmd)
  else
    local ocmd = cmd .. " " .. alt_file
    vim.cmd(ocmd)
  end

end

return M
