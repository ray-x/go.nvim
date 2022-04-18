-- golines A golang formatter that fixes long lines
-- golines + goimport
local api = vim.api
local utils = require("go.utils")
local log = utils.log
local max_len = _GO_NVIM_CFG.max_line_len or 120
local goimport = _GO_NVIM_CFG.goimport or "goimports"
local gofmt = _GO_NVIM_CFG.gofmt or "gofumpt"
local gofmt_args = _GO_NVIM_CFG.gofmt_args or {
  "--max-len=" .. tostring(max_len),
  "--base-formatter=" .. gofmt,
}

local goimport_args = _GO_NVIM_CFG.goimport_args
  or {
    "--max-len=" .. tostring(max_len),
    "--base-formatter=" .. goimport,
  }

local run = function(fmtargs, from_buffer, cmd)
  local args = vim.deepcopy(fmtargs)
  if not from_buffer then
    table.insert(args, api.nvim_buf_get_name(0))
    vim.notify("formatting buffer... " .. api.nvim_buf_get_name(0) .. vim.inspect(args), vim.lsp.log_levels.DEBUG)
  else
    vim.notify("formatting... " .. vim.inspect(args), vim.lsp.log_levels.DEBUG)
  end

  local old_lines = api.nvim_buf_get_lines(0, 0, -1, true)
  if cmd then
    table.insert(args, 1, cmd)
  else
    table.insert(args, 1, "golines")
  end
  log("fmt cmd:", args)

  local j = vim.fn.jobstart(args, {
    on_stdout = function(job_id, data, event)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      if not utils.check_same(old_lines, data) then
        vim.notify("updating codes", vim.lsp.log_levels.DEBUG)
        api.nvim_buf_set_lines(0, 0, -1, false, data)
        api.nvim_command("write")
      else
        vim.notify("already formatted", vim.lsp.log_levels.DEBUG)
      end
      -- log("stdout" .. vim.inspect(data))
      old_lines = nil
    end,
    on_stderr = function(job_id, data, event)
      data = utils.handle_job_data(data)
      log(vim.inspect(data) .. "from stderr")
    end,
    on_exit = function(id, data, event)
      -- log(vim.inspect(data) .. "exit")
      -- log("current data " .. vim.inspect(new_lines))
      old_lines = nil
    end,
    stdout_buffered = true,
    stderr_buffered = true,
  })
  vim.fn.chansend(j, old_lines)
  vim.fn.chanclose(j, "stdin")
end

local M = {}
M.gofmt = function(buf)
  if _GO_NVIM_CFG.gofmt == "gopls" then
    -- log("gopls format")
    vim.lsp.buf.formatting()
    return
  end
  vim.env.GO_FMT = "gofumpt"
  buf = buf or false
  require("go.install").install(gofmt)
  require("go.install").install("golines")
  local a = {}
  utils.copy_array(gofmt_args, a)
  run(a, buf)
end

M.org_imports = function(wait_ms)
  local codeaction = require("go.lsp").codeaction
  codeaction("", "source.organizeImports", wait_ms)
  vim.lsp.buf.formatting_sync(nil, wait_ms)
end

M.goimport = function(...)
  local args = { ... }
  if _GO_NVIM_CFG.goimport == "gopls" then
    if vim.fn.empty(args) == 1 then
      M.org_imports(1000)
      return
    else
      local path = select(1, ...)
      local gopls = require("go.gopls")
      gopls.import(path)
      return
    end
  end
  local a1 = select(1, args)
  local buf = true
  if #args > 0 and type(args[1]) == "boolean" then
    buf = a1
    table.remove(args, 1)
  end
  require("go.install").install(goimport)
  if #args > 0 and _GO_NVIM_CFG.goimport == "goimports" then -- dont use golines
    return run(args, buf, "goimports")
  end

  local a = vim.deepcopy(goimport_args)
  require("go.install").install("golines")
  run(a, buf, "golines")
end

return M
