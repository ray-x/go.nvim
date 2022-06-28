local _ = require("plenary/busted")

local eq = assert.are.same
local cur_dir = vim.fn.expand("%:p:h")
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")
-- local ulog = require('go.utils').log
describe("should run fixplurals", function()
  vim.cmd([[packadd go.nvim]])
  vim.cmd([[packadd nvim-treesitter]])

  status = require("plenary.reload").reload_module("go.nvim")
  status = require("plenary.reload").reload_module("nvim-treesitter/nvim-treesitter")
  require("go").setup({ verbose = true })
  it("should run fixplurals", function()
    --
    local name = vim.fn.tempname() .. ".go"
    local path = cur_dir .. "/lua/tests/fixtures/impl/impl_input.go" -- %:p:h ? %:p
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. "/lua/tests/fixtures/impl/impl_golden.txt"), "\n")
    local cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    local bufn = vim.fn.bufnr("")

    vim.fn.setpos(".", { bufn, 4, 11, 0 })

    vim.bo.filetype = "go"

    local goimpl = require("go.impl")
    goimpl.run("io.Writer")
    vim.wait(400, function()
      vim.cmd("w")
    end)
    local impled = vim.fn.join(vim.fn.readfile(name), "\n")
    vim.fn.assert_equal(impled, expected)
    eq(expected, impled)
    cmd = "bd! " .. name
    vim.cmd(cmd)
  end)
end)
