local _ = require('plenary/busted')

local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
describe('should run fillstruct', function()
  vim.cmd([[packadd go.nvim]])

  it('should run fillstruct', function()
    --
    vim.o.ft = 'go'
    local expected = vim.fn.join(
      vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fill/fill_struct_golden.txt'),
      '\n'
    )

    local path = cur_dir .. '/lua/tests/fixtures/' -- %:p:h ? %:p
    vim.cmd('cd ' .. path)
    local fname = 'fill/fill_struct_input.go'

    local cmd = " silent exe 'e " .. fname .. "'"
    vim.cmd(cmd)
    -- _GO_NVIM_CFG.log_path = ''  -- log to console in github actions
    vim.bo.filetype = 'go'
    require('plenary.reload').reload_module('go.nvim')
    require('go').setup({ verbose = true, lsp_cfg = true })

    vim.cmd('sleep 2000m') -- allow gopls startup
    vim.fn.setpos('.', { 0, 20, 14, 0 })

    require('go.lsp').codeaction({cmd ='apply_fix', only = 'refactor.rewrite'})

    local filled
    local success = vim.wait(5000, function()
      require('go.utils').log('waiting for fill')
      vim.wait(500, function()
        return false
      end)

      filled = vim.api.nvim_buf_get_lines(0, 0, 40, false)
      filled = vim.fn.join(filled, '\n')
      require('go.utils').log('fill struct', vim.inspect(filled))
      if expected == filled then
        eq(true, true)
        return true
      end

      return false
    end, 300)
    require('go.utils').log('filled', filled, success, expected)

    eq(expected, filled)
  end)
end)
