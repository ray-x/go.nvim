local helpers = {}
local busted = require("plenary/busted")

local eq = assert.are.same
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")

describe("should run runner", function()
  vim.cmd([[packadd go.nvim]])
  require("go").setup({ verbose = true })
  it("should run runner", function()
    --
    local result = {}
    local opts = {
      update_buffer = true,
      on_exit = function(code, signal, output)
        eq(code, 0)
        eq(signal, 0)
        eq(vim.trim(output), "abc")
      end,
    }

    local runner = require("go.runner")
    runner.run({ "echo", "abc" }, opts)

    vim.cmd("sleep 10m") -- allow cleanup
  end)
end)
