local utils = require('go.utils')
local log = utils.log
local coverage = {}
local api = vim.api
local vfn = vim.fn
local empty = utils.empty
local M = {}
local visible = false
-- _GO_NVIM_CFG = _GO_NVIM_CFG or {}
local sign_define_cache = {}

M.sign_map = { covered = 'goCoverageCovered', uncover = 'goCoverageUncovered', partial = 'goCoveragePartial' }

local ns = 'gocoverage_ns'

local function sign_get(bufnr, name)
  if sign_define_cache[bufnr] == nil then
    sign_define_cache[bufnr] = {}
  end
  if not sign_define_cache[bufnr][name] then
    local s = vfn.sign_getdefined(name)
    if not vim.tbl_isempty(s) then
      sign_define_cache[bufnr][name] = s
    end
  end
  return sign_define_cache[bufnr][name]
end

-- all windows and buffers
local function all_bufnr()
  local bufnrl = {}
  local buffers = vfn.getbufinfo({ bufloaded = 1, buflisted = 1 })

  for _, b in pairs(buffers) do
    if not (vfn.empty(b.name) == 1 or b.hidden == 1) then
      local name = b.name

      local ext = string.sub(name, #name - 2)
      if ext == '.go' then
        table.insert(bufnrl, b.bufnr)
      end
    end
  end
  return bufnrl
end -- log(bufnr, name, opts, redefine)

function M.define(bufnr, name, opts, redefine)
  if sign_define_cache[bufnr] == nil then
    sign_define_cache[bufnr] = {}
  end
  -- vim.notify(bufnr .. name .. opts .. redefine, vim.lsp.log_levels.DEBUG)
  if redefine then
    sign_define_cache[bufnr][name] = nil
    vfn.sign_undefine(name)
    vfn.sign_define(name, opts)
  elseif not sign_get(name) then
    -- log("define sign", name, vim.inspect(opts))
    vfn.sign_define(name, opts)
  end
  -- vim.cmd([[sign list]])
end

function M.remove(bufnr, lnum)
  if bufnr == nil then
    bufnr = vfn.bufnr('$')
  end
  vfn.sign_unplace(ns, { buffer = bufnr, id = lnum })
end

function M.remove_all()
  local bufnrs = all_bufnr()
  for _, bid in pairs(bufnrs) do
    M.remove(bid)
  end
end

function M.add(bufnr, signs)
  local to_place = {}
  local placed = {}
  for _, s in ipairs(signs or {}) do
    local covered = s.covered
    local sign_name = 'goCoverageCovered'
    if covered == 0 then
      sign_name = 'goCoverageUncovered'
    end

    M.define(bufnr, sign_name, { text = _GO_NVIM_CFG.gocoverage_sign, texthl = sign_name })
    for lnum = s.range.start.line, s.range['end'].line do
      local sg = sign_name
      if placed[lnum] and (placed[lnum] == 'goCoverageUncovered' or sign_name == 'goCoverageUncovered') then
        sg = 'goCoveragePartial'
      end

      if lnum == s.range.start.line then
        local start_ch = s.range.start.character
        local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
        if line and start_ch >= line:len() - 1 and placed[lnum] then
          log(start)
          log(lnum, covered, sign_name, bufnr) --verbose
          sg = placed[lnum]
        end
      end
      if (covered == 1 and not _GO_NVIM_CFG.gocoverage_skip_covered) or covered == 0 then
        to_place[#to_place + 1] = {
          id = lnum,
          group = ns,
          name = sg,
          buffer = bufnr,
          lnum = lnum,
          priority = _GO_NVIM_CFG.sign_priority,
        }
      end

      ::continue::
      placed[lnum] = sg
    end
  end

  log('placing', #to_place)
  vfn.sign_placelist(to_place)
  return to_place -- for testing
end

M.highlight = function()
  for _, sign_name in pairs(M.sign_map) do
    if vim.tbl_isempty(vfn.sign_getdefined(sign_name)) then
      vfn.sign_define(sign_name, {
        text = _GO_NVIM_CFG.gocoverage_sign,
        texthl = sign_name,
      })
    end
  end

  vim.api.nvim_set_hl(0, 'goCoverageCovered', { link = _GO_NVIM_CFG.sign_covered_hl, default = true })
  vim.api.nvim_set_hl(0, 'goCoveragePartial', { link = _GO_NVIM_CFG.sign_partial_hl, default = true })
  vim.api.nvim_set_hl(0, 'goCoverageUncovered', { link = _GO_NVIM_CFG.sign_uncovered_hl, default = true })
end

local function enable_all()
  local bufnrs = all_bufnr()
  for _, bufnr in pairs(bufnrs) do
    local fn = vfn.bufname(bufnr)
    if coverage[fn] ~= nil then
      M.add(bufnr, coverage[fn])
    end
  end
end
local function augroup()
  local aug = vim.api.nvim_create_augroup('gonvim__coverage', {})
  local pat = { '*.go', '*.mod' }
  vim.api.nvim_create_autocmd({ 'ColorScheme' }, {
    group = aug,
    pattern = pat,
    callback = function()
      require('go.coverage').highlight()
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufWinLeave' }, {
    group = aug,
    pattern = pat,
    callback = function()
      require('go.coverage').remove()
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufWinEnter' }, {
    group = aug,
    pattern = pat,
    callback = function()
      enable_all()
    end,
  })
end

M.toggle = function(show)
  if (show == nil and visible == true) or show == false then
    -- hide
    log('toggle remove coverage')
    visible = false
    return M.remove_all()
  end

  local pwd = vfn.getcwd()
  local cov = pwd .. utils.sep() .. 'cover.cov'

  M.read_cov(cov)
  visible = true
  enable_all()
  -- end
end

local function parse_line(line)
  local m = vfn.matchlist(line, [[\v([^:]+):(\d+)\.(\d+),(\d+)\.(\d+) (\d+) (\d+)]])

  if empty(m) then
    return {}
  end
  local path = m[2]
  local filename = vfn.fnamemodify(m[2], ':t')
  return {
    file = path,
    filename = filename,
    range = {
      start = { line = tonumber(m[3]), character = tonumber(m[4]) },
      ['end'] = { line = tonumber(m[5]), character = tonumber(m[6]) },
    },
    num = tonumber(m[7]),
    covered = tonumber(m[8]),
  }
end

M.read_cov = function(covfn)
  local total_lines = 0
  local total_covered = 0

  if vfn.filereadable(covfn) == 0 then
    vim.notify(string.format('cov file %s not exist please run cover test first', covfn), vim.lsp.log_levels.WARN)
    return
  end
  local cov = vfn.readfile(covfn)
  -- log(vim.inspect(cov))
  for _, line in pairs(cov) do
    local cl = parse_line(line)
    local file_lines = 0
    if cl.filename ~= nil or cl.range ~= nil then
      total_lines = total_lines + cl.num
      if coverage[cl.filename] == nil then
        coverage[cl.filename] = {}
      end
      coverage[cl.filename].file_lines = (coverage[cl.filename].file_lines or 0) + cl.num
      file_lines = file_lines + cl.num
      if cl.covered > 0 then
        coverage[cl.filename].file_covered = (coverage[cl.filename].file_covered or 0) + cl.num
        total_covered = total_covered + cl.num
      end
      table.insert(coverage[cl.filename], cl)
    end
  end

  coverage.total_lines = total_lines
  coverage.total_covered = total_covered
  local bufnrs = all_bufnr()
  log('buffers', bufnrs)
  -- local added = {} --cache?
  for _, bid in pairs(bufnrs) do
    -- if added[bid] == nil then
    local fn = vfn.bufname(bid)
    fn = vfn.fnamemodify(fn, ':t')
    log(bid, fn)
    M.add(bid, coverage[fn])
    visible = true
    -- added[bid] = true
    -- end
  end
  return coverage
end

M.show_func = function()
  local setup = { 'go', 'tool', 'cover', '-func=cover.cov' }
  local result = {}
  vfn.jobstart(setup, {
    on_stdout = function(_, data, _)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      for _, val in ipairs(data) do
        -- first strip the filename
        local l = vim.fn.split(val, ':')
        local fname = l[1]
        if vim.fn.filereadable(fname) == 0 then
          local parts = vim.fn.split(fname, utils.sep())
          for _ = 1, #parts do
            table.remove(parts, 1)
            fname = vim.fn.join(parts, utils.sep())
            log('fname', fname)
            if vim.fn.filereadable(fname) == 1 then
              l[1] = fname
              local d = vim.fn.join(l, ':')
              log('putback ', d)
              val = d
            end
          end
        end
        table.insert(result, val)
      end
    end,
    on_exit = function(_, data, _)
      if data ~= 0 then
        vim.notify('no coverage data', vim.lsp.log_levels.WARN)
        return
      end
      vim.fn.setqflist({}, ' ', {
        title = 'go coverage',
        lines = result,
      })

      utils.quickfix('copen')
    end,
  })
end

M.run = function(...)
  local get_build_tags = require('go.gotest').get_build_tags
  -- local cov = vfn.tempname()
  local pwd = vfn.getcwd()
  local cov = pwd .. utils.sep() .. 'cover.cov'

  local args = { ... }
  log(args)

  local arg = select(1, ...)
  if arg == '-m' then
    -- show the func metric
    if vim.fn.filereadable(cov) == 1 then
      return M.show_func()
    end
    log(cov .. ' not exist')
    table.remove(args, 1)
  end
  if arg == '-f' then
    local covfn = select(2, ...) or cov
    table.remove(args, 1)
    if vim.fn.filereadable(covfn) == 0 then
      vim.notify('no cov file specified or existed, will rerun coverage test', vim.lsp.log_levels.INFO)
    else
      table.remove(args, 1)
      local test_coverage = M.read_cov(covfn)
      vim.notify(string.format('total coverage: %d%%', test_coverage.total_covered / test_coverage.total_lines * 100))
      return test_coverage
    end
    arg = select(2, ...)
  end
  if arg == '-t' and #args < 2 then -- if only -t provided
    return M.toggle()
  end

  local float = false
  if args[1] == '-F' then
    table.remove(args, 1)
    arg = args[1]
    float = true
  end
  if arg == '-r' then
    return M.remove()
  end

  if arg == '-R' then
    return M.remove_all()
  end
  local test_runner = 'go'
  if _GO_NVIM_CFG.test_runner ~= 'go' then
    test_runner = _GO_NVIM_CFG.test_runner
    require('go.install').install(test_runner)
  end

  local cmd = { test_runner, 'test', '-coverprofile', cov }
  local tags
  if not empty(args) then
    tags = get_build_tags(args)
    if tags ~= nil then
      table.insert(cmd, tags)
      table.remove(args, 2)
    end
  end

  -- log(args)
  -- cmd = vim.list_extend(cmd, args)
  local argsstr

  arg = args[1]

  log(arg, args)
  if arg == '-p' then
    log('extend pkg')
    table.remove(args, 1)
    local pkg = require('go.package').pkg_from_path(nil, vim.api.nvim_get_current_buf())
    if vfn.empty(pkg) == 1 then
      vim.notify('No package found in current directory.')
      argsstr = ''
    else
      argsstr = pkg[1]
    end
  else
    argsstr = '.' .. utils.sep() .. '...'
  end

  table.insert(cmd, argsstr)

  if not empty(args) then
    log(args)
    cmd = vim.list_extend(cmd, args)
  end

  local lines = { '' }
  coverage = {}

  if _GO_NVIM_CFG.run_in_floaterm or float then
    local cmd_str = table.concat(cmd, ' ')
    if empty(args) then
      cmd_str = cmd_str .. '.' .. utils.sep() .. '...'
    end
    utils.log(cmd_str)
    local term = require('go.term').run
    term({ cmd = cmd_str, autoclose = false })
    return
  end

  local cmd_str = table.concat(cmd, ' ')
  log(cmd_str)
  vfn.jobstart(cmd_str, {
    on_stdout = function(jobid, data, event)
      log('go coverage ' .. vim.inspect(data), jobid, event)
      vim.list_extend(lines, data)
    end,
    on_stderr = function(job_id, data, event)
      data = utils.handle_job_data(data)
      if data == nil then
        return
      end
      if data[1] == 'no test files' then
        vim.notify(data[1], vim.lsp.log_levels.WARN)
        return
      end

      if string.find(data[1], 'warning: no packages being tested') then
        return
      end

      vim.notify(
        'go coverage finished with message: '
          .. vim.inspect(cmd)
          .. 'error: '
          .. vim.inspect(data)
          .. '\n'
          .. 'job '
          .. tostring(job_id)
          .. '\n'
          .. 'ev '
          .. event,
        vim.lsp.log_levels.WARN
      )
    end,
    on_exit = function(job_id, data, event)
      if event ~= 'exit' then
        vim.notify(string.format('%s %s %s', job_id, event, vim.inspect(data)), vim.lsp.log_levels.ERROR)
      end

      local lp = table.concat(lines, '\n')
      vim.notify(string.format('test finished:\n %s', lp), vim.lsp.log_levels.INFO)
      coverage = M.read_cov(cov)
      if arg == '-m' then
        M.toggle(true)
        return M.show_func()
      end
      vfn.setqflist({}, ' ', {
        title = cmd,
        lines = lines,
        efm = vim.o.efm .. [[,]] .. require('go.gotest').efm(),
      })
      api.nvim_command('doautocmd QuickFixCmdPost')
      -- vfn.delete(cov) -- maybe keep the file for other commands
    end,
  })
end

M.setup = function()
  M.highlight()
  augroup()
end

return M
