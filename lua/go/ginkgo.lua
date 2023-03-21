-- gonkgo test
local M = {}
local utils = require('go.utils')
local log = utils.log
local vfn = vim.fn
local long_opts = {
  verbose = 'v',
  compile = 'c',
  tags = 't',
  bench = 'b',
  select = 's',
  floaterm = 'F',
}

local getopt = require('go.alt_getopt')
local short_opts = 'vct:bsF'

local function get_build_tags(args)
  local tags = {}

  local optarg = getopt.get_opts(args, short_opts, long_opts)
  if optarg['t'] then
    table.insert(tags, optarg['t'])
  end

  if _GO_NVIM_CFG.build_tags ~= '' then
    table.insert(tags, _GO_NVIM_CFG.build_tags)
  end

  if #tags == 0 then
    return ''
  end

  return [[-tags=]] .. table.concat(tags, ',')
end

local function find_describe(lines)
  local describe
  local pat = [[Describe%(%".*%",%sfunc]]
  local despat = [[%(%".*%"]]
  for i = #lines, 1, -1 do
    local line = lines[i]
    local fs, fe = string.find(line, pat)
    if fs then
      line = string.sub(line, fs + #'Describe', fe)
      fs, fe = string.find(line, despat)
      if fs ~= nil then
        if fe - fs <= 2 then
          return nil
        end
        describe = line:sub(fs + 2, fe - 1)
        return describe
      end
    end
  end

  -- It
  pat = [[It%(%".*%",%sfunc]]
  for i = #lines, 1, -1 do
    local line = lines[i]
    local fs, fe = string.find(line, pat)
    if fs then
      line = string.sub(line, fs + #'It', fe)
      fs, fe = string.find(line, despat)
      if fs ~= nil then
        if fe - fs <= 2 then
          return nil
        end
        describe = line:sub(fs + 2, fe - 1)
        return describe
      end
    end
  end

  pat = [[Context%(%".*%",%sfunc]]
  for i = #lines, 1, -1 do
    local line = lines[i]
    local fs, fe = string.find(line, pat)
    if fs then
      line = string.sub(line, fs + #'Context', fe)
      fs, fe = string.find(line, despat)
      if fs ~= nil then
        if fe - fs <= 2 then
          return nil
        end
        describe = line:sub(fs + 2, fe - 1)
        return describe
      end
    end
  end
  return nil
end

-- print(find_describe({
--   [[ var _ = Describe("Integration test hourly data EstimateCombinedRules without ws ID", func() { ]]
-- }))

-- Run with ginkgo Description
M.test_func = function(...)
  local args = ...
  log(args)
  local optarg = {}
  local fpath = vfn.expand('%:p:h')

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1

  local fnum = row - 60
  if fnum < 0 then
    fnum = 0
  end
  local lines = vim.api.nvim_buf_get_lines(0, fnum, row + 1, true)

  local describe = find_describe(lines)
  if describe == nil then
    log('failed to find test function, test file instead', args)
    log(unpack(args))
    return M.test_file(unpack(args))
  end
  local test_runner = 'ginkgo'
  require('go.install').install(test_runner)

  -- local type_patterns = {
  --   'function',
  --   'method',
  --   'type_spec',
  --   'call_expression',
  -- }
  --
  -- local f = require('nvim-treesitter').statusline({
  --   indicator_size = 400,
  --   type_patterns = type_patterns,
  -- })
  -- local ctx = vim.split(f, '->')
  -- -- find describe
  -- log(ctx)
  --
  -- local cmd = { test_runner, [[ --focus=']] .. describe .. [[']], get_build_tags(args), fpath }
  local cmd = { test_runner, [[ --focus=']] .. describe .. [[']], get_build_tags(args), fpath }
  log(cmd)
  if _GO_NVIM_CFG.run_in_floaterm then
    local term = require('go.term').run
    term({ cmd = cmd, autoclose = false })
    return
  end
  cmd = [[setl makeprg=]] .. test_runner
  vim.cmd(cmd)

  args = { [[ --focus=']] .. describe .. [[']], get_build_tags(args), fpath }
  require('go.asyncmake').make(unpack(args))
  utils.log('test cmd', cmd)
  return true
end

M.test_file = function(...)
  local args =  ... 
  log(args)
  -- require sed
  local fpath = vfn.expand('%:p:h')
  local fname = vfn.expand('%:p')

  log(fpath, fname)

  local workfolder = utils.work_path()
  fname = '.' .. fname:sub(#workfolder + 1)

  log(workfolder, fname)
  local test_runner = 'ginkgo'
  require('go.install').install(test_runner)

  local cmd_args = {
    -- [[--regexScansFilePath=true]], v1
    get_build_tags(args),
    [[ --focus-file= ]],
    fname,
    fpath,
  }

  if _GO_NVIM_CFG.run_in_floaterm then
    table.insert(cmd_args, 1, test_runner)
    utils.log(args)
    local term = require('go.term').run
    term({ cmd = cmd_args, autoclose = false })
    return
  end

  fname = utils.relative_to_cwd(fname) .. [[\ ]]
  vim.cmd('setl makeprg=ginkgo')
  utils.log('test cmd', cmd_args)
  require('go.asyncmake').make(unpack(cmd_args))
end

M.run = function(opts)
  local test_runner = 'ginkgo'
  require('go.install').install(test_runner)
  local cmd = { test_runner }

  local cwd
  local args = {}

  if opts[1] then
    cmd = { test_runner, opts[1] }
    if opts[1] == 'bootstrap' then
      if not opts[2] then
        cwd = vim.fn.expand('%:p:h')
        args = { cwd = cwd }
      end
    end
    if opts[2] then
      cmd = { test_runner, opts[1], opts[2] }
    end
  end
  cwd = vim.fn.expand('%:p:h')
  local runner = require('go.runner')
  runner.run(cmd, {}, args)
end

return M
