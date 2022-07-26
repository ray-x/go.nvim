local eq = assert.are.same
local cur_dir = vim.fn.expand("%:p:h")
local busted = require("plenary/busted")

describe("should run func make", function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require("plenary.reload").reload_module("go.nvim")
  it("should make function", function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. "/lua/tests/fixtures/coverage/branch_test.go" -- %:p:h ? %:p
    require("go").setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand("$HOME") .. "/tmp/gonvim.log",
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos(".", { 0, 5, 11, 0 })
    local cmd = require("go.asyncmake").make('go', 'vet', '.')
    print(vim.inspect(cmd))

    eq({ "go", "vet", "."}, cmd)
  end)
  it("should make function inside a source code", function()
    --
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])

    local path = cur_dir .. "/lua/tests/fixtures/coverage/branch.go" -- %:p:h ? %:p
    require("go").setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand("$HOME") .. "/tmp/gonvim.log",
    })
    vim.cmd("silent exe 'e " .. path .. "'")
    vim.fn.setpos(".", { 0, 6, 11, 0 })
    local cmd = require("go.asyncmake").make('go', 'test', './...')

    eq({ "go", "test", "./..."}, cmd)
  end)
end)
