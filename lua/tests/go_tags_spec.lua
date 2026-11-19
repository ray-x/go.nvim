local helpers = {}
local busted = require('plenary/busted')

local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")

-- time to wait for action to take effect
local wait_time = 500

local function with_mocked_jobstart(jobstart, cb)
  local install = require('go.install')
  local original_install = install.install
  local original_jobstart = vim.fn.jobstart
  local original_notify = vim.notify

  install.install = function()
    return true
  end
  vim.fn.jobstart = jobstart

  local ok, err = xpcall(cb, debug.traceback)

  install.install = original_install
  vim.fn.jobstart = original_jobstart
  vim.notify = original_notify

  if not ok then
    error(err)
  end
end

-- local ulog = require('go.utils').log
describe('should run gotags', function()
  local cmd
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  -- status = require("plenary.reload").reload_module("go.nvim")
  it('should run add json tags', function()
    --
    local name = vim.fn.tempname() .. '.go'
    local path = cur_dir .. '/lua/tests/fixtures/tags/add_all_input.go' -- %:p:h ? %:p
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/tags/add_all_golden.go'), '\n')
    cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    local bufn = vim.fn.bufnr('')

    vim.fn.setpos('.', { bufn, 8, 4, 0 })

    local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    -- ulog("buf read: " .. vim.inspect(l))

    vim.bo.filetype = 'go'

    -- ulog("exp:" .. vim.inspect(expected))

    local gotags = require('go.tags')
    gotags.add()
    -- enable the channel response
    vim.wait(wait_time, function() end)
    local fmt = vim.fn.join(vim.fn.readfile(name), '\n')
    -- ulog("tagged file: " .. fmt)
    vim.fn.assert_equal(fmt, expected)
    eq(expected, fmt)
    cmd = 'bd! ' .. name
    vim.cmd(cmd)
  end)
  it('should rm json tags', function()
    local name = vim.fn.tempname() .. '.go'
    --
    local path = cur_dir .. '/lua/tests/fixtures/tags/add_all_golden.go' -- %:p:h ? %:p
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/tags/add_all_input.go'), '\n')
    cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    local bufn = vim.fn.bufnr('')

    vim.fn.setpos('.', { bufn, 8, 4, 0 })

    local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    -- ulog("buf read: " .. vim.inspect(l))

    vim.bo.filetype = 'go'

    -- ulog("exp:" .. vim.inspect(expected))

    local gotags = require('go.tags')
    gotags.rm('json')
    -- enable the channel response
    vim.wait(wait_time, function() end)

    -- format the code
    local gofmt = require('go.format')
    gofmt.gofmt()
    vim.wait(wait_time, function() end)
    local fmt = vim.fn.join(vim.fn.readfile(name), '\n')
    -- ulog("tagged file: " .. fmt)
    vim.fn.assert_equal(fmt, expected)
    eq(expected, fmt)
    cmd = 'bd! ' .. name
    vim.cmd(cmd)
  end)
  it('should run clear json tags by default', function()
    local name = vim.fn.tempname() .. '.go'
    --
    local path = cur_dir .. '/lua/tests/fixtures/tags/add_all_golden.go' -- %:p:h ? %:p
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/tags/add_all_input.go'), '\n')
    cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    local bufn = vim.fn.bufnr('')

    vim.fn.setpos('.', { bufn, 8, 4, 0 })

    local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    -- ulog("buf read: " .. vim.inspect(l))

    vim.bo.filetype = 'go'

    -- ulog("exp:" .. vim.inspect(expected))

    local gotags = require('go.tags')
    gotags.rm()
    -- enable the channel response
    vim.wait(wait_time, function() end)

    local gofmt = require('go.format')
    gofmt.gofmt()
    vim.wait(wait_time, function() end)

    local fmt = vim.fn.join(vim.fn.readfile(name), '\n')
    -- ulog("tagged file: " .. fmt)
    vim.fn.assert_equal(fmt, expected)
    eq(expected, fmt)
    cmd = 'bd! ' .. name
    vim.cmd(cmd)
  end)
  it('should clear all tags', function()
    local name = vim.fn.tempname() .. '.go'
    --
    local path = cur_dir .. '/lua/tests/fixtures/tags/add_all_golden.go' -- %:p:h ? %:p
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/tags/add_all_input.go'), '\n')
    cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    local bufn = vim.fn.bufnr('')

    vim.fn.setpos('.', { bufn, 8, 4, 0 })

    local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    -- ulog("buf read: " .. vim.inspect(l))

    vim.bo.filetype = 'go'

    -- ulog("exp:" .. vim.inspect(expected))

    local gotags = require('go.tags')
    gotags.rm()
    -- enable the channel response
    vim.wait(wait_time, function() end)

    local gofmt = require('go.format')
    gofmt.gofmt()
    vim.wait(wait_time, function() end)

    local fmt = vim.fn.join(vim.fn.readfile(name), '\n')
    -- ulog("tagged file: " .. fmt)
    vim.fn.assert_equal(fmt, expected)
    eq(expected, fmt)
    cmd = 'bd! ' .. name
    vim.cmd(cmd)
  end)
  it('should update the original buffer when tags finish after switching buffers', function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local a_name = dir .. '/a.go'
    local b_name = dir .. '/b.go'
    local a_lines = {
      'package t',
      '',
      'type Alpha struct {',
      '\tName string',
      '}',
    }
    local b_lines = { 'package t', '', '// unrelated file', 'var b = 1' }
    local expected_lines = {
      'package t',
      '',
      'type Alpha struct {',
      '\tName string `json:"name"`',
      '}',
    }
    vim.fn.writefile(a_lines, a_name)
    vim.fn.writefile(b_lines, b_name)

    vim.cmd(" silent exe 'e " .. a_name .. "'")
    local ts = require('go.ts.go')
    local original_get_struct_node_at_pos = ts.get_struct_node_at_pos
    ts.get_struct_node_at_pos = function()
      return { name = 'Alpha' }
    end

    local ok, err = xpcall(function()
      with_mocked_jobstart(function(_, opts)
        vim.defer_fn(function()
          opts.on_stdout(nil, {
            [[{"start":3,"end":5,"lines":["type Alpha struct {","\tName string `json:\"name\"`","}"]}]],
          }, nil)
        end, 50)
        return 1
      end, function()
        require('go.tags').add()
        vim.cmd(" silent exe 'e " .. b_name .. "'")

        local success = vim.wait(1000, function()
          return vim.fn.join(vim.fn.readfile(a_name), '\n') == vim.fn.join(expected_lines, '\n')
        end)

        eq(true, success)
        eq(vim.fn.join(expected_lines, '\n'), vim.fn.join(vim.fn.readfile(a_name), '\n'))
        eq(vim.fn.join(b_lines, '\n'), vim.fn.join(vim.fn.readfile(b_name), '\n'))
      end)
    end, debug.traceback)
    ts.get_struct_node_at_pos = original_get_struct_node_at_pos
    if not ok then
      error(err)
    end

    vim.cmd('%bdelete!')
  end)
end)
