local eq = assert.are.same
local cur_dir = vim.fn.expand("%:p:h")
local busted = require("plenary/busted")

describe("should run test", function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  status = require("plenary.reload").reload_module("go.nvim")
  it("should test function", function()
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
    local cmd = require("go.gotest").test_fun()
    local lines = vim.fn.readfile(path)

    eq({ "go", "test", "-v", "-run", "^Test_branch", "./lua/tests/fixtures/coverage" }, cmd)
  end)
end)
