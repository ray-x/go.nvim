local eq = assert.are.same

local busted = require("plenary/busted")
local cur_dir = vim.fn.expand("%:p:h")
describe("should get nodes  ", function()
  _GO_NVIM_CFG.verbose = true
  _GO_NVIM_CFG.comment_placeholder = "   "

  local status = require("plenary.reload").reload_module("go.nvim")
  status = require("plenary.reload").reload_module("nvim-treesitter/nvim-treesitter")

  local name = vim.fn.tempname() .. ".go"
  print("tmp:" .. name)
  --
  local path = cur_dir .. "/lua/tests/fixtures/ts/playlist.go" -- %:p:h ? %:p
  local lines = vim.fn.readfile(path)
  vim.fn.writefile(lines, name)
  local cmd = "silent exe 'e " .. name .. "'"
  vim.cmd(cmd)

  local bufn = vim.fn.bufnr("")
  it("should get struct playlist and generate comments", function()
    vim.fn.setpos(".", { bufn, 20, 14, 0 })
    local query = require("go.comment").gen(20, 14)
    eq("// createPlaylist function    ", query)
  end)

  it("should get struct playlist and generate comments", function()
    vim.fn.setpos(".", { bufn, 14, 4, 0 })
    local query = require("go.comment").gen(14, 4)
    eq("// playlist type    ", query)
  end)
end)
