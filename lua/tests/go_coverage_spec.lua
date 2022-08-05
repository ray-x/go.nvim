local eq = assert.are.same
local cur_dir = vim.fn.expand("%:p:h")
local busted = require("plenary/busted")

describe("should read coveragefile", function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  local status = require("plenary.reload").reload_module("go.nvim")
  it("should read coverage file", function()
    --
    local path = cur_dir .. "/lua/tests/fixtures/coverage/coverage.out" -- %:p:h ? %:p
    print("test:" .. path)
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand("$HOME") .. "/tmp/gonvim.log"
    })

    local cover = require("go.coverage")
    local result = cover.read_cov(path)

    -- print(vim.inspect(result))
    local n = "branch.go"
    local range = {['end'] = {character = 13, line = 4}, start = {character = 27, line = 3}}

    eq(result[n][1].file, "github.com/go.nvim/branch.go")
    eq(result[n][1].range, range)
    eq(result[n].file_lines, 9)
    eq(result[n].file_covered, 4)

    eq(result.total_lines, 9)
    eq(result.total_covered, 4)
    -- eq(result[n][1], "github.com/go.nvim/branch.go")
  end)
  it("should generate sign list", function()
    --
    local path = cur_dir .. "/lua/tests/fixtures/coverage/coverage.out" -- %:p:h ? %:p
    print("test:" .. path)
    -- go.nvim may not auto loaded
    vim.cmd([[packadd go.nvim]])
    require('go').setup({
      trace = true,
      lsp_cfg = true,
      log_path = vim.fn.expand("$HOME") .. "/tmp/gonvim.log",
      gocoverage_sign = '|'
    })

    local cover = require("go.coverage")
    cover.highlight()

    local coverage = {
      {
        cnt = 1,
        file = "github.com/go.nvim/branch.go",
        filename = "branch.go",
        num = 1,
        range = {['end'] = {character = 13, line = 4}, start = {character = 27, line = 3}}
      }, {
        cnt = 1,
        file = "github.com/go.nvim/branch.go",
        filename = "branch.go",
        num = 1,
        range = {['end'] = {character = 13, line = 7}, start = {character = 2, line = 7}}
      }
    }

    local result = cover.add(1, coverage)
    -- print(vim.inspect(result))
    local sign = {
      buffer = 1,
      group = 'gocoverage_ns',
      id = 3,
      lnum = 3,
      name = 'goCoverageCovered',
      priority = 7
    }
    eq(result[1], sign)
    -- eq(result[n][1], "github.com/go.nvim/branch.go")
  end)
end)
