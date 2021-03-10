local helpers = {}
local busted = require("plenary/busted")

local eq = assert.are.same
local cur_dir = vim.fn.expand("%:p:h")
local ulog = require('go.utils').log
describe(
  "should run gotags",
  function()
    --vim.fn.readfile('minimal.vim')
    -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
    status = require("plenary.reload").reload_module("go.nvim")
    it(
      "should run add json tags",
      function()
        --
        local name = vim.fn.tempname() .. ".go"
        local path = cur_dir .. "/lua/tests/fixtures/tags/add_all_input.go" -- %:p:h ? %:p
        local lines = vim.fn.readfile(path)
        vim.fn.writefile(lines, name)
        local expected =
          vim.fn.join(vim.fn.readfile(cur_dir .. "/lua/tests/fixtures/tags/add_all_golden.go"), "\n")
        local cmd = " silent exe 'e " .. name .. "'"
        vim.cmd(cmd)
        local bufn = vim.fn.bufnr("")

        vim.fn.setpos(".", {bufn, 8, 4, 0})


        local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
        -- ulog("buf read: " .. vim.inspect(l))

        vim.bo.filetype = "go"

        -- ulog("exp:" .. vim.inspect(expected))

        local gotags = require("go.tags")
        gotags.add()
        -- enable the channel response
        vim.wait(100, function () end)
        local fmt =
          vim.fn.join(vim.fn.readfile(name), "\n")
        -- ulog("tagged file: " .. fmt)
        vim.fn.assert_equal(fmt, expected)
        eq(expected, fmt)
        local cmd = "bd! ".. name
        vim.cmd(cmd)
      end
    )
    it(
      "should rm json tags",
      function()
        local name = vim.fn.tempname() .. ".go"
        --
        local path = cur_dir .. "/lua/tests/fixtures/tags/add_all_golden.go" -- %:p:h ? %:p
        local lines = vim.fn.readfile(path)
        vim.fn.writefile(lines, name)
        local expected =
          vim.fn.join(vim.fn.readfile(cur_dir .. "/lua/tests/fixtures/tags/add_all_input.go"), "\n")
        local cmd = " silent exe 'e " .. name .. "'"
        vim.cmd(cmd)
        local bufn = vim.fn.bufnr("")

        vim.fn.setpos(".", {bufn, 8, 4, 0})


        local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
        -- ulog("buf read: " .. vim.inspect(l))

        vim.bo.filetype = "go"

        -- ulog("exp:" .. vim.inspect(expected))

        local gotags = require("go.tags")
        gotags.rm('json')
        -- enable the channel response
        vim.wait(100, function () end)
        local fmt =
          vim.fn.join(vim.fn.readfile(name), "\n")
        -- ulog("tagged file: " .. fmt)
        vim.fn.assert_equal(fmt, expected)
        eq(expected, fmt)
        local cmd = "bd! ".. name
        vim.cmd(cmd)
      end
    )
    it(
      "should run clear json tags by default",
      function()
        local name = vim.fn.tempname() .. ".go"
        --
        local path = cur_dir .. "/lua/tests/fixtures/tags/add_all_golden.go" -- %:p:h ? %:p
        local lines = vim.fn.readfile(path)
        vim.fn.writefile(lines, name)
        local expected =
          vim.fn.join(vim.fn.readfile(cur_dir .. "/lua/tests/fixtures/tags/add_all_input.go"), "\n")
        local cmd = " silent exe 'e " .. name .. "'"
        vim.cmd(cmd)
        local bufn = vim.fn.bufnr("")

        vim.fn.setpos(".", {bufn, 8, 4, 0})


        local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
        -- ulog("buf read: " .. vim.inspect(l))

        vim.bo.filetype = "go"

        -- ulog("exp:" .. vim.inspect(expected))

        local gotags = require("go.tags")
        gotags.rm()
        -- enable the channel response
        vim.wait(100, function () end)
        local fmt =
          vim.fn.join(vim.fn.readfile(name), "\n")
        -- ulog("tagged file: " .. fmt)
        vim.fn.assert_equal(fmt, expected)
        eq(expected, fmt)
        local cmd = "bd! ".. name
        vim.cmd(cmd)
      end
    )
    it(
      "should clear all tags",
      function()
        local name = vim.fn.tempname() .. ".go"
        --
        local path = cur_dir .. "/lua/tests/fixtures/tags/add_all_golden.go" -- %:p:h ? %:p
        local lines = vim.fn.readfile(path)
        vim.fn.writefile(lines, name)
        local expected =
          vim.fn.join(vim.fn.readfile(cur_dir .. "/lua/tests/fixtures/tags/add_all_input.go"), "\n")
        local cmd = " silent exe 'e " .. name .. "'"
        vim.cmd(cmd)
        local bufn = vim.fn.bufnr("")

        vim.fn.setpos(".", {bufn, 8, 4, 0})


        local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
        -- ulog("buf read: " .. vim.inspect(l))

        vim.bo.filetype = "go"

        -- ulog("exp:" .. vim.inspect(expected))

        local gotags = require("go.tags")
        gotags.rm()
        -- enable the channel response
        vim.wait(100, function () end)
        local fmt =
          vim.fn.join(vim.fn.readfile(name), "\n")
        -- ulog("tagged file: " .. fmt)
        vim.fn.assert_equal(fmt, expected)
        eq(expected, fmt)
        local cmd = "bd! ".. name
        vim.cmd(cmd)
      end
    )
  end
)
