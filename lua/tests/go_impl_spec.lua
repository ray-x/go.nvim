local _ = require('plenary/busted')

local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")
-- local ulog = require('go.utils').log
describe('should run impl', function()
  it('should run impl', function()
    --
    if vim.fn.has('nvim-0.7') == 0 then
      -- treesitter master require nvim-0.7+
      return eq(1, 1)
    end

    vim.cmd([[packadd go.nvim]])
    vim.cmd([[packadd nvim-treesitter]])
    local status = require('plenary.reload').reload_module('go.nvim')
    status = require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')

    local name = vim.fn.tempname() .. '.go'
    local path = cur_dir .. '/lua/tests/fixtures/impl/impl_input.go' -- %:p:h ? %:p
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    local bufn = vim.fn.bufnr('')
    vim.fn.setpos('.', { bufn, 4, 11, 0 })
    vim.bo.filetype = 'go'

    require('go').setup({ verbose = true })
    local goimpl = require('go.impl')
    goimpl.run('io.Writer')
    vim.wait(1000, function() end)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/impl/impl_golden.txt'), '\n')
    local impled = vim.fn.join(vim.fn.readfile(name), '\n')
    print(vim.fn.assert_equal(impled, expected))
    eq(expected, impled)
    vim.cmd('bd! ' .. name)
  end)
end)
