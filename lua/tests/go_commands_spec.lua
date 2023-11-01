local _ = require('plenary/busted')

local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")
-- local ulog = require('go.utils').log
describe('should run Go commands', function()
  it('should run GoRun', function()
    --
    if vim.fn.has('nvim-0.7') == 0 then
      -- treesitter master require nvim-0.7+
      return eq(1, 1)
    end

    vim.cmd([[packadd go.nvim]])
    vim.cmd([[packadd nvim-treesitter]])
    local status = require('plenary.reload').reload_module('go.nvim')
    status = require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')

    require('go').setup({ verbose = true })
    local path = cur_dir .. '/lua/tests/fixtures/fmt/goimports.go' -- %:p:h ? %:p

    local name = vim.fn.tempname() .. '.go'

    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    -- local bufn = vim.fn.bufnr('')
    --
    vim.cmd('GoFmt')

    path = cur_dir .. '/lua/tests/fixtures/'
    local fname = 'coverage/branch_test.go' -- %:p:h ? %:p

    -- local lines = vim.fn.readfile(path)
    vim.cmd('cd ' .. path)

    -- name = vim.fn.tempname() .. '.go'
    -- vim.fn.writefile(lines, name)
    local cmd = " silent exe 'e " .. fname .. "'"

    vim.cmd(cmd)
    bufn = vim.fn.bufnr('')
    vim.cmd('GoRun')
    vim.cmd('GoBuild')

    vim.cmd('GoTest')
    vim.cmd('GoTest -c')
  end)
end)
