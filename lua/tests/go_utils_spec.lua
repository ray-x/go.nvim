local eq = assert.are.same

local busted = require('plenary/busted')
local cur_dir = vim.fn.expand('%:p:h')
describe('should get file name and number ', function()
  require('plenary.reload').reload_module('go.nvim')

  require('go').setup({
    verbose = true,
    trace = true,
    lsp_cfg = true,
    log_path = vim.fn.expand('$HOME') .. '/tmp/gonvim.log',
  })

  local utils = require('go.utils')
  it('should get file name and number in windows', function()
    local f2, f3 = utils.get_fname_num(
      "C:\\Users\\user\\go\\src\\github.com\\user\\project\\main.go:12:2: expected declaration, found 'IDENT' main"
    )
    eq(f2, 'C:\\Users\\user\\go\\src\\github.com\\user\\project\\main.go')
    eq(f3, 12)
  end)

  it('should get file name and number in windows', function()
    local f2, f3 = utils.get_fname_num(
      "C:\\Users\\user\\go\\src\\github.com\\user\\project\\main.go:12: expected declaration, found 'IDENT' main"
    )
    eq(f2, 'C:\\Users\\user\\go\\src\\github.com\\user\\project\\main.go')
    eq(f3, 12)
  end)
  it('should get file name and number in linux', function()
    local f2, f3 = utils.get_fname_num(
      "/home/user/go/src/github.com/user/project/main.go:12:2: expected declaration, found 'IDENT' main"
    )
    eq(f2, '/home/user/go/src/github.com/user/project/main.go')
    eq(f3, 12)
  end)
end)
