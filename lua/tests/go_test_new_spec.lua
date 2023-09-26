local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

describe('should run subcase test', function()
  require('plenary.reload').reload_module('go.nvim')

  it('should test subcase in table test style', function()
    -- vim.cmd([[packadd go.nvim]])

    -- go.nvim may not auto loaded

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch_test.go'
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 1, 18, 11, 0 })
    local cmd = require('go.gotest').test_tblcase()
    eq({ 'go', 'test', '-run', [['^Test_branch$'/"a10"]], './lua/tests/fixtures/coverage' }, cmd)
  end)

  it('should test subcase in subtest style', function()
    -- vim.cmd([[packadd go.nvim]])

    -- go.nvim may not auto loaded

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch_test.go'
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 1, 75, 11, 0 })
    local cmd = require('go.gotest').test_tblcase()
    eq({ 'go', 'test', '-run', [['^Test_branch$'/"a10"]], './lua/tests/fixtures/coverage' }, cmd)
  end)
end)
