-- golines A golang formatter that fixes long lines
-- golines + gofumports(stricter gofmt + goimport)
local api = vim.api
local utils = require("go.utils")
local max_len = _GO_NVIM_CFG.max_line_len or 120
local goimport = _GO_NVIM_CFG.goimport ~= nil and _GO_NVIM_CFG.goimport or "gofumports"
local gofmt = _GO_NVIM_CFG.gofmt ~= nil and _GO_NVIM_CFG.gofmt or "gofumpt"
local gofmt_args = _GO_NVIM_CFG.gofmt_args and _GO_NVIM_CFG.gofmt_args
                       or {"--max-len=" .. tostring(max_len), "--base-formatter=" .. gofmt}

local goimport_args = _GO_NVIM_CFG.goimport_args and _GO_NVIM_CFG.goimport_args
                          or {"--max-len=" .. tostring(max_len), "--base-formatter=" .. goimport}

local run = function(args, from_buffer)

  if not from_buffer then
    table.insert(args, api.nvim_buf_get_name(0))
    print('formatting... ' .. api.nvim_buf_get_name(0) .. vim.inspect(args))
  end

  local old_lines = api.nvim_buf_get_lines(0, 0, -1, true)
  table.insert(args, 1, "golines")

  local j = vim.fn.jobstart(args, {
    on_stdout = function(job_id, data, event)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      if not utils.check_same(old_lines, data) then
        print("updating codes")
        api.nvim_buf_set_lines(0, 0, -1, false, data)
        api.nvim_command("write")
      else
        print("already formatted")
      end
      utils.log("stdout" .. vim.inspect(data))
      old_lines = nil

    end,
    on_stderr = function(job_id, data, event)
      utils.log(vim.inspect(data) .. "stderr")
    end,
    on_exit = function(id, data, event)
      utils.log(vim.inspect(data) .. "exit")
      -- utils.log("current data " .. vim.inspect(new_lines))
      old_lines = nil
    end,
    stdout_buffered = true,
    stderr_buffered = true
  })
  vim.fn.chansend(j, old_lines)
  vim.fn.chanclose(j, "stdin")
end

local M = {}
M.gofmt = function(buf)
  if _GO_NVIM_CFG.gofmt == 'gopls' then
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

M.OrgImports = function(wait_ms)
  local params = vim.lsp.util.make_range_params()
  params.context = {only = {"source.organizeImports"}}
  local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, wait_ms)
  for _, res in pairs(result or {}) do
    for _, r in pairs(res.result or {}) do
      if r.edit then
        vim.lsp.util.apply_workspace_edit(r.edit)
      else
        vim.lsp.buf.execute_command(r.command)
      end
    end
  end
  vim.lsp.buf.formatting()
end

M.goimport = function(buf)
  if _GO_NVIM_CFG.goimport == 'gopls' then
    M.OrgImports(1000)
    return
  end
  buf = buf or false
  require("go.install").install(goimport)
  require("go.install").install("golines")
  local a = {}
  utils.copy_array(goimport_args, a)
  run(a, buf)
end
return M
