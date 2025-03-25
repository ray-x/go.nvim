local _ = require('plenary/busted')
print('aaa')
local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")

-- local ulog = require('go.utils').log
describe('should run fixplurals', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  -- status = require("plenary.reload").reload_module("go.nvim")
  it('should run fixplurals', function()
    --
    local name = vim.fn.tempname() .. '.go'
    local path = cur_dir .. '/lua/tests/fixtures/fixplurals/fixp_input.go' -- %:p:h ? %:p
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local expected =
      vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fixplurals/fixp_golden.go'), '\n')
    local cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    local bufn = vim.fn.bufnr('')
    vim.treesitter.stop()
    vim.treesitter.start()
    local parsers = require "nvim-treesitter.parsers"

    local root_lang_tree = parsers.get_parser(bufn, 'go')
    -- read current line

    root_lang_tree:parse()
    vim.fn.setpos('.', { bufn, 2, 11, 0 })
    print('current line', vim.api.nvim_get_current_line(), vim.o.filetype, bufn)

    vim.bo.filetype = 'go'

    local gofixp = require('go.fixplurals')
    gofixp.fixplurals()
    vim.wait(100, function()
      vim.cmd('w')
    end)
    local fmt = vim.fn.join(vim.fn.readfile(name), '\n')
    vim.fn.assert_equal(fmt, expected)
    eq(expected, fmt)
    cmd = 'bd! ' .. name
    vim.cmd(cmd)
  end)
end)
