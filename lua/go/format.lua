-- golines A golang formatter that fixes long lines
-- golines + goimport
local api = vim.api
local utils = require("go.utils")
local log = utils.log
local max_len = _GO_NVIM_CFG.max_line_len or 120
local goimport = _GO_NVIM_CFG.goimport or "goimports"
local gofmt = _GO_NVIM_CFG.gofmt or "gofumpt"
local vfn = vim.fn
local install = require("go.install").install
local gofmt_args = _GO_NVIM_CFG.gofmt_args or {
  "--max-len=" .. tostring(max_len),
  "--base-formatter=" .. gofmt,
}

local goimport_args = _GO_NVIM_CFG.goimport_args
  or {
    "--max-len=" .. tostring(max_len),
    "--base-formatter=goimports",
  }

local run = function(fmtargs, bufnr, cmd)
  log(fmtargs, bufnr, cmd)
  bufnr = bufnr or 0
  if _GO_NVIM_CFG.gofmt == "gopls" then
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      vfn.bufload(bufnr)
    end

    vim.cmd("write")
    vim.lsp.buf.format({ async = _GO_NVIM_CFG.lsp_fmt_async, bufnr = bufnr, name = "gopls" })
    return
  end

  local args = vim.deepcopy(fmtargs)
  table.insert(args, api.nvim_buf_get_name(bufnr))
  log("formatting buffer... " .. vim.inspect(args), vim.lsp.log_levels.DEBUG)

  if bufnr == 0 then
    if vfn.getbufinfo("%")[1].changed == 1 then
      vim.cmd("write")
    end
  end

  local old_lines = api.nvim_buf_get_lines(0, 0, -1, true)
  if cmd then
    table.insert(args, 1, cmd)
  else
    table.insert(args, 1, "golines")
  end
  log("fmt cmd:", args)

  local j = vfn.jobstart(args, {
    on_stdout = function(_, data, _)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      if not utils.check_same(old_lines, data) then
        vim.notify("updating codes", vim.lsp.log_levels.DEBUG)
        api.nvim_buf_set_lines(0, 0, -1, false, data)
        vim.cmd("write")
      else
        vim.notify("already formatted", vim.lsp.log_levels.DEBUG)
      end
      -- log("stdout" .. vim.inspect(data))
      old_lines = nil
    end,
    on_stderr = function(_, data, _)
      data = utils.handle_job_data(data)
      log(vim.inspect(data) .. "from stderr")
    end,
    on_exit = function(_, data, _)  -- id, data, event
      -- log(vim.inspect(data) .. "exit")
      if data ~= 0 then
        return vim.notify("golines failed " .. tostring(data), vim.lsp.log_levels.ERROR)
      end
      old_lines = nil
      vim.defer_fn(function()
        if vfn.getbufinfo("%")[1].changed == 1 then
          vim.cmd("write")
        end
      end, 300)
    end,
    stdout_buffered = true,
    stderr_buffered = true,
  })
  vfn.chansend(j, old_lines)
  vfn.chanclose(j, "stdin")
end

local M = {}
M.gofmt = function(...)
  local long_opts = {
    all = "a",
  }

  local short_opts = "a"
  local args = ... or {}

  local getopt = require("go.alt_getopt")
  local optarg = getopt.get_opts(args, short_opts, long_opts)
  log(optarg)

  vim.env.GO_FMT = "gofumpt"
  local all_buf = false
  if optarg["a"] then
    all_buf = true
  end
  if not install(gofmt) then
    utils.notify("installing ".. gofmt .. " please retry after installation")
    return
  end
  if not install("golines") then
    utils.notify("installing golines , please rerun format after install finished")
    return
  end
  local a = {}
  utils.copy_array(gofmt_args, a)
  if all_buf then
    log("fmt all buffers")
    vim.cmd("wall")
    local bufs = utils.get_active_buf()
    log(bufs)

    for _, b in ipairs(bufs) do
      log(a, b)
      run(a, b.bufnr)
    end
  else
    if vfn.getbufinfo("%")[1].changed == 1 then
      vim.cmd("write")
    end
    run(a, 0)
  end
end

M.org_imports = function(wait_ms)
  local codeaction = require("go.lsp").codeaction
  codeaction("", "source.organizeImports", wait_ms)
  vim.defer_fn(function()
    vim.lsp.buf.format({ async = _GO_NVIM_CFG.lsp_fmt_async })
   end, 100)
end

M.goimport = function(...)
  local args = { ... }
  if _GO_NVIM_CFG.goimport == "gopls" then
    if vfn.empty(args) == 1 then
      return M.org_imports(1000)
    else
      local path = select(1, ...)
      local gopls = require("go.gopls")
      return gopls.import(path)
    end
  end
  local buf = vim.api.nvim_get_current_buf()
  require("go.install").install(goimport)
  -- specified the pkg name
  if #args > 0 then -- dont use golines
    return run(args, buf, "goimports")
  end

  local a = vim.deepcopy(goimport_args)
  require("go.install").install("golines")
  run(a, buf, "golines")
end

return M
