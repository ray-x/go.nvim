local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
-- func Println(a ...any) (n int, err error)
-- func fmt.Println(a ...any) (n int, err error)
-- func fmt.inner.Println(a ...any) (n int, err error)
-- func fmt.inner2.Println3(a ...any) (n int, err error)
-- func fmt.inner2.Println3(a any, par int) (n int, err error)
-- func fmt.inner2.Println3(a any, par int)  int
-- func fmt.inner2.Println3(par int)  int
-- func fmt.inner2.Println3(par int)
-- func fmt.inner2.Println3(par *[]int)
-- func fmt.inner2.Println3(par struct mnt{})
-- /(\%(\w\|\_s\|[*\.\[\],\{\}<>-]\)*)/
-- /\v\((\w|\_s|[*\.\[\],{}<>-])*\)
local busted = require('plenary/busted')

describe('regex should work', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')

  require('go').setup({
    trace = true,
    log_path = vim.fn.expand('$HOME') .. '/.cache/nvim/gonvim.log',
  })

  print(vim.fn.expand('$HOME') .. '/tmp/gonvim.log')
  it('should find return', function()
    local str = [[func Println(a ...any) (n int, err error)]]
    local ret = require('go.lsp').find_ret(str)
    print(vim.inspect(ret))
    eq({ 'n', 'err' }, ret)
  end)

  it('should find return', function()
    local str = [[func fmt.Println(a ...any) (int, error)]]
    local ret, e = require('go.lsp').find_ret(str)
    print(vim.inspect(ret))
    eq({ 'i', 'err' }, ret)
    eq(true, e)
  end)
  it('should find return', function()
    local str = [[func fmt.Println(a, b int) (int, error)]]
    local ret, e = require('go.lsp').find_ret(str)
    print(vim.inspect(ret))
    eq({ 'i', 'err' }, ret)
    eq(true, e)
  end)

  it('should find return', function()
    local str = [[func fmt.Println(a, b int) int]]
    local ret, e = require('go.lsp').find_ret(str)
    print(vim.inspect(ret))
    eq({ 'i' }, ret)
    eq(false, e)
  end)

  it('should find return', function()
    local str = [[func fmt.Println(a, b int) MyType]]
    local ret, e = require('go.lsp').find_ret(str)
    print(vim.inspect(ret))
    eq({ 'myType' }, ret)
    eq(false, e)
  end)

  it('should find return', function()
    local str = [[func fmt.Println(a, b int) (MyType, error)]]
    local ret, e = require('go.lsp').find_ret(str)
    print(vim.inspect(ret))
    eq({ 'myType', 'err' }, ret)
    eq(true, e)
  end)
end)
describe('should run hover', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')
  it('should run hover', function()
    local result = {
      contents = {
        kind = 'markdown',
        value = [[```go\nfunc fmt.Println(a ...any) (n int, err error)(\%(\w\|\_s\|[*\.\[\],\{\}<>-]\)*)\n```\n\nPrintln formats using the default formats for its operands and writes to standard output\\.\nSpaces are always added between operands and a newline is appended\\.\nIt returns the number of bytes written and any write error encountered\\.\n\n\n[`fmt.Println` on pkg.go.dev](https://pkg.go.dev/fmt?utm_source=gopls#Println)]],
      },
      range = {},
    }

    local ret = require('go.lsp').gen_return(result)
    print(vim.inspect(ret))
  end)
end)
