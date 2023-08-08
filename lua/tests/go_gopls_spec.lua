local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

describe('should run gopls releated functions', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')
  local cmd = " silent exe 'e temp.go'"
  vim.cmd(cmd)
  require('go').setup({ goimport = 'gopls', lsp_cfg = true })
  it('should run import from file with gopls', function()
    local path = cur_dir .. '/lua/tests/fixtures/fmt/goimports2.go' -- %:p:h ? %:p
    local expected =
      vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports2_golden.go'), '\n')

    vim.cmd('%bdelete!')
    local cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)

    vim.cmd([[cd %:p:h]])
    _GO_NVIM_CFG.goimport = 'gopls'
    vim.wait(2000, function()
      return false
    end)
    require('go.format').goimport()
    vim.wait(100, function()
      return false
    end)

    print('workspaces:', vim.inspect(vim.lsp.buf.list_workspace_folders()))
    vim.wait(1000, function() end)
    vim.cmd([[wa]])
    local fmt = vim.fn.join(vim.fn.readfile(path), '\n')
    print(vim.inspect(fmt))
    eq(expected, fmt)
    -- eq(1, 1) -- still not working
    cmd = 'bd! ' .. path
    vim.cmd(cmd)
  end)
  it('should run import from file with gopls', function()
    vim.cmd('%bdelete!')
    local path = cur_dir .. '/lua/tests/fixtures/fmt/goimports3.go' -- %:p:h ? %:p
    local expected =
      vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports3_golden.go'), '\n')
    local cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)

    vim.cmd([[cd %:p:h]])

    require('go.format').goimport()
    vim.wait(1000, function() end)
    print('workspaces:', vim.inspect(vim.lsp.buf.list_workspace_folders()))
    local fmt = vim.fn.join(vim.fn.readfile(path), '\n')
    print(vim.inspect(fmt))
    eq(expected, fmt)
    -- eq(1, 1) -- still not working
    cmd = 'bd! ' .. path
    vim.cmd(cmd)
  end)
end)
