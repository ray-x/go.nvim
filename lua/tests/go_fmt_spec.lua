local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

local function with_mocked_jobstart(jobstart, cb)
  local install = require('go.install')
  local original_install = install.install
  local original_jobstart = vim.fn.jobstart
  local original_chansend = vim.fn.chansend
  local original_chanclose = vim.fn.chanclose
  local original_notify = vim.notify

  install.install = function()
    return true
  end
  vim.fn.jobstart = jobstart
  vim.fn.chansend = function()
  end
  vim.fn.chanclose = function()
  end

  local ok, err = xpcall(cb, debug.traceback)

  install.install = original_install
  vim.fn.jobstart = original_jobstart
  vim.fn.chansend = original_chansend
  vim.fn.chanclose = original_chanclose
  vim.notify = original_notify

  if not ok then
    error(err)
  end
end

describe('should run gofmt', function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  require('plenary.reload').reload_module('go.nvim')
  it('should run fmt', function()
    local name = vim.fn.tempname() .. '.go'
    print('tmp:' .. name)
    --
    local path = cur_dir .. '/lua/tests/fixtures/fmt/hello.go' -- %:p:h ? %:p
    print('test:' .. path)
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/hello_golden.go'), '\n')
    local cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)
    local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    print('buf read: ' .. vim.inspect(l))

    vim.bo.filetype = 'go'

    print('exp:' .. vim.inspect(expected))
    print('tmp' .. name)

    local gofmt = require('go.format')
    gofmt.gofmt()
    -- enable the channel response
    vim.wait(400, function() end)
    local fmt = vim.fn.join(vim.fn.readfile(name), '\n')
    print('fmt' .. fmt)
    vim.fn.assert_equal(fmt, expected)
    eq(expected, fmt)
    cmd = 'bd! ' .. name
    vim.cmd(cmd)
  end)
  it('should run fmt sending from buffer', function()
    local name = vim.fn.tempname() .. '.go'
    print('tmp:' .. name)
    --
    local path = cur_dir .. '/lua/tests/fixtures/fmt/hello.go' -- %:p:h ? %:p
    print('test:' .. path)
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/hello_golden.go'), '\n')
    local cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)

    vim.cmd([[packadd go.nvim]])
    local l = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    print('buf read: ' .. vim.inspect(l))

    vim.bo.filetype = 'go'

    print('exp:' .. vim.inspect(expected))
    print('tmp' .. name)

    local gofmt = require('go.format')
    gofmt.gofmt()
    -- enable the channel response
    vim.wait(400, function() end)
    local fmt = vim.fn.join(vim.fn.readfile(name), '\n')
    print('fmt' .. fmt)
    vim.fn.assert_equal(fmt, expected)
    eq(expected, fmt)
    cmd = 'bd! ' .. name
    vim.cmd(cmd)
  end)
  it('should run import from file with goimports', function()
    local path = cur_dir .. '/lua/tests/fixtures/fmt/goimports.go' -- %:p:h ? %:p
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports_golden.go'), '\n')
    local name = vim.fn.tempname() .. '.go'
    print(name)
    local lines = vim.fn.readfile(path)
    vim.fn.writefile(lines, name)
    local cmd = " silent exe 'e " .. name .. "'"
    vim.cmd(cmd)

    vim.cmd([[packadd go.nvim]])
    require('go').setup({ goimports = 'goimports' })
    _GO_NVIM_CFG.goimports = 'goimports'
    vim.cmd([[cd %:p:h]])
    require('go.format').goimports()
    -- print('workspaces:', vim.inspect(vim.lsp.buf.list_workspace_folders()))
    vim.wait(500, function() end)
    local fmt = vim.fn.join(vim.fn.readfile(name), '\n')
    eq(expected, fmt)
    cmd = 'bd! ' .. name
    vim.cmd(cmd)
  end)
  it('should run import from file with goimports with package name', function()
    local path = cur_dir .. '/lua/tests/fixtures/fmt/goimports.go' -- %:p:h ? %:p
    local expected = vim.fn.join(vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports_golden.go'), '\n')
    local name = vim.fn.tempname() .. '.go'
    print(name)
    local lines = vim.fn.readfile(path)
    local cmd = " silent exe 'e " .. name .. "'"
    vim.fn.writefile(lines, name)
    vim.cmd(cmd)
    vim.cmd([[cd %:p:h]])
    print('code write to ' .. name)

    require('go').setup({ goimports = 'goimports', gofmt = 'gofmt' })
    local gofmt = require('go.format')
    gofmt.goimports('fmt')

    vim.wait(400, function() end)
    vim.cmd([[w]])
    local fmt = vim.fn.join(vim.fn.readfile(name), '\n')

    print(fmt)
    eq(expected, fmt)
    vim.cmd('%bdelete!')
  end)
  it('should update the original buffer when goimports finishes after switching buffers', function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local a_name = dir .. '/a.go'
    local b_name = dir .. '/b.go'
    local a_lines = vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports.go')
    local b_lines = { 'package main', '', 'var untouched = 1' }
    local expected_lines = vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports_golden.go')
    local expected = vim.fn.join(expected_lines, '\n')
    vim.fn.writefile(a_lines, a_name)
    vim.fn.writefile(b_lines, b_name)

    vim.cmd("silent exe 'e " .. a_name .. "'")
    require('go').setup({ goimports = 'goimports', gofmt = 'gofmt' })

    with_mocked_jobstart(function(_, opts)
      vim.defer_fn(function()
        opts.on_stdout(nil, vim.deepcopy(expected_lines), nil)
        opts.on_exit(nil, 0, nil)
      end, 50)
      return 1
    end, function()
      require('go.format').goimports()
      vim.cmd("silent exe 'e " .. b_name .. "'")

      local success = vim.wait(1000, function()
        return vim.fn.join(vim.fn.readfile(a_name), '\n') == expected
      end)

      eq(true, success)
      eq(expected, vim.fn.join(vim.fn.readfile(a_name), '\n'))
      eq(vim.fn.join(b_lines, '\n'), vim.fn.join(vim.fn.readfile(b_name), '\n'))
    end)

    vim.cmd('%bdelete!')
  end)
  it('should keep newer buffer edits when goimports output is stale', function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local a_name = dir .. '/a.go'
    local original_lines = vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports.go')
    local original = vim.fn.join(original_lines, '\n')
    local formatted_lines = vim.fn.readfile(cur_dir .. '/lua/tests/fixtures/fmt/goimports_golden.go')
    local notifications = {}
    vim.fn.writefile(original_lines, a_name)

    vim.cmd("silent exe 'e " .. a_name .. "'")
    require('go').setup({ goimports = 'goimports', gofmt = 'gofmt' })

    with_mocked_jobstart(function(_, opts)
      vim.defer_fn(function()
        opts.on_stdout(nil, vim.deepcopy(formatted_lines), nil)
        opts.on_exit(nil, 0, nil)
      end, 50)
      return 1
    end, function()
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      require('go.format').goimports()

      local bufnr = vim.api.nvim_get_current_buf()
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, { '// keep me' })

      local warned = vim.wait(1000, function()
        for _, notification in ipairs(notifications) do
          if notification.msg == 'buffer changed while goimports was running; output not applied' then
            return true
          end
        end
        return false
      end)

      eq(true, warned)
      eq(true, vim.bo[bufnr].modified)
      eq(original, vim.fn.join(vim.fn.readfile(a_name), '\n'))

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
      eq('// keep me', lines[#lines])
    end)

    vim.cmd('%bdelete!')
  end)
end)
