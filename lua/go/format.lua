-- golines A golang formatter that fixes long lines
-- golines + gofumports(stricter gofmt + goimport)
local api = vim.api
local utils = require("go.utils")
local log = utils.log
local max_len = _GO_NVIM_CFG.max_line_len or 120
local goimport = _GO_NVIM_CFG.goimport or "goimports"
local gofmt = _GO_NVIM_CFG.gofmt or "gofumpt"
local gofmt_args = _GO_NVIM_CFG.gofmt_args
                       or {"--max-len=" .. tostring(max_len), "--base-formatter=" .. gofmt}

local goimport_args = _GO_NVIM_CFG.goimport_args
                          or {"--max-len=" .. tostring(max_len), "--base-formatter=" .. goimport}

local run = function(fmtargs, from_buffer, cmd)
  local args = vim.deepcopy(fmtargs)
  if not from_buffer then
    table.insert(args, api.nvim_buf_get_name(0))
    print('formatting buffer... ' .. api.nvim_buf_get_name(0) .. vim.inspect(args))
  else
    print('formatting... ' .. vim.inspect(args))
  end

  local old_lines = api.nvim_buf_get_lines(0, 0, -1, true)
  if cmd then
    table.insert(args, 1, cmd)
  else
    table.insert(args, 1, "golines")
  end
  log(args)

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
      -- log("stdout" .. vim.inspect(data))
      old_lines = nil

    end,
    on_stderr = function(job_id, data, event)
      log(vim.inspect(data) .. "stderr")
    end,
    on_exit = function(id, data, event)
      -- log(vim.inspect(data) .. "exit")
      -- log("current data " .. vim.inspect(new_lines))
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
  local params = vim.lsp.util.make_range_params()
  params.context = {only = {"source.organizeImports"}}
  local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, wait_ms)
  if not result or next(result) == nil then
    log("nil result")
    return
  end
  -- log("org_imports result", result)
  for _, res in pairs(result) do
    for _, r in pairs(res.result or {}) do
      if r.edit or type(r.command) == "table" then
        if r.edit then
          local result = vim.lsp.util.apply_workspace_edit(r.edit)
          -- log("workspace edit", result)
        end
        if type(r.command) == "table" then
          vim.lsp.buf.execute_command(r.command)
        end
      else
        -- log("execute command", r)
        vim.lsp.buf.execute_command(r)
      end
    end
  end
  vim.lsp.buf.formatting()
end

M.goimport = function(...)
  if _GO_NVIM_CFG.goimport == 'gopls' then
    M.org_imports(1000)
    return
  end
  local args = {...}
  local a1 = select(1, args)
  local buf = true
  if type(a1) == "boolean" then
    buf = a1
    table.remove(args, 1)
  end
  require("go.install").install(goimport)
  require("go.install").install("golines")
  local a = vim.deepcopy(goimport_args)
  if #args > 0 and _GO_NVIM_CFG.goimport == 'goimports' then -- dont use golines
    return run(args, buf, 'goimports')
  end
  run(goimport_args, buf)
end

return M
