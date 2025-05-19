local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

local godir = cur_dir .. '/lua/tests/fixtures'
describe('should run gopls related functions', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)

  vim.cmd([[packadd go.nvim]])
  it('should import time with gopls', function()
    require('plenary.reload').reload_module('go.nvim')

    require('go').setup({
      goimports = 'gopls',
      verbose = true,
      log_path = '',
      lsp_cfg = true,
      lsp_codelens = false,
    })
    local cmd = " silent exe 'e temp.go'"
    vim.cmd(cmd)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports3_golden.go'), '\n')

    vim.cmd('cd ' .. godir)
    local path = './fmt/goimports3.go' -- %:p:h ? %:p
    cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)

    if
      vim.wait(3000, function()
        local c = vim.lsp.get_clients({ name = 'gopls' })
        if c[1] then
          return true
        end
        if vim.lsp.enable then
          vim.lsp.enable('gopls')
        end
        vim.cmd(cmd)
        return false
      end, 300) == false
    then
      return error('gopls not started')
    end

    _GO_NVIM_CFG.log_path = '' -- enable log to console
    require('go.format').goimports()

    print('workspaces:', vim.inspect(vim.lsp.buf.list_workspace_folders()))
    local fmt
    require('go.utils').log(vim.inspect(expected))
    require('go.utils').log('waiting for import')
    local success, no = vim.wait(6000, function()
      fmt = vim.fn.join(vim.fn.readfile(path), '\n')
      require('go.utils').log(vim.inspect(fmt))
      if expected == fmt then
        require('go.utils').log('import success:', vim.inspect(fmt))
        return true
      end
      require('go.utils').log('wait:', fmt, expected)
      require('go.format').goimports()
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
