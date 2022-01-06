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

  log(makeprg, args)
  local indent = "%\\%(    %\\)"
  if not makeprg then
    log("makeprog not setup")
    return
  end

  local efm = [[%-G#\ %.%#]]
  if makeprg:find("go build") then
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

  local runner = "golangci-lint"
  if makeprg:find("golangci%-lint") then
    -- lint
    efm = efm .. [[,%A%\\%%(%[%^:]%\\+:\ %\\)%\\?%f:%l:%c:\ %m]]
    efm = efm .. [[,%A%\\%%(%[%^:]%\\+:\ %\\)%\\?%f:%l:\ %m]]

    local pwd = util.work_path()
    local cfg = pwd .. ".golangci.yml"

    if util.file_exists(cfg) then
      makeprg = makeprg .. [[\ -c\ ]] .. cfg
      -- vim.api.nvim_buf_set_option(bufnr, "makeprg", makeprg)
    end
  end
  if makeprg:find("go run") then
    runner = "go run"
    if args == nil or #args == 0 then
      makeprg = makeprg .. " ."
      -- vim.api.nvim_buf_set_option(bufnr, "makeprg", makeprg)
    end
    efm = efm .. [[,%A%\\t%#%f:%l\ +0x%[0-9A-Fa-f]%\\+]]

    log("go run", makeprg)
  end

  if makeprg:find("go vet") then
    runner = "go vet"
    if args == nil or #args == 0 then
      makeprg = makeprg .. " ."
      -- vim.api.nvim_buf_set_option(bufnr, "makeprg", makeprg)
    end
    efm = efm .. [[,%-Gexit\ status\ %\\d%\\+]]
  end

  if makeprg:find("test") then
    log("go test")

    runner = "go test"

    -- I feel it is better to output everything
    -- efm = efm .. [[,]] .. require("go.gotest").efm()
  end

  local cmd = vim.fn.split(makeprg, " ")

  if args and #args > 0 then
    cmd = vim.list_extend(cmd, args)
    -- vim.api.nvim_buf_set_option(bufnr, "makeprg", makeprg)
  end

  local function on_event(job_id, data, event)
    log("stdout", data, event)
    if event == "stdout" then
      if data then
        for _, value in ipairs(data) do
          if value ~= "" then
            table.insert(lines, value)
          end
        end
      end
    end

    if event == "stderr" then
      if data then
        for _, value in ipairs(data) do
          if value ~= "" then
            table.insert(errorlines, value)
          end
        end
      end
      if next(errorlines) ~= nil and runner == "golangci-lint" then
        efm =  [[level=%tarning\ msg="%m:\ [%f:%l:%c:\ %.%#]",level=%tarning\ msg="%m",level=%trror\ msg="%m:\ [%f:%l:%c:\ %.%#]",level=%trror\ msg="%m",%f:%l:%c:\ %m,%f:%l:\ %m,%f:%l\ %m]]     end
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

      vim.cmd("botright copen")
      if type(cmd) == "table" then
        cmd = table.concat(cmd, " ")
      end
      vim.notify(cmd .. " finished", vim.lsp.log_levels.WARN)
    end
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
