-- Table driven tests based on its target source files' function and method signatures.
-- https://github.com/cweill/gotests
local ut = {}
local gotests = "gotests"
local test_dir = _GO_NVIM_CFG.test_dir or ""
local test_template = vim.go_nvim_test_template or ""
local utils = require("go.utils")
local empty = utils.empty
local run = function(setup)
  print(vim.inspect(setup))
  local j = vim.fn.jobstart(setup, {
    on_stdout = function(jobid, data, event)
      print("unit tests generate " .. vim.inspect(data))
    end,
    on_stderr = function(_, data, _)
      print("generate tests finished with message: " .. vim.inspect(setup) .. "error: " .. vim.inspect(data))
    end,
  })
end

local add_test = function(args)
  require("go.install").install(gotests)
  if string.len(test_template) > 1 then
    table.insert(args, "-template")
    table.insert(args, test_template)
    if string.len(test_dir) > 1 then
      table.insert(args, "-template_dir")
      table.insert(args, test_dir)
    end
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row + 1, col + 1
  local ns = require("go.ts.go").get_func_method_node_at_pos(row, col)
  if empty(ns) then
    return
  end

  utils.log("parnode" .. vim.inspect(ns))
  run(args)
end

ut.fun_test = function(parallel)
  parallel = parallel or false
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row + 1, col + 1
  local ns = require("go.ts.go").get_func_method_node_at_pos(row, col)
  if empty(ns) then
    return
  end

  -- utils.log("parnode" .. vim.inspect(ns))
  local funame = ns.name
  -- local rs, re = ns.dim.s.r, ns.dim.e.r
  local gofile = vim.fn.expand("%")
  local args = { gotests, "-w", "-only", funame, gofile }
  if parallel then
    table.insert(args, "-parallel")
  end
  add_test(args)
end

ut.all_test = function(parallel)
  parallel = parallel or false
  local gofile = vim.fn.expand("%")
  local args = { gotests, "-all", "-w", gofile }
  if parallel then
    table.insert(args, "-parallel")
  end
  add_test(args)
end

ut.exported_test = function(parallel)
  parallel = parallel or false
  local gofile = vim.fn.expand("%")
  local args = { gotests, "-exported", "-w", gofile }
  if parallel then
    table.insert(args, "-parallel")
  end
  add_test(args)
end

return ut
