local eq = assert.are.same
local cur_dir = vim.fn.expand("%:p:h")
local busted = require("plenary/busted")

describe("should run gofmt", function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  status = require("plenary.reload").reload_module("go.nvim")
  it("should run fmt", function()
    local name = vim.fn.tempname() .. ".go"
    print("tmp:" .. name)
    --
    local path = cur_dir .. "/lua/tests/fixtures/fmt/hello.go" -- %:p:h ? %:p
    print("test:" .. path)
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. "/lua/tests/fixtures/fmt/hello_golden.go"), "\n")
    local cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    print("buf read: " .. vim.inspect(l))

    vim.bo.filetype = "go"

    print("exp:" .. vim.inspect(expected))
    print("tmp" .. name)

    local gofmt = require("go.format")
    gofmt.gofmt()
    -- enable the channel response
    vim.wait(400, function()
    end)
    local fmt = vim.fn.join(vim.fn.readfile(name), "\n")
    print("fmt" .. fmt)
    vim.fn.assert_equal(fmt, expected)
    eq(expected, fmt)
    local cmd = "bd! " .. name
    vim.cmd(cmd)
  end)
  it("should run fmt sending from buffer", function()
    local name = vim.fn.tempname() .. ".go"
    print("tmp:" .. name)
    --
    local path = cur_dir .. "/lua/tests/fixtures/fmt/hello.go" -- %:p:h ? %:p
    print("test:" .. path)
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. "/lua/tests/fixtures/fmt/hello_golden.go"), "\n")
    local cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    print("buf read: " .. vim.inspect(l))

    vim.bo.filetype = "go"

    print("exp:" .. vim.inspect(expected))
    print("tmp" .. name)

    local gofmt = require("go.format")
    gofmt.gofmt(true)
    -- enable the channel response
    vim.wait(100, function()
    end)
    local fmt = vim.fn.join(vim.fn.readfile(name), "\n")
    print("fmt" .. fmt)
    vim.fn.assert_equal(fmt, expected)
    eq(expected, fmt)
    local cmd = "bd! " .. name
    vim.cmd(cmd)
  end)
  it("should run import from file", function()
    local path = cur_dir .. "/lua/tests/fixtures/fmt/goimports.go" -- %:p:h ? %:p
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. "/lua/tests/fixtures/fmt/goimports_golden.go"), "\n")
    local name = vim.fn.tempname() .. ".go"
    print(name)
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    require("go").setup({goimport = "goimports"})
    vim.cmd([[cd %:p:h]])
    require("go.format").goimport()
    print("workspaces:", vim.inspect(vim.lsp.buf.list_workspace_folders()))
    vim.wait(400, function()
    end)
    local fmt = vim.fn.join(vim.fn.readfile(name), "\n")
    eq(expected, fmt)
    cmd = "bd! " .. name
    vim.cmd(cmd)
  end)
  it("should run import from file buffer with goimport", function()
    local path = cur_dir .. "/lua/tests/fixtures/fmt/goimports.go" -- %:p:h ? %:p
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. "/lua/tests/fixtures/fmt/goimports_golden.go"), "\n")
    local name = vim.fn.tempname() .. ".go"
    print(name)
    local lines = vim.fn.readfile(path)
    local cmd = " silent exe 'e " .. name .. "'"
    vim.fn.writefile(lines, name)
    vim.cmd(cmd)
    vim.cmd([[cd %:p:h]])
    print("code write to " .. name)

    require("go").setup({goimport = "goimports"})
    local gofmt = require("go.format")
    gofmt.goimport(true)

    vim.wait(400, function()
    end)
    vim.cmd([[w]])
    local fmt = vim.fn.join(vim.fn.readfile(name), "\n")

    print(fmt)
    eq(expected, fmt)
  end)

  it("should run import from file with gopls", function()
    local path = cur_dir .. "/lua/tests/fixtures/fmt/goimports2.go" -- %:p:h ? %:p
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. "/lua/tests/fixtures/fmt/goimports2_golden.go"), "\n")

    _GO_NVIM_CFG.goimport = 'gopls'

    local cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)

    vim.cmd([[cd %:p:h]])
    vim.cmd([[packadd go.nvim]])
    require("go").setup({goimport = "gopls", lsp_cfg = true})
    vim.wait(2000, function()
    end)

    require("go.format").goimport()

    print("workspaces:", vim.inspect(vim.lsp.buf.list_workspace_folders()))
    vim.wait(400, function()
    end)
    vim.cmd([[w]])
    local fmt = vim.fn.join(vim.fn.readfile(path), "\n")
    print(vim.inspect(fmt))
    eq(expected, fmt)
    eq(1, 1) -- still not working
    cmd = "bd! " .. path
    vim.cmd(cmd)
  end)
end)
