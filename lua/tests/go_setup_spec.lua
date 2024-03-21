local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

local godir = cur_dir .. '/lua/tests/fixtures'

describe('should run func make', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')
  it('should make function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])
    vim.cmd('cd ' .. godir)
    local path = './coverage/branch_test.go' -- %:p:h ? %:p

    local cmd = "silent exe 'e " .. path .. "'"
    vim.cmd(cmd)
    require('go').setup({
      trace = true,
      lsp_cfg = false,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })

    _GO_NVIM_CFG.lsp_cfg = {
      settings = {
        gopls = {
          analyses = {
            ST1003 = false,
            fieldalignment = true,
            unusedparams = false,
          },
          staticcheck = false,
        },
      },
    }

    vim.wait(500, function() end)
    local gosetup = require('go.lsp').config()
    -- print(vim.inspect(gosetup))
    eq(gosetup.settings.gopls.analyses, {
      ST1003 = false,
      append = true,
      asmdecl = true,
      atomic = true,
      fieldalignment = true,
      fillreturns = true,
      assign = true,
      nilness = true,
      nonewvars = true,
      shadow = true,
      undeclaredname = true,
      unreachable = true,
      unusedparams = false,
      unusedvariable = true,
      unusedwrite = true,
      useany = true,
    })
  end)
end)
