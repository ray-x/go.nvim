-- https://phelipetls.github.io/posts/async-make-in-nvim-with-lua/
local M = {}
local util = require("go.utils")
local log = util.log
local getopt = require("go.alt_getopt")

local function compile_efm()
  local efm = [[%-G#\ %.%#]]
  efm = efm .. [[,%-G%.%#panic:\ %m]]
  efm = efm .. [[,%Ecan\'t\ load\ package:\ %m]]
  efm = efm .. [[,%A%\\%%\(%[%^:]%\\+:\ %\\)%\\?%f:%l:%c:\ %m]]
  efm = efm .. [[,%A%\\%%\(%[%^:]%\\+:\ %\\)%\\?%f:%l:\ %m]]
  efm = efm .. [[,%C%*\\s%m]]
  efm = efm .. [[,%-G%.%#]]
  return efm
end

local namepath = {}

local function extract_filepath(msg)
  msg = msg or ""
  --[[     or [[    findAllSubStr_test.go:234: Error inserting caseResult1: operation error DynamoDB: PutItem, exceeded maximum number of attempts]]

  local pos, _ = msg:find([[[%w_-]+_test%.go:%d+:]])
  if pos == nil then
    return
  end
  local pos2 = msg:find(":")
  local s = msg:sub(pos, pos2 - 1)
  if namepath[s] ~= nil then
    return namepath[s]
  end
  if vim.fn.executable("find") == 0 then
    return
  end
  local cmd = "find ./ -type f -name " .. s
  local path = vim.fn.systemlist(cmd)

  if vim.v.shell_error ~= 0 then
    util.warn("find failed" .. vim.inspect(path))
    return
  end
  for _, value in pairs(path) do
    local st, _ = value:find(s)
    log(value, st)
    if st then
      local p = value:sub(1, st - 1)
      namepath[st] = p
      return p
    end
  end
end

local long_opts = {
  verbose = "v",
  compile = "c",
  tags = "t",
  bench = "b",
  run = "r",
  floaterm = "F",
}

local short_opts = "vct:bFr:"
local bench_opts = { "-benchmem", "-cpuprofile", "profile.out" }

function M.make(...)
  local args = { ... }
  local lines = {}
  local errorlines = {}
  local winnr = vim.fn.win_getid()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local makeprg = vim.api.nvim_buf_get_option(bufnr, "makeprg")

  local optarg, _, reminder = getopt.get_opts(args, short_opts, long_opts)
  log(makeprg, args, optarg, reminder)
  -- local indent = "%\\%(    %\\)"
  if not makeprg then
    log("makeprog not setup")
    return
  end

  local runner = vim.split(makeprg, ' ')[1]

  if not require("go.install").install(runner) then
    util.warn("please wait for " .. runner .. " to be installed and re-run the command")
    return
  end

  local efm = [[%-G#\ %.%#]]
  if makeprg:find("go build") then
    vim.cmd([[setl errorformat=%-G#\ %.%#]])
    -- if makeprg:find("go build") then
    efm = compile_efm()
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
  local compile_test = false
  if makeprg:find("test") then
    if optarg["c"] then
      log("compile test")
      compile_test = true
      efm = compile_efm()
    end
  end
  if makeprg:find("go run") then
    runner = "go run"
    if args == nil or #args == 0 or (#args == 1 and args[1] == "-F") then
      makeprg = makeprg .. " ."
    end
    efm = efm .. [[,%A%\\t%#%f:%l\ +0x%[0-9A-Fa-f]%\\+]]

    log("go run", makeprg)
  end

  if makeprg:find("go vet") then
    runner = "go vet"
    if args == nil or #args == 0 then
      makeprg = makeprg .. " ."
    end

    efm = compile_efm()
    efm = efm .. [[,%-Gexit\ status\ %\\d%\\+]]
  end

  local cmd = vim.fn.split(makeprg, " ")
  if optarg["t"] then
    local tag = optarg["t"]
    local f = tag:find("=")
    if not f then
      table.insert(cmd, "-tags=" .. tag)
    else
      table.insert(cmd, "-tags=" .. tag:sub(f + 1))
    end
  end
  if makeprg:find("test") then
    log("go test")

    runner = "go test"
    efm = compile_efm()

    if optarg["v"] then
      table.insert(cmd, "-v")
    end
    if optarg["r"] then
      log("run test")
      table.insert(cmd, "-run")
    end
    if compile_test then
      table.insert(cmd, "-c")
    end
  end

  if args and #args > 0 then
    cmd = vim.list_extend(cmd, reminder)
  end

  local function handle_color(line)
    if _GO_NVIM_CFG.run_in_floaterm or optarg["F"] then
      return line
    end
    if tonumber(vim.fn.match(line, "\\%x1b\\[[0-9;]\\+")) < 0 then
      return line
    end
    if type(line) ~= "string" then
      return line
    end
    line = vim.fn.substitute(line, "\\%x1b\\[[0-9;]\\+[mK]", "", "g")
    log(line)
    return line
  end

  if _GO_NVIM_CFG.run_in_floaterm or optarg["F"] then
    local term = require("go.term").run
    cmd = table.concat(cmd, " ")
    term({ cmd = cmd, autoclose = false })
    return
  end
  local failed = false
  local itemn = 1
  local function on_event(job_id, data, event)
    -- log("stdout", data, event)
    if event == "stdout" then
      if data then
        for _, value in ipairs(data) do
          if value ~= "" then
            if value:find("=== RUN") or value:find("no test file") then
              goto continue
            end
            value = handle_color(value)
            if value:find("FAIL") then
              failed = true
            end
            local changed = false
            if vim.fn.empty(vim.fn.glob(args[#args])) == 0 then
              changed = true
              if value:find("FAIL") == nil then
                value = args[4] .. util.sep() .. util.ltrim(value)
              end
            else
              local p = extract_filepath(value)
              if p then
                failed = true
                value = p .. util.ltrim(value)
                changed = true
              end
            end
            table.insert(lines, value)
            if itemn == 1 and failed and changed then
              itemn = #lines
            end
          end
          ::continue::
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
        efm =
          [[level=%tarning\ msg="%m:\ [%f:%l:%c:\ %.%#]",level=%tarning\ msg="%m",level=%trror\ msg="%m:\ [%f:%l:%c:\ %.%#]",level=%trror\ msg="%m",%f:%l:%c:\ %m,%f:%l:\ %m,%f:%l\ %m]]
      end
    end

    if event == "exit" then
      if type(cmd) == "table" then
        cmd = table.concat(cmd, " ")
      end
      local info = cmd
      local level = vim.lsp.log_levels.INFO
      if #errorlines > 0 then
        if #lines > 0 then
          vim.list_extend(errorlines, lines)
        end
        vim.fn.setqflist({}, " ", {
          title = cmd,
          lines = errorlines,
          efm = efm,
        })
        failed = true
        log(errorlines[1], job_id)
        vim.cmd([[echo v:shell_error]])
      elseif #lines > 0 then
        vim.fn.setqflist({}, " ", {
          title = cmd,
          lines = lines,
        })
      end

      if tonumber(data) ~= 0 then
        failed = true
        info = info .. " exited with code: " .. tostring(data)
        level = vim.lsp.log_levels.ERROR
      end
      _GO_NVIM_CFG.job_id = nil
      if failed then
        cmd = cmd .. " go test failed"
        level = vim.lsp.log_levels.WARN
        vim.cmd("botright copen")
      end

      itemn = 1
      if failed then
        vim.notify(info .. " failed", level)
      else
        vim.notify(info .. " succeed", level)
      end
      failed = false
    end
  end

  local cmdstr = vim.fn.join(cmd, " ") -- cmd list run without shell, cmd string run with shell
  -- releative dir does not work without shell
  log("cmd ", cmdstr)
  _GO_NVIM_CFG.job_id = vim.fn.jobstart(cmdstr, {
    on_stderr = on_event,
    on_stdout = on_event,
    on_exit = on_event,
    stdout_buffered = true,
    stderr_buffered = true,
  })
  return cmd
end

M.stopjob = function(id)
  id = id or _GO_NVIM_CFG.job_id
  if id == nil then
    return
  end
  local r = vim.fn.jobstop(id)
  if r == 1 then
    _GO_NVIM_CFG.job_id = nil
  else
    util.warn("failed to stop job " .. tostring(id))
  end
end

return M
