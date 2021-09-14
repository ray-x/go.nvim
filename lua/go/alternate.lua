local M = {}
function M.switch(bang, cmd)
  local file = vim.fn.expand('%')
  local root = ""
  local alt_file = ""
  if #file <= 1 then
    print("no buffer name")
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
    print('not a go file')
  end
  if not vim.fn.filereadable(alt_file) and not vim.fn.bufexists(alt_file) and not bang then
    print("couldn't find " .. alt_file)
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
