local _ = require('plenary/busted')

local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
describe('should run get module', function()
  it('should get module name', function()
    local path = cur_dir .. '/lua/tests/fixtures/fmt/goimports2_golden.go' -- %:p:h ? %:p
    local cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)
    --
    vim.cmd([[packadd go.nvim]])
    vim.cmd([[packadd nvim-treesitter]])
    require('plenary.reload').reload_module('go.nvim')
    require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')
    vim.cmd('e')

    require('go').setup({ verbose = true })
    local bufn = vim.api.nvim_get_current_buf()

    vim.fn.setpos('.', { bufn, 3, 9, 0 })

    vim.bo.filetype = 'go'

    local module = require('go.ts.go').get_module_at_pos(bufn)
    eq(module, 'fmt')
  end)
end)
