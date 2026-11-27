require('plenary/busted')

local eq = assert.are.same
-- local status = require("plenary.reload").reload_module("go.nvim")

describe('should run runner', function()
  vim.cmd([[packadd go.nvim]])
  require('go').setup({ verbose = true })
  it('should run runner', function()
    --
    local opts = {
      update_buffer = true,
      on_exit = function(code, signal, output)
        eq(code, 0)
        eq(signal, 0)
        eq(vim.trim(output), 'abc')
      end,
    }

    local runner = require('go.runner')
    runner.run({ 'echo', 'abc' }, opts)

    vim.cmd('sleep 10m') -- allow cleanup
  end)
  it('should call on_exit only once', function()
    local calls = 0
    local opts = {
      on_exit = function(code, signal, output)
        calls = calls + 1
        eq(code, 0)
        eq(signal, 0)
        return output
      end,
    }

    local runner = require('go.runner')
    runner.run({ 'echo', 'abc' }, opts)

    eq(true, vim.wait(1000, function()
      return calls > 0
    end, 10))
    eq(1, calls)
  end)
  it('should run the command in opts.cwd', function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local output
    local opts = {
      cwd = dir,
      on_exit = function(code, signal, data)
        eq(code, 0)
        eq(signal, 0)
        output = vim.trim(data)
        return data
      end,
    }

    local runner = require('go.runner')
    runner.run({ 'pwd' }, opts)

    eq(true, vim.wait(1000, function()
      return output ~= nil
    end, 10))
    eq(vim.fn.resolve(dir), vim.fn.resolve(output))
  end)
end)
