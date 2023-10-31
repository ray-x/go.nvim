local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

local godir = cur_dir .. '/lua/tests/fixtures'
describe('should run gopls releated functions', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)

  vim.cmd([[packadd go.nvim]])
  it('should run import from file with gopls', function()
    require('plenary.reload').reload_module('go.nvim')
    local cmd = " silent exe 'e temp.go'"
    vim.cmd(cmd)
    require('go').setup({ goimport = 'gopls', lsp_cfg = true })
    local path = './fmt/goimports2.go' -- %:p:h ? %:p
    local expected =
      vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports2_golden.go'), '\n')

    vim.cmd('%bdelete!')
    vim.cmd('cd ' .. godir)
    cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)

    _GO_NVIM_CFG.goimport = 'gopls'
    vim.wait(2000, function()
      return false
    end)
    local c = vim.lsp.get_active_clients()
    eq(#c > 0, true)
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
    require('plenary.reload').reload_module('go.nvim')
    local cmd = " silent exe 'e temp.go'"
    vim.cmd(cmd)
    _GO_NVIM_CFG.log_path = '' -- enable log to console
    local expected =
      vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports3_golden.go'), '\n')

    vim.cmd('cd ' .. godir)
    local path = './fmt/goimports3.go' -- %:p:h ? %:p
    cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)

    vim.wait(2000, function()
      return false
    end)
    require('go.format').goimport()
    vim.wait(2000, function() end)

    vim.cmd([[wa]])
    print('workspaces:', vim.inspect(vim.lsp.buf.list_workspace_folders()))
    local fmt = vim.fn.join(vim.fn.readfile(path), '\n')
    print(vim.inspect(fmt))
    eq(expected, fmt)
    -- eq(1, 1) -- still not working
    cmd = 'bd! ' .. path
    vim.cmd(cmd)
  end)
end)
