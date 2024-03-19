local api = vim.api
local utils = require('go.utils')
local log = utils.log
local max_len = _GO_NVIM_CFG.max_line_len or 128
local vfn = vim.fn

local install = require('go.install').install

local goimport_args = _GO_NVIM_CFG.goimport_args
  or {
    '--max-len=' .. tostring(max_len),
    '--base-formatter=goimports',
  }

local M = {}

M.lsp_format = function()
  -- vim.lsp.buf.format({
  vim.lsp.buf.format({
    async = _GO_NVIM_CFG.lsp_fmt_async,
    bufnr = vim.api.nvim_get_current_buf(),
    name = 'gopls',
  })
  if not _GO_NVIM_CFG.lsp_fmt_async then
    if vfn.getbufinfo('%')[1].changed == 1 then
      vim.cmd('noautocmd write')
    end
  end
  -- otherwise use the format handler
end

local run = function(fmtargs, bufnr, cmd)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  cmd = cmd or _GO_NVIM_CFG.gofmt or 'gofumpt'
  log(fmtargs, bufnr, cmd)
  if cmd == 'gopls' then
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      vfn.bufload(bufnr)
    end
    -- gopls format
    return M.lsp_format()
  end

  -- for none lsp format we need to check if the buffer is modified and save to disk first
  if vim.o.mod == true then
    vim.cmd('noautocmd write')
  end
  local args = vim.deepcopy(fmtargs)
  table.insert(args, api.nvim_buf_get_name(bufnr))
  log('formatting buffer... ' .. vim.inspect(args), vim.log.levels.DEBUG)

  local old_lines = api.nvim_buf_get_lines(0, 0, -1, true)
  table.insert(args, 1, cmd)
  log('fmt cmd:', args)

  local j = vfn.jobstart(args, {
    on_stdout = function(_, data, _)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      if not utils.check_same(old_lines, data) then
        vim.notify('updating codes', vim.log.levels.DEBUG)
        api.nvim_buf_set_lines(0, 0, -1, false, data)
        vim.cmd('write')
      else
        vim.notify('already formatted', vim.log.levels.DEBUG)
      end
      -- log("stdout" .. vim.inspect(data))
      old_lines = nil
    end,
    on_stderr = function(_, data, _)
      data = utils.handle_job_data(data)
      if data then
        log(vim.inspect(data) .. ' from stderr')
      end
    end,
    on_exit = function(_, data, _) -- id, data, event
      -- log(vim.inspect(data) .. "exit")
      if data ~= 0 then
        return vim.notify(cmd .. ' failed ' .. tostring(data), vim.log.levels.ERROR)
      end
      old_lines = nil
      vim.defer_fn(function()
        if cmd == 'goimports' then
          return M.lsp_format()
        end
        if vfn.getbufinfo('%')[1].changed == 1 then
          vim.cmd('noautocmd write')
        end
      end, 200)
    end,
    stdout_buffered = true,
    stderr_buffered = true,
  })
  vfn.chansend(j, old_lines)
  vfn.chanclose(j, 'stdin')
end

M.gofmt = function(...)
  local gofmt = _GO_NVIM_CFG.gofmt or 'gopls'
  local gofmt_args = _GO_NVIM_CFG.gofmt_args
    or gofmt == 'golines' and {
      '--max-len=' .. tostring(max_len),
      '--base-formatter=gofumpt',
    }
    or {}
  local long_opts = {
    all = 'a',
  }

  local short_opts = 'a'
  local args = ... or {}

  local getopt = require('go.alt_getopt')
  local optarg = getopt.get_opts(args, short_opts, long_opts)

  local all_buf = false
  if optarg['a'] then
    all_buf = true
  end
  if not install(gofmt) then
    utils.warn('installing ' .. gofmt .. ' please retry after installation')
    return
  end
  local a = {}
  utils.copy_array(gofmt_args, a)
  log('formatting', optarg, gofmt, gofmt_args)
  if all_buf then
    log('fmt all buffers')
    vim.cmd('wall')
    local bufs = utils.get_active_buf()
    log(bufs)

    for _, b in ipairs(bufs) do
      log(a, b)
      run(a, b.bufnr, gofmt)
    end
  else
    run(a, vim.api.nvim_get_current_buf(), gofmt)
  end
end

M.org_imports = function()
  require('go.lsp').codeaction('', 'source.organizeImports', M.gofmt)
end

M.goimports = function(...)
  local goimports = _GO_NVIM_CFG.goimports or 'gopls'
  local args = { ... }
  log('imports', args, goimports)
  if goimports == 'gopls' then
    if vfn.empty(args) == 1 then
      return M.org_imports()
    else
      local path = select(1, ...)
      local gopls = require('go.gopls')
      return gopls.import(path)
    end
  end
  local buf = vim.api.nvim_get_current_buf()
  require('go.install').install(goimports)
  -- specified the pkg name
  if #args > 0 then -- dont use golines
    return run(args, buf, 'goimports')
  end

  -- golines base formatter is goimports
  local a = {}
  if goimports == 'golines' then
    a = vim.deepcopy(goimport_args)
  end
  run(a, buf, goimports)
end

M.goimport = M.goimports
return M
