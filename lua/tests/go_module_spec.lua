local _ = require('plenary/busted')

local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
describe('should run get module', function()
  it('should get module name', function()
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
    local path = cur_dir .. '/lua/tests/fixtures/fmt/goimports2_golden.go' -- %:p:h ? %:p
    local cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)
    local bufn = vim.fn.bufnr('')

    vim.fn.setpos('.', { bufn, 4, 3, 0 })

    vim.bo.filetype = 'go'

    local module = require('go.ts.go').get_module_at_pos(bufn)
    eq(module, 'fmt')
  end)
end)
