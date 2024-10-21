local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')
local godir = cur_dir .. '/lua/tests/fixtures'

-- hack latest nvim treestitter get_node_text bug
-- TODO remove this after nvim-treesitter is fixed
local nvim11 = vim.fn.has('nvim-0.11') == 1

describe('should run func test', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  vim.cmd([[packadd go.nvim]])
  require('plenary.reload').reload_module('go.nvim')
  require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')

  vim.wait(400, function() end)
  it('should test function', function()
    --
    -- go.nvim may not auto loaded
    local path = './coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
      test_runner = 'go',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 5, 11, 0 })
    local cmd = require('go.gotest').test_func()

    eq({ 'go', 'test', './coverage', "-test.run='^\\QTest_branch\\E$'" }, cmd)
  end)
  it('should test function inside a source code', function()
    --
    local path = './coverage/branch.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
      test_runner = 'go',
    })

    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 6, 11, 0 })
    local cmd = require('go.gotest').test_func()

    eq({ 'go', 'test', './coverage', "-test.run='^\\QTest_branch\\E$'" }, cmd)
  end)
  it('should test function with additional args to test binary', function()
    --
    local path = 'coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
      test_runner = 'go',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 5, 11, 0 })
    local cmd = require('go.gotest').test_func('-a', 'mock=true')

    eq({
      'go',
      'test',
      './coverage',
      '-args',
      'mock=true',
      "-test.run='^\\QTest_branch\\E$'",
    }, cmd)
  end)
end)

describe('should run test file', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')
  require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')
  it('should test function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = 'coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
      test_runner = 'go',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 5, 11, 0 })
    local cmd = require('go.gotest').test_file()

    eq({
      'go',
      'test',
      'coverage',
      '-test.run',
      [['Test_branch|TestBranch|TestBranchSubTest']],
    }, cmd)
  end)
end)

describe('should run test file with flags', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')
  require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')
  it('should test function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])
    require('plenary.reload').reload_module('go.nvim')
    require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')
    local path = 'coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 5, 11, 0 })
    local cmd = require('go.gotest').test_file('-t', 'tag1')

    eq({
      'go',
      'test',
      '-tags=tag1',
      'coverage',
      '-test.run',
      [['Test_branch|TestBranch|TestBranchSubTest']],
    }, cmd)
  end)
end)

describe('should run test package: ', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')
  require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')
  it('should test function', function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    require('plenary.reload').reload_module('go.nvim')
    require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')
    local path = 'coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 1, 1, 0 })
    local cmd = require('go.gotest').test_package()

    eq({ 'go', 'test', './coverage/...' }, cmd)
  end)
end)

describe('should run test: ', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  vim.cmd([[packadd go.nvim]])
  require('plenary.reload').reload_module('go.nvim')
  require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')
  it('should test function', function()
    --
    local path = 'coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 6, 1, 0 })
    local cmd = require('go.gotest').test('-n', '-t', 'tags1')

    eq({ 'go', 'test', '-tags=tags1', './coverage', "-test.run='^\\QTest_branch\\E$'" }, cmd)
  end)
end)

-- test passed but the exit code is not 0
describe('should allow select test func: ', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')
  require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')
  it('should test function', function()
    --
    local path = 'coverage/branch_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 0, 1, 1, 0 })
    local cmd = require('go.gotest').get_testfunc()

    eq({ 'Test_branch', 'TestBranch', 'TestBranchSubTest' }, cmd)
  end)
end)

describe('should run test file with flags inside file: ', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')
  require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')
  it('should test function with tag', function()
    --
    local path = 'coverage/tag_test.go' -- %:p:h ? %:p
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 1, 1, 1, 0 })
    local cmd = require('go.gotest').test_file('-t', 'tag1')

    eq({
      'go',
      'test',
      '-tags=tag1,integration,unit',
      'coverage',
      '-test.run',
      "'TestTag'",
    }, cmd)
  end)
end)

describe('should run subcase tests: ', function()
  vim.cmd([[packadd go.nvim]])

  require('plenary.reload').reload_module('go.nvim')
  require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')

  if nvim11 then
    eq(1, 1)
    return
  end
  it('should test subcase in table test style', function()
    -- go.nvim may not auto loaded
    local path = 'coverage/branch_test.go'
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 1, 18, 11, 0 })
    local cmd = require('go.gotest').test_tblcase()
    eq({ 'go', 'test', './coverage', "-test.run='^\\QTest_branch\\E$'/'^\\Qa10\\E$'" }, cmd)
  end)

  it('should test subcase in table test style when cursor inside test block', function()
    -- go.nvim may not auto loaded
    local path = 'coverage/branch_test.go'
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 1, 29, 12, 0 })
    local cmd = require('go.gotest').test_tblcase()
    eq(
      { 'go', 'test', './coverage', "-test.run='^\\QTest_branch\\E$'/'^\\Qb10 [step 1..3]\\E$'" },
      cmd
    )
  end)

  it('should test subcase in subtest style', function()
    local path = 'coverage/branch_test.go'
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 1, 75, 11, 0 })
    local cmd = require('go.gotest').test_tblcase()
    eq({ 'go', 'test', './coverage', "-test.run='^\\QTestBranchSubTest\\E$'/'^\\Qa11\\E$'" }, cmd)
  end)

  it('should test subcase in subtest style when cursor inside test block', function()
    local path = 'coverage/branch_test.go'
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
    })
    vim.cmd('cd ' .. godir)
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos('.', { 1, 82, 7, 0 })
    local cmd = require('go.gotest').test_tblcase()
    eq({ 'go', 'test', './coverage', "-test.run='^\\QTestBranchSubTest\\E$'/'^\\Qb11\\E$'" }, cmd)
  end)
end)
