local _ = require("plenary/busted")
local fn = vim.fn

local eq = assert.are.same
local cur_dir = vim.fn.expand("%:p:h")
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")
-- local ulog = require('go.utils').log
describe("should run mockgen", function()
  vim.cmd([[packadd go.nvim]])
  vim.cmd([[packadd nvim-treesitter]])
  require("plenary.reload").reload_module("go.nvim")
  require("plenary.reload").reload_module("nvim-treesitter/nvim-treesitter")

  require("go").setup({ verbose = true })
  it("should run mockgen", function()
    --
    local path = cur_dir .. "/lua/tests/fixtures/ts/interfaces.go" -- %:p:h ? %:p
    local cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)
    vim.cmd("cd lua/tests/fixtures/ts")
    local bufn = fn.bufnr("")

    vim.fn.setpos(".", { bufn, 14, 11, 0 })

    vim.bo.filetype = "go"

    local gomockgen = require("go.mockgen")
    cmd = gomockgen.run({ args = { "-s" } })
    -- vim.wait(400, function() end)

    local expected_cmd = {
      "mockgen",
      "-source",
      "interfaces.go",
      "-package",
      "mocks",
      "-destination",
      "mocks/mock_interfaces.go",
    }
    eq(cmd, expected_cmd)
  end)
end)
