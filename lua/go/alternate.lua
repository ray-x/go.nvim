local M = {}

function M.is_test_file()
  local file = vim.fn.expand('%')
  if #file <= 1 then
    vim.notify("no buffer name", vim.lsp.log_levels.ERROR)
    return
  end
  local is_test  = string.find(file, "_test%.go$")
  local is_source = string.find(file, "%.go$")
  return file, (not is_test and is_source), is_test
end


function M.alternate()
  local file, is_source, is_test = M.is_test_file()
  local alt_file = file
  if is_test then
    alt_file = string.gsub(file, "_test.go", ".go")
  elseif is_source then
    alt_file = vim.fn.expand('%:r') .. "_test.go"
  else
    vim.notify('not a go file', vim.lsp.log_levels.ERROR)
  end
  return alt_file
end

function M.switch(bang, cmd)
  local alt_file = M.alternate()
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
