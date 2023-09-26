local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

describe('should run func test', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  local status = require('plenary.reload').reload_module('go.nvim')
  it('should test function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
      test_runner = 'go',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 5, 11, 0 })
    local cmd = require('go.gotest').test_func()

    eq({ 'go', 'test', '-run', [['^Test_branch$']], './lua/tests/fixtures/coverage' }, cmd)
  end)
  it('should test function inside a source code', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
      test_runner = 'go',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 6, 11, 0 })
    local cmd = require('go.gotest').test_func()

    eq({ 'go', 'test', '-run', [['^Test_branch$']], './lua/tests/fixtures/coverage' }, cmd)
  end)
  it('should test function with additional args to test binary', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
      test_runner = 'go',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 5, 11, 0 })
    local cmd = require('go.gotest').test_func('-a', 'mock=true')

    eq(
      {
        'go',
        'test',
        '-run',
        [['^Test_branch$']],
        './lua/tests/fixtures/coverage',
        '-args',
        'mock=true',
      },
      cmd
    )
  end)
end)

describe('should run test file', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  local status = require('plenary.reload').reload_module('go.nvim')
  it('should test function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
      test_runner = 'go',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 5, 11, 0 })
    local cmd = require('go.gotest').test_file()

    eq({ 'go', 'test', '-run', [['Test_branch|TestBranch']], 'lua/tests/fixtures/coverage' }, cmd)
  end)
end)

describe('should run test file with flags', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  local status = require('plenary.reload').reload_module('go.nvim')
  it('should test function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 5, 11, 0 })
    local cmd = require('go.gotest').test_file('-t', 'tag1')

    eq(
      {
        'go',
        'test',
        '-tags=tag1',
        '-run',
        [['Test_branch|TestBranch']],
        'lua/tests/fixtures/coverage',
      },
      cmd
    )
  end)
end)

describe('should run test package', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  local status = require('plenary.reload').reload_module('go.nvim')
  it('should test function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 1, 1, 0 })
    local cmd = require('go.gotest').test_package()

    eq({ 'go', 'test', './lua/tests/fixtures/coverage/...' }, cmd)
  end)
end)

describe('should run test ', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  local status = require('plenary.reload').reload_module('go.nvim')
  it('should test function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 6, 1, 0 })
    local cmd = require('go.gotest').test('-n', '-t', 'tags1')

    eq(
      { 'go', 'test', '-tags=tags1', '-run', [['^Test_branch$']], './lua/tests/fixtures/coverage' },
      cmd
    )
  end)
end)

-- test passed but the exit code is not 0
describe('should allow select test func', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  local status = require('plenary.reload').reload_module('go.nvim')
  it('should test function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 1, 1, 0 })
    local cmd = require('go.gotest').get_testfunc()

    eq({ 'Test_branch', 'TestBranch' }, cmd)
  end)
end)

describe('should run test file with flags inside file', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  local status = require('plenary.reload').reload_module('go.nvim')
  it('should test function with tag', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. '/lua/tests/fixtures/coverage/tag_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 1, 1, 1, 0 })
    local cmd = require('go.gotest').test_file('-t', 'tag1')

    eq({
      'go',
      'test',
      '-tags=tag1,integration,unit',
      '-run',
      [['TestTag']],
      'lua/tests/fixtures/coverage',
    }, cmd)
  end)
end)

describe('should run subcase test', function()
  require('plenary.reload').reload_module('go.nvim')
  it('should test subcase in table test style', function()
    -- vim.cmd([[packadd go.nvim]])
  
    -- go.nvim may not auto loaded

    local path = cur_dir .. '/lua/tests/fixtures/coverage/branch_test.go'
    print(" asdfasfdfasdfasdfas")
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 1, 18, 15, 0 })

    local cmd = require('go.gotest').test_tblcase()

    print(cmd)
    eq({ 'go', 'test', '-run', [['^Test_branch$']], './lua/tests/fixtures/coverage' }, cmd)
  end)
end)
