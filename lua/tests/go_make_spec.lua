local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

describe('should run func make', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')
  it('should make function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/'
    local fname = 'coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/.cache/nvim/gonvim.log',
    })
    vim.cmd('silent cd ' .. path)
    vim.cmd("silent exe 'e " .. fname .. "'")
    vim.fn.setpos('.', { 0, 5, 11, 0 })
    local cmd = require('go.asyncmake').make('go', 'vet', './coverage')
    print(vim.inspect(cmd))

    eq({ 'go', 'vet', './coverage' }, cmd)
  end)
  it('should make function inside a source code', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/'
    local fname = './coverage/branch.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/.cache/nvim/gonvim.log',
    })

    vim.cmd('silent cd ' .. path)
    vim.cmd("silent exe 'e " .. fname .. "'")
    vim.fn.setpos('.', { 0, 6, 11, 0 })
    local cmd = require('go.asyncmake').make('go', 'test', './coverage')

    eq({ 'go', 'test', './coverage' }, cmd)
  end)
  it('should keep the newer job id when an older job exits', function()
    local asyncmake = require('go.asyncmake')
    asyncmake.runjob({ 'sleep', '0.1' }, 'sleep', {})
    local older = _GO_NVIM_CFG.job_id
    asyncmake.runjob({ 'sleep', '30' }, 'sleep', {})
    local newer = _GO_NVIM_CFG.job_id

    eq(true, older ~= newer)
    vim.fn.jobwait({ older }, 5000)
    eq(newer, _GO_NVIM_CFG.job_id)

    asyncmake.stopjob()
    eq(
      true,
      vim.wait(2000, function()
        return vim.fn.jobwait({ newer }, 0)[1] ~= -1
      end, 20)
    )
  end)
end)
