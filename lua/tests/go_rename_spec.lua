local eq = assert.are.same
local cur_dir = vim.fn.expand("%:p:h")

local busted = require("plenary/busted")
describe("should run gorename", function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require("plenary.reload").reload_module("go.nvim")
  it("should run rename", function()
    eq(1, 1)
    -- use lsp to rename
    -- local name = vim.fn.tempname() .. ".go"
    -- print("tmp:" .. name)
    -- --
    -- local path = cur_dir .. "/lua/tests/fixtures/rename/interface.go" -- %:p:h ? %:p
    -- print("test:" .. path)
    -- -- read target file
    -- local lines = vim.fn.readfile(path)
    -- vim.fn.writefile(lines, name)
    -- vim.bo.filetype = "go"
    -- local cmd = " silent exe 'e " .. name .. "'"
    -- vim.cmd(cmd)
    --
    -- local bufn = vim.fn.bufnr("")
    -- vim.fn.setpos(".", {bufn, 26, 18, 0})
    --
    -- local gorename = require("go.rename")
    -- gorename.run()
    -- local expected = vim.fn.join(vim.fn.readfile(cur_dir
    --                                                  .. "/lua/tests/fixtures/rename/interface_golden.go"),
    --                              "\n")
    -- print("exp:" .. vim.inspect(expected))
    --
    -- local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    -- print("buf read: " .. vim.inspect(l))
    --
    -- -- enable the channel response
    -- vim.wait(100, function()
    -- end)
    -- local rename = vim.fn.join(vim.fn.readfile(name), "\n")
    -- print("fmt" .. rename)
    -- vim.fn.assert_equal(rename, expected)
    -- eq(expected, rename)
    -- local cmd = "bd! " .. name
    -- vim.cmd(cmd)
  end)
end)
