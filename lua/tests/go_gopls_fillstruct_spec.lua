local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

local godir = cur_dir .. '/lua/tests/fixtures'
describe('should run gopls related functions', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)

  vim.cmd([[packadd go.nvim]])
  it('should import time from file with gopls', function()
    require('plenary.reload').reload_module('go.nvim')

    require('go').setup({ goimports = 'gopls', verbose = true, log_path = '', lsp_cfg = true })
    local cmd = " silent exe 'e temp.go'"
    vim.cmd(cmd)
    _GO_NVIM_CFG.goimports = 'gopls'
    _GO_NVIM_CFG.log_path = '' -- enable log to console
    _GO_NVIM_CFG.lsp_codelens = false
    local expected =
      vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports3_golden.go'), '\n')

    vim.cmd('cd ' .. godir)
    local path = './fmt/goimports3.go' -- %:p:h ? %:p
    cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)

    vim.wait(2000, function()
      return false
    end)
    local c = vim.lsp.get_active_clients()
    eq(#c > 0, true)

    _GO_NVIM_CFG.log_path = '' -- enable log to console
    require('go.format').goimports()

    vim.wait(1000, function()
      return false
    end)
    print('workspaces:', vim.inspect(vim.lsp.buf.list_workspace_folders()))
    local fmt
    require('go.utils').log(vim.inspect(expected))
    require('go.utils').log('waiting for import')
    vim.cmd([[wa]])
    local success, no = vim.wait(6000, function()
      fmt = vim.fn.join(vim.fn.readfile(path), '\n')
      require('go.utils').log(vim.inspect(fmt))
      if expected == fmt then
        require('go.utils').log('success:', vim.inspect(fmt))
        return true
      end
      require('go.utils').log('wait:', fmt, expected)
      return false
    end, 400)

    require('go.utils').log('success:', success, no, fmt, expected)
    if success then
      eq(1, 1)
    else
      eq(expected, fmt)
    end
    cmd = 'bd! ' .. path
    vim.cmd(cmd)
  end)
end)
