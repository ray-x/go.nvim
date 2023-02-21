-- run `go test`
local M = {}
local utils = require('go.utils')
local log = utils.log
-- local trace = utils.trace
local trace = log
local empty = utils.empty
local ginkgo = require('go.ginkgo')
local getopt = require('go.alt_getopt')
local install = require('go.install').install
local vfn = vim.fn

local long_opts = {
  verbose = 'v',
  compile = 'c',
  coverage = 'C',
  count = 'n',
  tags = 't',
  fuzz = 'f',
  bench = 'b',
  metric = 'm',
  select = 's',
  args = 'a',
  package = 'p',
  floaterm = 'F',
}

local sep = require('go.utils').sep()
local short_opts = 'a:cC:t:bsFmpn:v'
local bench_opts = { '-benchmem', '-cpuprofile', 'profile.out' }

M.efm = function()
  local indent = [[%\\%(    %\\)]]
  local efm = [[%-G=== RUN   %.%#]]
  efm = efm .. [[,%-G]] .. indent .. [[%#--- PASS: %.%#]]
  efm = efm .. [[,%G--- FAIL: %\\%(Example%\\)%\\@=%m (%.%#)]]
  efm = efm .. [[,%G]] .. indent .. [[%#--- FAIL: %m (%.%#)]]
  efm = efm .. [[,%A]] .. indent .. [[%\\+%[%^:]%\\+: %f:%l: %m]]
  efm = efm .. [[,%+Gpanic: test timed out after %.%\\+]]
  efm = efm .. ',%+Afatal error: %.%# [recovered]'
  efm = efm .. [[,%+Afatal error: %.%#]]
  efm = efm .. [[,%+Apanic: %.%#]]
  --
  -- -- exit
  efm = efm .. ',%-Cexit status %[0-9]%\\+'
  efm = efm .. ',exit status %[0-9]%\\+'
  -- -- failed lines
  efm = efm .. ',%-CFAIL%\\t%.%#'
  efm = efm .. ',FAIL%\\t%.%#'
  -- compiling error

  efm = efm .. ',%A%f:%l:%c: %m'
  efm = efm .. ',%A%f:%l: %m'
  efm = efm .. ',%f:%l +0x%[0-9A-Fa-f]%\\+' -- pannic with adress
  efm = efm .. ',%-G%\\t%\\f%\\+:%\\d%\\+ +0x%[0-9A-Fa-f]%\\+' -- test failure, address invalid inside
  -- multi-line
  efm = efm .. ',%+G%\\t%m'
  efm = efm .. ',%-C%.%#' -- ignore rest of unmatched lines
  efm = efm .. ',%-G%.%#'

  efm = string.gsub(efm, ' ', [[\ ]])
  -- log(efm)
  return efm
end

-- return "-tags=tag1,tag2"
M.get_build_tags = function(args, tbl)
  -- local tags = "-tags"
  args = args or {}
  local tags = {}
  if _GO_NVIM_CFG.build_tags ~= '' then
    tags = { _GO_NVIM_CFG.build_tags }
  end

  local optarg, _, reminder = getopt.get_opts(args, short_opts, long_opts)
  log('build tags', optarg, reminder)
  if optarg['t'] then
    table.insert(tags, optarg['t'])
  end

  local rt = utils.get_build_tags()
  if not utils.empty(rt) then
    vim.list_extend(tags, rt)
  end

  if #tags > 0 then
    if tbl then
      return { '-tags', table.concat(tags, ',') }, reminder, optarg
    end
    return '-tags=' .. table.concat(tags, ','), reminder, optarg
  end
  return
end

function M.get_test_path()
  local path = vim.fn.expand('%:p:h')
  local relative_path = vim.fn.fnamemodify(path, ':.')
  if path == relative_path then
    return path
  end
  return '.' .. sep .. relative_path
end

local function richgo(cmd)
  if cmd[1] == 'go' and vfn.executable('richgo') == 1 then
    cmd[1] = 'richgo'
  end
  return cmd
end

local function get_test_filebufnr()
  local fn = vfn.expand('%')
  trace(fn)

  local bufnr = vim.api.nvim_get_current_buf()
  if not fn:find('test%.go$') then
    fn = require('go.alternate').alternate()
    fn = vfn.fnamemodify(fn, ':p') -- expand to full path
    local uri = vim.uri_from_fname(fn)
    bufnr = vim.uri_to_bufnr(uri)
    log(fn, bufnr, uri)
    if vfn.filereadable(vim.uri_to_fname(uri)) == 0 then
      -- no test file existed
      return 0, 'no test file'
    end
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      vfn.bufload(bufnr)
    end
  end
  return bufnr
end

-- {-c: compile, -v: verbose, -t: tags, -b: bench, -s: select}
local function run_test(path, args)
  log(args)
  local compile = false
  local bench = false
  local extra_args = ''
  local optarg, oid, reminder = getopt.get_opts(args, short_opts, long_opts)
  trace(optarg, oid, reminder)
  if optarg['c'] then
    path = utils.rel_path(true) -- vfn.expand("%:p:h") can not resolve releative path
    compile = true
  end
  if optarg['b'] then
    bench = true
  end

  if optarg['a'] then
    extra_args = optarg['a']
  end

  if next(reminder) then
    path = reminder[1]
    table.remove(reminder, 1)
  end
  local test_runner = _GO_NVIM_CFG.go
  if _GO_NVIM_CFG.test_runner ~= test_runner then
    test_runner = _GO_NVIM_CFG.test_runner
    if not install(test_runner) then
      test_runner = 'go'
    end
  end

  local tags = M.get_build_tags(args)

  log(tags)
  local cmd = {}

  local run_in_floaterm = optarg['F'] or _GO_NVIM_CFG.run_in_floaterm
  if run_in_floaterm then
    table.insert(cmd, test_runner or 'go')
    table.insert(cmd, 'test')
  end

  if not empty(tags) then
    cmd = vim.list_extend(cmd, { tags })
  end

  if optarg['C'] then
    table.insert(cmd, '-C')
    table.insert(cmd, optarg['C'])
  end

  if optarg['n'] then
    table.insert(cmd, '-count=' .. optarg['n'] or '1')
  end

  if (optarg['v'] or _GO_NVIM_CFG.verbose_tests) and _GO_NVIM_CFG.test_runner == 'go' then
    table.insert(cmd, '-v')
  end
  if not empty(reminder) then
    cmd = vim.list_extend(cmd, reminder)
    log('****', reminder, cmd)
  end

  if compile == true then
    if path ~= '' then
      table.insert(cmd, '-c')
      table.insert(cmd, path)
    end
  elseif bench == true then
    if path ~= '' then
      table.insert(cmd, '-bench=' .. path)
    else
      table.insert(cmd, '-bench=.')
    end
    vim.list_extend(cmd, bench_opts)
  else
    if path ~= '' then
      table.insert(cmd, path)
    else
      local argsstr = '.' .. utils.sep() .. '...'
      table.insert(cmd, argsstr)
    end
  end

  if #extra_args > 0 then
    table.insert(cmd, '-a')
    table.insert(cmd, extra_args)
  end
  utils.log(cmd, args)
  if run_in_floaterm then
    install('richgo')
    local term = require('go.term').run
    cmd = richgo(cmd)
    log(cmd)
    term({ cmd = cmd, autoclose = false })
    return cmd
  end

  vim.cmd([[setl makeprg=]] .. _GO_NVIM_CFG.go .. [[\ test]])

  utils.log('test cmd', cmd)
  return require('go.asyncmake').make(unpack(cmd))
end

M.test = function(...)
  local args = { ... }
  log(args)

  local test_opts = {
    verbose = 'v',
    compile = 'c',
    coverage = 'C',
    tags = 't',
    bench = 'b',
    metrics = 'm',
    floaterm = 'F',
    nearest = 'n',
    file = 'f',
    args = 'a',
    package = 'p',
  }

  local test_short_opts = 'a:vcC:t:bsfmnpF'
  local optarg, _, reminder = getopt.get_opts(args, test_short_opts, test_opts)

  vfn.setqflist({})

  if optarg['n'] then --nearest
    optarg['n'] = nil
    local opts = getopt.rebuid_args(optarg, reminder) or {}
    return M.test_func(unpack(opts))
  end

  if optarg['f'] then -- currentfile
    optarg['f'] = nil
    local opts = getopt.rebuid_args(optarg, reminder) or {}
    return M.test_file(unpack(opts))
  end
  if optarg['p'] then -- current package
    optarg['p'] = nil
    local opts = getopt.rebuid_args(optarg, reminder) or {}
    return M.test_package(unpack(opts))
  end

  if optarg['a'] then -- current package
    log('args', optarg['a'])
  end
  local workfolder = utils.work_path()
  if workfolder == nil then
    workfolder = '.'
  end

  local fpath = workfolder .. utils.sep() .. '...'

  if #reminder > 0 then
    fpath = reminder[1]
  end

  utils.log('fpath :' .. fpath)
  run_test(fpath, args)
end

M.test_suit = function(...)
  local args = { ... }
  log(args)

  local workfolder = utils.work_path()
  utils.log(args)
  local fpath = workfolder .. utils.sep() .. '...'

  utils.log('fpath' .. fpath)

  run_test(fpath, args)
end

M.test_package = function(...)
  local args = { ... }
  log(args)
  local fpath = M.get_test_path() .. sep .. '...'
  utils.log('fpath: ' .. fpath)
  return run_test(fpath, args)
end

M.get_test_func_name = function()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  local ns = require('go.ts.go').get_func_method_node_at_pos()
  if empty(ns) then
    return nil
  end
  if ns == nil or ns.name == nil then
    return nil
  end
  if not string.find(ns.name, '[T|t]est') then
    -- not in a test function
    local fns = M.get_testfunc()
    for _, fn in ipairs(fns) do
      log(fn, ns.name)
      if string.find(fn:lower(), ns.name:lower()) then
        ns = { name = fn }
        return ns
      end
    end
  end
  return ns
end

M.get_testcase_name = function()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  local ns = require('go.ts.go').get_testcase_node()
  if empty(ns) then
    return nil
  end
  if ns == nil or ns.name == nil then
    return nil
  end
  return ns
end

local function run_tests_with_ts_node(args, func_node, tblcase_ns)
  local optarg, _, reminder = getopt.get_opts(args, short_opts, long_opts)
  local tags = M.get_build_tags(args)
  utils.log('tags: ', tags)
  utils.log('parnode' .. vim.inspect(func_node))

  local test_runner = _GO_NVIM_CFG.test_runner or 'go'

  if test_runner ~= 'go' then
    if not install(test_runner) then
      test_runner = 'go'
    end
    if test_runner == 'ginkgo' then
      ginkgo.test_func(unpack(args))
    end
  end

  local run_flags = '-r'

  local cmd = {}
  local run_in_floaterm = optarg['F'] or _GO_NVIM_CFG.run_in_floaterm
  if run_in_floaterm then
    table.insert(cmd, test_runner)
    table.insert(cmd, 'test')
  end

  if optarg['s'] then
    return M.select_tests()
  end
  if (optarg['v'] or _GO_NVIM_CFG.verbose_tests) and _GO_NVIM_CFG.test_runner == 'go' then
    table.insert(cmd, '-v')
  end

  if tags and tags ~= '' then
    table.insert(cmd, tags)
  end
  if func_node == nil or func_node.name == nil then
    return
  end

  if optarg['n'] then
    table.insert(cmd, '-n')
    table.insert(cmd, (optarg['n'] or '1'))
  end

  if optarg['C'] then
    table.insert(cmd, '-C')
    table.insert(cmd, optarg['C'])
  end
  local tbl_name = ''
  if tblcase_ns and tblcase_ns.name then
    tbl_name = tblcase_ns.name:gsub('/', '//')
    tbl_name = tbl_name:gsub('%(', '\\(')
    tbl_name = tbl_name:gsub('%)', '\\)')
    tbl_name = '/' .. tbl_name
  end

  if func_node.name:find('Bench') then
    local bench = '-bench=' .. func_node.name .. tbl_name
    table.insert(cmd, bench)
    vim.list_extend(cmd, bench_opts)
  elseif func_node.name:find('Fuzz') then
    table.insert(cmd, '-fuzz')
    table.insert(cmd, func_node.name)
  else
    table.insert(cmd, run_flags)
    table.insert(cmd, [['^]] .. func_node.name .. [[$']] .. tbl_name)
  end

  local fpath = M.get_test_path()
  table.insert(cmd, fpath)

  if optarg['a'] then
    table.insert(cmd, '-a')
    table.insert(cmd, optarg['a'])
  end

  if test_runner == 'dlv' then
    local runflag = string.format("-test.run='^%s$'%s", func_node.name, tbl_name)
    if tags and #tags > 0 then
      cmd = { 'dlv', 'test', fpath, '--build-flags', tags, '--', runflag }
    else
      cmd = { 'dlv', 'test', fpath, '--', runflag }
    end
    log(cmd)
    local term = require('go.term').run
    term({ cmd = cmd, autoclose = false })
    return
  end

  if run_in_floaterm then
    utils.log(cmd)
    install('richgo')
    local term = require('go.term').run
    cmd = richgo(cmd)
    term({ cmd = cmd, autoclose = false })
    return
  end
  vim.list_extend(cmd, reminder)

  vim.cmd([[setl makeprg=]] .. test_runner .. [[\ test]])
  -- set_efm()
  utils.log('test cmd', cmd)

  return require('go.asyncmake').make(unpack(cmd))
end

--options {s:select, F: floaterm}
M.test_func = function(...)
  local args = { ... } or {}
  log(args)

  local ns = M.get_test_func_name()
  if empty(ns) then
    return M.select_tests()
  end

  local parser_path = vim.api.nvim_get_runtime_file('parser' .. sep .. 'go.so', false)[1]
  if not parser_path then
    --   require('nvim-treesitter.install').commands.TSInstallSync['run!']('go')
    vim.notify('go treesitter parser not found, please Run `:TSInstallSync go`', vim.log.levels.WARN)
  end
  return run_tests_with_ts_node(args, ns)
end

--options {s:select, F: floaterm}
M.test_tblcase = function(...)
  local args = { ... }
  log(args)

  local ns = M.get_test_func_name()
  if empty(ns) then
    vim.notify('put cursor on test case name string')
  end

  local tblcase_ns = M.get_testcase_name()
  if empty(tblcase_ns) then
    vim.notify('put cursor on test case name string')
  end
  return run_tests_with_ts_node(args, ns, tblcase_ns)
end

M.get_test_cases = function()
  local fpath = '.' .. sep .. vfn.fnamemodify(vfn.expand('%:p'), ':.')
  local is_test = fpath:find('_test%.go$')
  if not is_test then
    fpath = '.' .. sep .. vfn.fnamemodify(vfn.expand('%:p'), ':.:r') .. '_test.go'
  end
  -- utils.log(args)
  local tests = M.get_testfunc()
  if not tests then
    local cmd = [[cat ]] .. fpath .. [[| sed -n 's/func\s\+\(Test.*\)(.*/\1/p' | xargs | sed 's/ /\\|/g']]
    -- TODO maybe with treesitter or lsp list all functions in current file and regex with Test
    if vfn.executable('sed') == 0 then
      return
    end

    local tests = vfn.systemlist(cmd)
    if vim.v.shell_error ~= 0 then
      utils.warn('go test failed' .. vim.inspect(tests))
      return
    end
    return tests[1]
  end
  local sep = '|'
  local testsstr = vim.fn.join(tests, sep)
  utils.log(tests, testsstr)
  return testsstr, tests
end

M.test_file = function(...)
  local args = { ... }
  log(args)

  -- require sed
  local tests = M.get_test_cases()
  if not tests then
    vim.notify('no test found fallback to package test', vim.log.levels.DEBUG)
    return M.test_package(...)
  end

  local optarg, _, reminder = getopt.get_opts(args, short_opts, long_opts)

  local run_in_floaterm = optarg['F'] or _GO_NVIM_CFG.run_in_floaterm

  if vfn.empty(tests) == 1 then
    vim.notify('no test found fallback to package test', vim.log.levels.DEBUG)
    M.test_package(...)
    return
  end

  local tags = M.get_build_tags(args)

  local test_runner = _GO_NVIM_CFG.go
  if _GO_NVIM_CFG.test_runner ~= 'go' then
    test_runner = _GO_NVIM_CFG.test_runner
    if not install(test_runner) then
      test_runner = 'go'
    end
    if test_runner == 'ginkgo' then
      ginkgo.test_func(...)
    end
  end

  local relpath = utils.rel_path(true)
  log(relpath)

  local cmd_args = {}
  if run_in_floaterm then
    table.insert(cmd_args, test_runner)
    table.insert(cmd_args, 'test')
  end

  if (optarg['v'] or _GO_NVIM_CFG.verbose_tests) and _GO_NVIM_CFG.test_runner == 'go' then
    table.insert(cmd_args, '-v')
  end

  if tags ~= nil then
    table.insert(cmd_args, tags)
  end

  if next(reminder) then
    vim.list_extend(cmd_args, reminder)
  end
  if optarg['n'] then
    table.insert(cmd_args, '-n')
    table.insert(cmd_args, optarg['n'] or '1')
  end

  if optarg['C'] then
    table.insert(cmd_args, '-C')
    table.insert(cmd_args, optarg['C'])
  end
  table.insert(cmd_args, '-r')

  tests = "'" .. tests .. "'"
  table.insert(cmd_args, tests) -- shell script | is a pipe
  table.insert(cmd_args, relpath)

  if run_in_floaterm then
    install('richgo')
    local term = require('go.term').run
    cmd_args = richgo(cmd_args)
    cmd_args = table.concat(cmd_args, ' ')
    log(cmd_args)
    term({ cmd = cmd_args, autoclose = false })
    return cmd_args
  end

  if _GO_NVIM_CFG.test_runner == 'dlv' then
    cmd_args = { 'dlv', 'test', relpath, '--', '-test.run', tests }
    cmd_args = table.concat(cmd_args, ' ')
    local term = require('go.term').run
    term({ cmd = cmd_args, autoclose = false })
    return cmd_args
  end

  vim.cmd([[setl makeprg=]] .. _GO_NVIM_CFG.go .. [[\ test]])
  log(cmd_args)

  local cmdret = require('go.asyncmake').make(unpack(cmd_args))

  utils.log('test cmd: ', cmdret, ' finished')
  return cmdret
end

-- TS based run func
-- https://github.com/rentziass/dotfiles/blob/master/vim/.config/nvim/lua/rentziass/lsp/go_tests.lua
M.run_file = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local tree = vim.treesitter.get_parser(bufnr):parse()[1]
  local query = vim.treesitter.parse_query('go', require('go.ts.textobjects').query_test_func)

  local test_names = {}
  for id, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
    local name = query.captures[id] -- name of the capture in the query
    if name == 'test_name' then
      table.insert(test_names, vim.treesitter.query.get_node_text(node, bufnr))
    end
  end

  vim.schedule(function()
    vim.lsp.buf.execute_command({
      command = 'gopls.run_tests',
      arguments = { { URI = vim.uri_from_bufnr(0), Tests = test_names } },
    })
  end)
end

M.get_testfunc = function()
  local bufnr = get_test_filebufnr()

  -- Note: the buffer may not be loaded yet
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return end
  local tree = parser:parse()
  tree = tree[1]
  local query = vim.treesitter.parse_query('go', require('go.ts.go').query_test_func)

  local test_names = {}
  for id, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
    local name = query.captures[id] -- name of the capture in the query
    if name == 'test_name' then
      table.insert(test_names, vim.treesitter.query.get_node_text(node, bufnr))
    end
  end

  return test_names
end

-- GUI to select test?
M.select_tests = function()
  local guihua = utils.load_plugin('guihua.lua', 'guihua.gui')
  local original_select = vim.ui.select

  if guihua then
    vim.ui.select = require('guihua.gui').select
  end

  vim.defer_fn(function()
    vim.ui.select = original_select
  end, 500)

  local function onselect(item, idx)
    if not item then
      return
    end
    local uri = vim.uri_from_bufnr(0)
    log(uri, item, idx)
    vim.schedule(function()
      vim.lsp.buf.execute_command({
        command = 'gopls.run_tests',
        arguments = { { URI = uri, Tests = { item } } },
      })
    end)
  end
  local test_names = M.get_testfunc()
  vim.ui.select(test_names, {
    prompt = 'select test to run:',
    kind = 'codelensaction',
  }, onselect)
  return test_names
end

return M
