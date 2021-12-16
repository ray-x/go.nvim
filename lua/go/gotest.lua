local M = {}
local utils = require("go.utils")
local log = utils.log
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
  local tags = "-tags"

  local space = [[\ ]]
  if _GO_NVIM_CFG.run_in_floaterm then
    space = " "
  end
  if _GO_NVIM_CFG.build_tags ~= "" then
    tags = tags .. space .. _GO_NVIM_CFG.build_tags
  end

  for i, value in pairs(args) do
    if value:find("-tags") then
      if tags == "-tags" then
        tags = value
      else
        tags = tags .. "," .. value:sub(#"-tags=" + 1)
      end
      table.remove(args, i)
      break
    end
  end
  if tags == "-tags" then
    tags = ""
    return tags, args
  else
    return space .. tags .. space, args
  end
end

M.get_build_tags = get_build_tags

local function run_test(path, args)
  log(args)
  local test_runner = "go"
  if _GO_NVIM_CFG.test_runner ~= "go" then
    test_runner = _GO_NVIM_CFG.test_runner
    require("go.install").install(test_runner)
  end

  local tags, args2 = get_build_tags(args)
  log(tags, args2)
  if tags ~= "" then
    tags = tags .. [[\ ]]
  end
  local argsstr = ""

  if _GO_NVIM_CFG.run_in_floaterm then
    argsstr = table.concat(args2 or {}, " ")
    if argsstr == "" then
      argsstr = "." .. utils.sep() .. "..."
    end
    local cmd = test_runner .. [[ test ]] .. tags .. [[ -v ]] .. argsstr
    cmd = cmd .. tags .. [[ -v ]] .. argsstr
    if path ~= "" then
      cmd = cmd .. [[  ]] .. path
    end
    utils.log(cmd)
    local term = require("go.term").run
    term({ cmd = cmd, autoclose = false })
    return
  end

  argsstr = table.concat(args2 or {}, [[\ ]])
  if argsstr == "" then
    argsstr = "." .. utils.sep() .. "..." .. [[\ ]]
  end
  path = argsstr or path

  local cmd = [[setl makeprg=go\ test\ ]] .. tags .. path .. [[ | lua require"go.asyncmake".make()]]
  utils.log("test cmd", cmd)
  vim.cmd(cmd)
end

M.test = function(...)
  local args = { ... }
  log(args)

  local workfolder = vim.lsp.buf.list_workspace_folders()[1]
  if workfolder == nil then
    workfolder = "."
  end
  local fpath = workfolder .. utils.sep() .. "..."
  -- local fpath = workfolder .. utils.sep() .. '...'
  -- local fpath = './' .. vim.fn.expand('%:h') .. '/...'
  utils.log("fpath" .. fpath)

  run_test(fpath, args)
end

M.test_suit = function(...)
  local args = { ... }
  log(args)

  local workfolder = vim.lsp.buf.list_workspace_folders()[1]
  utils.log(args)
  local fpath = workfolder .. utils.sep() .. "..."
  -- local fpath = './' .. vim.fn.expand('%:h') .. '/...'
  utils.log("fpath" .. fpath)

  run_test(fpath, args)
end

M.test_package = function(...)
  local args = { ... }
  log(args)

  local repath = utils.rel_path() or ""

  local fpath = repath .. utils.sep() .. "..."
  utils.log("fpath" .. fpath)
  utils.log("fpath" .. fpath)

  args[#args + 1] = fpath
  run_test(fpath, args)
end

M.test_fun = function(...)
  local args = { ... }
  log(args)
  -- for i, v in ipairs(args) do
  --   table.insert(setup, v)
  -- end

  local fpath = vim.fn.expand("%:p:h")
  fpath:gsub(" ", [[\ ]])
  fpath:gsub("-", [[\-]])
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  local ns = require("go.ts.go").get_func_method_node_at_pos(row, col)
  if ns == nil or ns == {} then
    return false
  end

  local tags, args2 = get_build_tags(args)
  local argsstr = ""
  utils.log("parnode" .. vim.inspect(ns))

  local test_runner = "go"
  if _GO_NVIM_CFG.test_runner ~= "go" then
    test_runner = _GO_NVIM_CFG.test_runner
    if test_runner == "ginkgo" then
      ginkgo.test_fun(...)
    end
    require("go.install").install(test_runner)
  end
  local bench = ""
  if ns.name:find("Bench") then
    bench = "-bench=" .. ns.name
  end

  if _GO_NVIM_CFG.run_in_floaterm then
    argsstr = table.concat(args2 or {}, " ")

    local cmd = test_runner .. [[ test ]] -- .. tags .. [[-v -run ^]] .. ns.name .. [[ ]] .. argstr .. [[ ]] .. fpath

    if tags ~= "" then
      cmd = cmd .. tags
    end

    cmd = cmd .. [[-v -run ^]] .. ns.name

    if bench ~= "" then
      cmd = cmd .. [[  ]] .. bench
    end
    if argsstr ~= "" then
      cmd = cmd .. [[  ]] .. argsstr
    end

    cmd = cmd .. [[  ]] .. fpath

    utils.log(cmd)
    local term = require("go.term").run
    term({ cmd = cmd, autoclose = false })
    return
  end

  argsstr = table.concat(args2 or {}, [[\ ]])
  -- local cmd =
  --     [[setl makeprg=]] .. test_runner .. [[\ test\ ]] .. tags .. [[-v\ -run\ ^]] .. ns.name .. [[\ ]] .. argsstr
  --         .. [[\ ]] .. fpath .. [[ | lua require"go.asyncmake".make()]]
  --

  local cmd = [[setl makeprg=]] .. test_runner .. [[\ test\ ]]

  if tags ~= "" then
    cmd = cmd .. tags
  end

  cmd = cmd .. [[-v\ -run\ ^]] .. ns.name

  if bench ~= "" then
    cmd = cmd .. [[\ ]] .. bench
  end
  if argsstr ~= "" then
    cmd = cmd .. [[\ ]] .. argsstr
  end

  -- set_efm()
  cmd = cmd .. [[\ ]] .. fpath .. [[ | lua require"go.asyncmake".make()]]

  utils.log("test cmd", cmd)
  vim.cmd(cmd)
  return true
end

M.test_file = function(...)
  local args = { ... }
  log(args)

  -- require sed
  -- local testcases = [[sed -n 's/func.*\(Test.*\)(.*/\1/p' | xargs | sed 's/ /\\\|/g']]
  utils.log(args)
  local cmd = [[cat ]] .. vim.fn.expand("%:p") .. [[| sed -n 's/func.*\(Test.*\)(.*/\1/p' | xargs | sed 's/ /\\\|/g']]
  -- TODO maybe with treesitter or lsp list all functions in current file and regex with Test
  local tests = vim.fn.systemlist(cmd)[1]
  -- local fpath = './' .. vim.fn.expand('%:h') .. '/...'
  utils.log(tests)
  if tests == nil or tests == {} then
    print("no test found fallback to package test")
    M.test_package(...)
    return
  end

  local tags, args2 = get_build_tags(args)
  local argsstr = ""

  local test_runner = "go"
  if _GO_NVIM_CFG.test_runner ~= "go" then
    test_runner = _GO_NVIM_CFG.test_runner
    if test_runner == "ginkgo" then
      ginkgo.test_fun(...)
    end
    require("go.install").install(test_runner)
  end

  local relpath = utils.rel_path()

  if _GO_NVIM_CFG.run_in_floaterm then
    argsstr = table.concat(args2 or {} or {}, " ")
    cmd = test_runner .. [[ test ]] .. tags .. [[-v -run ]] .. tests .. [[ ]] .. argsstr .. [[  ]] .. relpath
    utils.log(cmd)
    local term = require("go.term").run
    term({ cmd = cmd, autoclose = false })
    return
  end

  argsstr = table.concat(args2 or {}, [[\ ]])

  cmd = [[setl makeprg=go\ test\ ]]
    .. tags
    .. [[-v\ -run\ ]]
    .. tests
    .. [[\ ]]
    .. argsstr
    .. [[\ ]]
    .. relpath
    .. [[| lua require"go.asyncmake".make()]]
  utils.log("test cmd", cmd)
  vim.cmd(cmd)
end

return M
