local M = {}
local utils = require("go.utils")
local log = utils.log
local empty = utils.empty
local ginkgo = require("go.ginkgo")

M.efm = function()
  local indent = [[%\\%(    %\\)]]
  local efm = [[%-G=== RUN   %.%#]]
  efm = efm .. [[,%-G" .. indent .. "%#--- PASS: %.%#]]
  efm = efm .. [[,%G--- FAIL: %\\%(Example%\\)%\\@=%m (%.%#)]]
  efm = efm .. [[,%G" .. indent .. "%#--- FAIL: %m (%.%#)]]
  efm = efm .. [[,%A" .. indent .. "%\\+%[%^:]%\\+: %f:%l: %m]]
  efm = efm .. [[,%+Gpanic: test timed out after %.%\\+]]
  efm = efm .. ",%+Afatal error: %.%# [recovered]"
  efm = efm .. [[,%+Afatal error: %.%#]]
  efm = efm .. [[,%+Apanic: %.%#]]

  -- exit
  efm = efm .. ",%-Cexit status %[0-9]%\\+"
  efm = efm .. ",exit status %[0-9]%\\+"
  -- failed lines
  efm = efm .. ",%-CFAIL%\\t%.%#"
  -- compiling error

  efm = efm .. ",%A%f:%l:%c: %m"
  efm = efm .. ",%A%f:%l: %m"
  efm = efm .. ",%-C%.%#"
  efm = efm .. ",%-G%.%#"
  efm = string.gsub(efm, " ", [[\ ]])
  log(efm)
  return efm
end

local function get_build_tags(args)
  -- local tags = "-tags"
  local tags = {}

  local space = [[\ ]]
  if _GO_NVIM_CFG.run_in_floaterm then
    space = " "
  end
  if _GO_NVIM_CFG.build_tags ~= "" then
    tags = { "-tags=" .. _GO_NVIM_CFG.build_tags }
  end

  for i, value in pairs(args) do
    if value:find("-tags") then
      table.insert(tags, value)
      table.remove(args, i)
      break
    end
  end
  return tags, args
end

M.get_build_tags = get_build_tags

local function run_test(path, args)
  log(args)
  local test_runner = _GO_NVIM_CFG.go
  if _GO_NVIM_CFG.test_runner ~= test_runner then
    test_runner = _GO_NVIM_CFG.test_runner
    require("go.install").install(test_runner)
  end

  local tags, args2 = get_build_tags(args)

  local cmd
  if _GO_NVIM_CFG.run_in_floaterm then
    cmd = { test_runner, "test", "-v" }
  else
    cmd = { "-v" }
  end
  if not empty(tags) then
    cmd = vim.list_extend(cmd, tags)
  end
  if not empty(args2) then
    cmd = vim.list_extend(cmd, args2)
  end

  if path ~= "" then
    table.insert(cmd, path)
  else
    local argsstr = "." .. utils.sep() .. "..."
    cmd = table.insert(cmd, argsstr)
  end
  utils.log(cmd)
  if _GO_NVIM_CFG.run_in_floaterm then
    local term = require("go.term").run
    term({ cmd = cmd, autoclose = false })
    return
  end

  vim.cmd([[setl makeprg=]] .. _GO_NVIM_CFG.go .. [[\ test]])

  utils.log("test cmd", cmd)
  require("go.asyncmake").make(unpack(cmd))
end

M.test = function(...)
  local args = { ... }
  log(args)

  local workfolder = utils.work_path()
  if workfolder == nil then
    workfolder = "."
  end
  local fpath = workfolder .. utils.sep() .. "..."
  utils.log("fpath :" .. fpath)
  run_test(fpath, args)
end

M.test_suit = function(...)
  local args = { ... }
  log(args)

  local workfolder = utils.work_path()
  utils.log(args)
  local fpath = workfolder .. utils.sep() .. "..."

  utils.log("fpath" .. fpath)

  run_test(fpath, args)
end

M.test_package = function(...)
  local args = { ... }
  log(args)

  local repath = utils.rel_path() or ""

  local fpath = repath .. utils.sep() .. "..."

  utils.log("fpath: " .. fpath)

  -- args[#args + 1] = fpath
  run_test(fpath, args)
end

M.test_fun = function(...)
  local args = { ... }
  log(args)

  local fpath = vim.fn.expand("%:p:h")
  -- fpath = fpath:gsub(" ", [[\ ]])
  -- fpath = fpath:gsub("-", [[\-]])
  -- log(fpath)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  local ns = require("go.ts.go").get_func_method_node_at_pos(row, col)
  if empty(ns) then
    return false
  end

  local tags, args2 = get_build_tags(args)
  local argsstr = ""
  utils.log("parnode" .. vim.inspect(ns))

  local test_runner = _GO_NVIM_CFG.go

  if _GO_NVIM_CFG.test_runner ~= "go" then
    require("go.install").install(test_runner)
    test_runner = _GO_NVIM_CFG.test_runner
    if test_runner == "ginkgo" then
      ginkgo.test_fun(...)
    end
  end

  local cmd
  if _GO_NVIM_CFG.run_in_floaterm then
    cmd = { test_runner, "test", "-v" }
  else
    cmd = { "-v" }
  end
  if not empty(tags) then
    cmd = vim.list_extend(cmd, tags)
  end
  if not empty(args2) then
    cmd = vim.list_extend(cmd, args2)
  else
    argsstr = "." .. utils.sep() .. "..."
    table.insert(cmd, argsstr)
  end

  if ns.name:find("Bench") then
    local bench = "-bench=" .. ns.name
    table.insert(cmd, bench)
  end

  table.insert(cmd, "-run")
  table.insert(cmd, [[^]] .. ns.name)

  table.insert(cmd, fpath)

  if _GO_NVIM_CFG.run_in_floaterm then
    utils.log(cmd)
    local term = require("go.term").run
    term({ cmd = cmd, autoclose = false })
    return
  end

  vim.cmd([[setl makeprg=]] .. test_runner .. [[\ test]])
  -- set_efm()
  utils.log("test cmd", cmd)
  require("go.asyncmake").make(unpack(cmd))

  return true
end

M.test_file = function(...)
  local args = { ... }
  log(args)

  -- require sed
  -- local testcases = [[sed -n 's/func.*\(Test.*\)(.*/\1/p' | xargs | sed 's/ /\\\|/g']]
  local fpath = vim.fn.expand("%:p")
  -- utils.log(args)
  local cmd = [[cat ]] .. fpath .. [[| sed -n 's/func.*\(Test.*\)(.*/\1/p' | xargs | sed 's/ /\\\|/g']]
  -- TODO maybe with treesitter or lsp list all functions in current file and regex with Test
  local tests = vim.fn.systemlist(cmd)[1]
  utils.log(cmd, tests)
  if empty(tests) then
    vim.notify("no test found fallback to package test", vim.lsp.log_levels.DEBUG)
    M.test_package(...)
    return
  end

  local tags, args2 = get_build_tags(args)

  local test_runner = _GO_NVIM_CFG.go
  if _GO_NVIM_CFG.test_runner ~= "go" then
    test_runner = _GO_NVIM_CFG.test_runner
    require("go.install").install(test_runner)
    if test_runner == "ginkgo" then
      ginkgo.test_fun(...)
    end
  end

  local relpath = utils.rel_path()

  local cmd_args

  if _GO_NVIM_CFG.run_in_floaterm then
    cmd_args = { test_runner, "test", "-v" }
  else
    cmd_args = { "-v" }
  end
  if tags ~= nil and #tags > 1 then
    cmd_args = vim.list_extend(cmd_args, tags)
  end

  if args2 then
    cmd_args = vim.list_extend(cmd_args, args2)
  end
  table.insert(cmd_args, "-run")
  table.insert(cmd_args, tests)
  table.insert(cmd_args, relpath)

  if _GO_NVIM_CFG.run_in_floaterm then
    local term = require("go.term").run
    term({ cmd = cmd_args, autoclose = false })
    return
  end

  vim.cmd([[setl makeprg=]] .. _GO_NVIM_CFG.go .. [[\ test]])
  require("go.asyncmake").make(unpack(cmd_args))
  utils.log("test cmd", cmd)
end

return M
