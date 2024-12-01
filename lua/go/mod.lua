local runner = require('go.runner')
local utils = require('go.utils')
local M = {}

-- return module from current line
function M.get_mod()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row - 1, col
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
  line = line:gsub('^%s+', '') -- lstrip
  line = line:gsub('%s+', ' ') -- combine spaces
  line = vim.split(line, ' ')
  local pkg1 = line[1]:gsub('"', '')
  local pkg2 = ''
  if line[2] then
    pkg2 = line[2]:gsub('"', '')
  end
  if string.find(pkg1, '%a+%.%a+/%a+/%a+') or string.find(pkg1, '%a+%.%a+/%a+') then
    return pkg1
  elseif string.find(pkg2, '%a+%.%a+/%a+/%a+') or string.find(pkg2, '%a+%.%a+/%a+') then
    return pkg2
  end
  return nil
end

-- args::execute "" tidy or vendor
function M.run(...)
  local args = { ... }
  local cmd = { 'go', 'mod' }
  cmd = vim.list_extend(cmd, args)
  utils.log(cmd)
  local opts = {
    on_exit = function(code, signal, output)
      vim.schedule(function()
        utils.restart()
        vim.schedule(function()
          local lc = vim.fn.getloclist(0)
          if vim.fn.empty(lc) == 0 then
            vim.cmd('lopen')
          end
        end)
      end)
    end,
  }
  if vim.fn.expand('%:t'):find('go.mod') then
    opts.cwd = vim.fn.expand('%:p:h')
  end
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
