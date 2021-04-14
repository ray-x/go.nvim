-- golines A golang formatter that fixes long lines
-- golines + gofumports(stricter gofmt + goimport)
local api = vim.api
local util = require("go.utils")
local max_len = vim.g.go_nvim_max_len or 120
local goimport = vim.g.go_nvim_goimport ~= nil and vim.g.go_nvim_goimport or "gofumports"
local gofmt = vim.g.go_nvim_gofmt ~= nil and vim.g.go_nvim_gofmt or "gofumpt"
local gofmt_args =
  vim.g.go_nvim_gofmt_args and vim.g.go_nvim_gofmt_args or
  {"--max-len=" .. tostring(max_len), "--base-formatter=" .. gofmt}

local goimport_args =
  vim.g.go_nvim_goimport_args and vim.g.go_nvim_goimport_args or
  {"--max-len=" .. tostring(max_len), "--base-formatter=" .. goimport}

local run = function(args, from_buffer)
  if not from_buffer then
    table.insert(args, api.nvim_buf_get_name(0))
    print('formatting... ' .. api.nvim_buf_get_name(0) .. vim.inspect(args))
  end

  local old_lines = api.nvim_buf_get_lines(0, 0, -1, true)
  table.insert(args, 1, "golines")

  local j =
    vim.fn.jobstart(
    args,
    {
      on_stdout = function(job_id, data, event)
        if not data or #data==1 and data[1] == "" then return end
        if not util.check_same(old_lines, data) then
          print("updating codes")
          api.nvim_buf_set_lines(0, 0, #data, false, data)
          api.nvim_command("write")
        else
          print("already formatted")
        end
        util.log("stdout" .. vim.inspect(data))
        old_lines = nil

      end,
      on_stderr = function(job_id, data, event)
        util.log(vim.inspect(data) .. "stderr")
      end,
      on_exit = function(id, data, event)
        util.log(vim.inspect(data) .. "exit")
        -- util.log("current data " .. vim.inspect(new_lines))
        old_lines = nil
      end,
      stdout_buffered = true,
      stderr_buffered = true,
    }
  )
  vim.fn.chansend(j, old_lines)
  vim.fn.chanclose(j, "stdin")
end

local M = {}
M.gofmt = function(buf)
  vim.env.GO_TEST = "gofmt"
  buf = buf or false
  require("go.install").install(gofmt)
  require("go.install").install("golines")
  local a = {}
  util.copy_array(gofmt_args, a)
  run(a, buf)
end

M.goimport = function()
  buf = buf or false
  require("go.install").install(goimport)
  require("go.install").install("golines")
  local a = {}
  util.copy_array(goimport_args, a)
  run(a, buf)
end
return M
