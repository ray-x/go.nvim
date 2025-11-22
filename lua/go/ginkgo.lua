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
local ts = vim.treesitter

local parsers
if _GO_NVIM_CFG.treesitter_main then
  parsers = require('guihua.ts_obsolete.parsers')
else
  parsers = require('nvim-treesitter.parsers')
end

local getopt = require('go.alt_getopt')
local short_opts = 'vct:bsF'

local function get_build_tags(args)
  if not args then
    return ''
  end
  local tags = {}

  if not vim.tbl_isempty(args) then
    local optarg = getopt.get_opts(args, short_opts, long_opts)
    if optarg['t'] then
      table.insert(tags, optarg['t'])
    end
  end
  if _GO_NVIM_CFG.build_tags ~= '' then
    table.insert(tags, _GO_NVIM_CFG.build_tags)
  end

  if #tags == 0 then
    return ''
  end

  return [[-tags=]] .. table.concat(tags, ',')
end

local function find_nearest_test_case()
  local query = require('go.ts.go').ginkgo_query

  local bufnr = vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufnr, 'go')
  if not parser then
    log('no parser found')
    return
  end
  local root = parser:parse()[1]:root()

  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
  cursor_row = cursor_row - 1

  local tst_query = ts.query.parse('go', query)
  local nearest_name, nearest_dist = nil, math.huge
  local in_range = require('go.ts.go').is_position_in_node

  local prev_test_name
  -- assume the node are ordered by row
  for id, node, _ in tst_query:iter_captures(root, bufnr, 0, -1) do
    local row, col, erow, ecol = node:range()
    -- check if cursor is inside the test case range
    if tst_query.captures[id] == 'test_body' and in_range(node, cursor_row, cursor_col) then
      local dist = cursor_row - row
      if dist <= nearest_dist then
        nearest_dist = dist
        nearest_name = prev_test_name
      end
      log('cursor is inside test case', dist, nearest_dist, nearest_name)
    end

    if tst_query.captures[id] == 'test_name' then
      local name = ts.get_node_text(node, bufnr)
      -- if cursor on the test name
      if in_range(node, cursor_row, cursor_col) then
        log('cursor is inside test name', name)
        return name
      end
      if row <= cursor_row then
        local dist = cursor_row - row
        if dist <= nearest_dist then
          prev_test_name = name
          nearest_dist = cursor_row - row
        end
      end
    end
  end
  if nearest_name then
    log('nearest test case: ' .. nearest_name)
    return nearest_name
  else
    log('no test case found')
  end
end

-- print(find_describe({
--   [[ var _ = Describe("Integration test hourly data EstimateCombinedRules without ws ID", func() { ]]
-- }))

-- Run with ginkgo Description
M.test_func = function(...)
  local args = ... or {}
  log(args)
  local fpath = vfn.expand('%:p:h')

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1

  local fnum = row - 60
  if fnum < 0 then
    fnum = 0
  end

  local describe
  local ts_nearest_test_case = find_nearest_test_case()
  if ts_nearest_test_case then
    describe = ts_nearest_test_case
  else
    return M.test_file(unpack(args))
  end
  local test_runner = 'ginkgo'
  require('go.install').install(test_runner)

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
  local args = ...
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

M.is_ginkgo_file = function()
  -- read first 50 lines(if >50lines) and search for "github.com/onsi/ginkgo/v2"

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 50, false)
  for _, line in ipairs(lines) do
    if line:find('github.com/onsi/ginkgo/v2') then
      return true
    end
  end
end

return M
