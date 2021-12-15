-- https://phelipetls.github.io/posts/async-make-in-nvim-with-lua/
local M = {}
local util = require("go.utils")
local log = util.log
function M.make(...)
  local args = { ... }
  local lines = {}
  local errorlines = {}
  local winnr = vim.fn.win_getid()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local makeprg = vim.api.nvim_buf_get_option(bufnr, "makeprg")

  local indent = "%\\%(    %\\)"
  if not makeprg then
    log("makeprog not setup")
    return
  end

  local efm = [[%-G#\ %.%#]]
  if makeprg:find("go build")  then
    vim.cmd([[setl errorformat=%-G#\ %.%#]])
    -- if makeprg:find("go build") then
    efm = efm .. [[,%-G%.%#panic:\ %m]]
    efm = efm .. [[,%Ecan\'t\ load\ package:\ %m]]
    efm = efm .. [[,%A%\\%%\(%[%^:]%\\+:\ %\\)%\\?%f:%l:%c:\ %m]]
    efm = efm .. [[,%A%\\%%\(%[%^:]%\\+:\ %\\)%\\?%f:%l:\ %m]]
    efm = efm .. [[,%C%*\\s%m]]
    efm = efm .. [[,%-G%.%#]]
  end
  -- end

  if makeprg:find("golangci%-lint") then
    -- lint
    efm = efm .. [[,%A%\\%%(%[%^:]%\\+:\ %\\)%\\?%f:%l:%c:\ %m]]
    efm = efm .. [[,%A%\\%%(%[%^:]%\\+:\ %\\)%\\?%f:%l:\ %m]]

    local pwd = vim.lsp.buf.list_workspace_folders()[1]
    local cfg = pwd .. ".golangci.yml"

    if util.file_exists(cfg) then
      makeprg = makeprg .. [[\ -c\ ]] .. cfg
      vim.api.nvim_buf_set_option(bufnr, "makeprg", makeprg)
    end
  end
  if makeprg:find("go run") then
    log("go run")
    if args == nil or #args == 0 then
      makeprg = makeprg .. " ."
      vim.api.nvim_buf_set_option(bufnr, "makeprg", makeprg)
    end
    efm = efm .. [[,%A%\\t%#%f:%l\ +0x%[0-9A-Fa-f]%\\+]]
  end

  if makeprg:find("go vet") then
    if args == nil or #args == 0 then
      makeprg = makeprg .. " ."
      vim.api.nvim_buf_set_option(bufnr, "makeprg", makeprg)
    end
    efm = efm .. [[,%-Gexit\ status\ %\\d%\\+]]
  end

  if makeprg:find("test") then
    log("go test")
    -- I feel it is better to output everything
    -- efm = efm .. [[,]] .. require("go.gotest").efm()
  end

  local arg = " "
  for _, v in pairs(args or {}) do
    arg = arg .. " " .. v
  end

  if #arg > 0 then
    makeprg = makeprg .. arg

    vim.api.nvim_buf_set_option(bufnr, "makeprg", makeprg)
  end

  -- vim.cmd([[make %:r]])
  local cmd = vim.fn.expandcmd(makeprg)

  log(cmd, efm)
  local function on_event(job_id, data, event)
    log(event, data)
    if event == "stdout" then
      if data then
        -- log('stdout', data)
        for _, value in ipairs(data) do
          if value ~= "" then
            table.insert(lines, value)
          end
        end
      end
    end

    if event == "stderr" then
      if data then
        log("stderr", data)
        for _, value in ipairs(data) do
          if value ~= "" then
            table.insert(errorlines, value)
          end
        end
      end
    end

    if event == "exit" then
      if #errorlines > 0 then
        if #lines > 0 then
          vim.list_extend(errorlines, lines)
        end
        vim.fn.setqflist({}, " ", {
          title = cmd,
          lines = errorlines,
          efm = efm,
        })
      elseif #lines > 0 then
        vim.fn.setqflist({}, " ", {
          title = cmd,
          lines = lines,
        })
      end
      vim.api.nvim_command("doautocmd QuickFixCmdPost")
    end
    log(lines)
    log("err", errorlines)
    vim.cmd("botright copen")
    print(cmd .. " finished")
  end

  local job_id = vim.fn.jobstart(cmd, {
    on_stderr = on_event,
    on_stdout = on_event,
    on_exit = on_event,
    stdout_buffered = true,
    stderr_buffered = true,
  })
end

return M
