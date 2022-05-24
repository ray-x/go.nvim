-- run `go test`
local M = {}
local utils = require("go.utils")
local log = utils.log
local empty = utils.empty
local ginkgo = require("go.ginkgo")
local getopt = require("go.alt_getopt")

local long_opts = {
  verbose = "v",
  compile = "c",
  tags = "t",
  bench = "b",
  floaterm = "F",
}

local sep = require("go.utils").sep()
local short_opts = "vct:bF"
local bench_opts = { "-benchmem", "-cpuprofile", "profile.out" }

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
  local tags
  local space = [[\ ]]
  if _GO_NVIM_CFG.run_in_floaterm then
    space = " "
  end
  if _GO_NVIM_CFG.build_tags ~= "" then
    tags = "-tags=" .. _GO_NVIM_CFG.build_tags
  end

  local optarg, optind, reminder = getopt.get_opts(args, short_opts, long_opts)
  if optarg["t"] then
    if tags then
      tags = tags .. space .. optarg["t"]
    else
      tags = "-tags=" .. optarg["t"]
    end
  end
  if tags then
    return { tags }, reminder
  end
end

M.get_build_tags = get_build_tags

local function run_test(path, args)
  log(args)
  local compile = false
  local bench = false
  local optarg, optind, reminder = getopt.get_opts(args, short_opts, long_opts)
  if optarg["c"] then
    path = utils.rel_path() -- vim.fn.expand("%:p:h") can not resolve releative path
    compile = true
  end
  if optarg["b"] then
    bench = true
  end
  if next(reminder) then
    path = reminder[1]
  end
  local test_runner = _GO_NVIM_CFG.go
  if _GO_NVIM_CFG.test_runner ~= test_runner then
    test_runner = _GO_NVIM_CFG.test_runner
    require("go.install").install(test_runner)
  end

  local tags = get_build_tags(args)

  log(tags)
  local cmd = {}
  if _GO_NVIM_CFG.run_in_floaterm then
    table.insert(cmd, test_runner)
    table.insert(cmd, "test")
  end

  if _GO_NVIM_CFG.verbose_tests then
    table.insert(cmd, "-v")
  end

  if not empty(tags) then
    cmd = vim.list_extend(cmd, tags)
  end
  if not empty(reminder) then
    cmd = vim.list_extend(cmd, reminder)
  end

  if compile == true then
    if path ~= "" then
      table.insert(cmd, path)
    end
  elseif bench == true then
    if path ~= "" then
      table.insert(cmd, "-bench=" .. path)
    else
      table.insert(cmd, "-bench=.")
    end
    vim.list_extend(cmd, bench_opts)
  else
    if path ~= "" then
      table.insert(cmd, path)
    else
      local argsstr = "." .. utils.sep() .. "..."
      cmd = table.insert(cmd, argsstr)
    end
  end
  utils.log(cmd, args)
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

  vim.fn.setqflist({})
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

  local repath = utils.rel_path() or "."
  local fpath = repath .. utils.sep() .. "..."
  utils.log("fpath: " .. fpath)

  -- args[#args + 1] = fpath
  run_test(fpath, args)
end

M.test_fun = function(...)
  local args = { ... }
  log(args)

  local fpath = "." .. sep .. vim.fn.fnamemodify(vim.fn.expand("%:h"), ":~:.")
  -- fpath = fpath:gsub(" ", [[\ ]])
  -- fpath = fpath:gsub("-", [[\-]])
  -- log(fpath)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  local ns = require("go.ts.go").get_func_method_node_at_pos(row, col)
  if empty(ns) then
    return false
  end

  local optarg, optind, reminder = getopt.get_opts(args, short_opts, long_opts)
  local tags = get_build_tags(args)
  utils.log("parnode" .. vim.inspect(ns))

  local test_runner = _GO_NVIM_CFG.go

  if _GO_NVIM_CFG.test_runner ~= "go" then
    require("go.install").install(test_runner)
    test_runner = _GO_NVIM_CFG.test_runner
    if test_runner == "ginkgo" then
      ginkgo.test_fun(...)
    end
  end

  local cmd = {}
  local run_in_floaterm = optarg["F"] or _GO_NVIM_CFG.run_in_floaterm
  if run_in_floaterm then
    table.insert(cmd, test_runner)
    table.insert(cmd, "test")
  end

  if _GO_NVIM_CFG.verbose_tests then
    table.insert(cmd, "-v")
  end

  if not empty(tags) then
    cmd = vim.list_extend(cmd, tags)
  end

  if ns.name:find("Bench") then
    local bench = "-bench=" .. ns.name
    table.insert(cmd, bench)
    vim.list_extend(cmd, bench_opts)
  else
    table.insert(cmd, "-run")
    table.insert(cmd, [[^]] .. ns.name)
  end
  table.insert(cmd, fpath)

  if run_in_floaterm then
    utils.log(cmd)
    local term = require("go.term").run
    term({ cmd = cmd, autoclose = false })
    return
  end

  vim.cmd([[setl makeprg=]] .. test_runner .. [[\ test]])
  -- set_efm()
  utils.log("test cmd", cmd)
  return require("go.asyncmake").make(unpack(cmd))

end

M.test_file = function(...)
  local args = { ... }
  log(args)

  -- require sed
  -- local testcases = [[sed -n 's/func.*\(Test.*\)(.*/\1/p' | xargs | sed 's/ /\\\|/g']]
  local fpath = vim.fn.expand("%:p")
  -- utils.log(args)
  local cmd = [[cat ]] .. fpath .. [[| sed -n 's/func.*\(Test.*\)(.*/\1/p' | xargs | sed 's/ /\|/g']]
  -- TODO maybe with treesitter or lsp list all functions in current file and regex with Test
  if vim.fn.executable("sed") == 0 then
    M.test_package(...)
    return
  end

  local optarg, optind, reminder = getopt.get_opts(args, short_opts, long_opts)

  local run_in_floaterm = optarg["F"] or _GO_NVIM_CFG.run_in_floaterm
  local tests = vim.fn.systemlist(cmd)
  utils.log(cmd, tests)
  tests = tests[1]
  if vim.fn.empty(tests) == 1 then
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

  local cmd_args = {}
  if run_in_floaterm then
    table.insert(cmd_args, test_runner)
    table.insert(cmd_args, "test")
  end

  if _GO_NVIM_CFG.verbose_tests then
    table.insert(cmd_args, "-v")
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

  if run_in_floaterm then
    local term = require("go.term").run
    term({ cmd = cmd_args, autoclose = false })
    return
  end

  vim.cmd([[setl makeprg=]] .. _GO_NVIM_CFG.go .. [[\ test]])
  require("go.asyncmake").make(unpack(cmd_args))
  utils.log("test cmd: ", cmd, " finished")
end

-- TS based run func
-- https://github.com/rentziass/dotfiles/blob/master/vim/.config/nvim/lua/rentziass/lsp/go_tests.lua
M.run_file = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local tree = vim.treesitter.get_parser(bufnr):parse()[1]
  local query = vim.treesitter.parse_query("go", require("go.ts.textobjects").query_test_func)

  local test_names = {}
  for id, node, metadata in query:iter_captures(tree:root(), bufnr, 0, -1) do
    local name = query.captures[id] -- name of the capture in the query
    if name == "test_name" then
      table.insert(test_names, vim.treesitter.query.get_node_text(node, bufnr))
    end
  end

  vim.schedule(function()
    vim.lsp.buf.execute_command({
      command = "gopls.run_tests",
      arguments = { { URI = vim.uri_from_bufnr(0), Tests = test_names } },
    })
  end)
end

M.select_tests = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local tree = vim.treesitter.get_parser(bufnr):parse()[1]
  local query = vim.treesitter.parse_query("go", require("go.ts.textobjects").query_test_func)
  local test_names = {}
  for id, node, metadata in query:iter_captures(tree:root(), bufnr, 0, -1) do
    local name = query.captures[id] -- name of the capture in the query
    if name == "test_name" then
      table.insert(test_names, vim.treesitter.query.get_node_text(node, bufnr))
    end
  end

  local guihua = utils.load_plugin("guihua.lua", "guihua.gui")
  local original_select = vim.ui.select

  if guihua then
    vim.ui.select = require("guihua.gui").select
  end

  local title = "Possible Tests"
  pickers.new({}, {
    prompt_title = title,
    finder = finders.new_table({
      results = test_names,
      entry_maker = function(entry)
        return {
          value = entry,
          text = entry,
          display = entry,
          ordinal = entry,
        }
      end,
    }),
    previewer = false,
    sorter = conf.generic_sorter({}),
    attach_mappings = function(_)
      actions.select_default:replace(function(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.schedule(function()
          vim.lsp.buf.execute_command({
            command = "gopls.run_tests",
            arguments = { { URI = vim.uri_from_bufnr(0), Tests = { selection.value } } },
          })
        end)

        actions.close(prompt_bufnr)
      end)
      return true
    end,
  }):find()
end

return M
