-- gonkgo test
local M = {}
local utils = require("go.utils")
local log = utils.log
local function get_build_tags(args)
  local tags = {}

  if args ~= nil then
    table.insert(tags, args)
  end

  if _GO_NVIM_CFG.build_tags ~= "" then
    table.insert(tags, _GO_NVIM_CFG.build_tags)
  end

  if #tags == 0 then
    return ""
  end

  return [[-tags\ ]] .. table.concat(tags, ",")
end

local function find_describe(lines)
  local describe
  local pat = [[Describe%(%".*%",%sfunc]]
  local despat = [[%(%".*%"]]
  for i = #lines, 1, -1 do
    local line = lines[i]
    local fs, fe = string.find(line, pat)
    if fs then
      line = string.sub(line, fs + #"Describe", fe)
      fs, fe = string.find(line, despat)
      if fs ~= nil then
        if fe - fs <= 2 then
          return nil
        end
        describe = line:sub(fs + 2, fe - 1)
        return describe
      end
    end
  end
  return nil
end

-- print(find_describe({
--   [[ var _ = Describe("Integration test hourly data EstimateCombinedRules without ws ID", func() { ]]
-- }))

-- Run with ginkgo Description
M.test_fun = function(...)
  local args = { ... }
  log(args)
  local fpath = vim.fn.expand("%:p:h")

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1

  local fnum = row - 3
  if fnum < 0 then
    fnum = 0
  end
  local lines = vim.api.nvim_buf_get_lines(0, fnum, row + 1, true)

  local describe = find_describe(lines)
  log("testing: ", describe)
  if describe == nil then
    log("failed to find test function, test file instead")
    return M.test_file(args)
  end
  local test_runner = "ginkgo"
  require("go.install").install(test_runner)

  local cmd = { test_runner, [[ --focus=']] .. describe .. [[']], get_build_tags(args), fpath }
  log(cmd)
  if _GO_NVIM_CFG.run_in_floaterm then
    local term = require("go.term").run
    term({ cmd = cmd, autoclose = false })
    return
  end
  local cmd = [[setl makeprg=]] .. test_runner
  vim.cmd(cmd)

  local args = { [[ --focus=']] .. describe .. [[']], get_build_tags(args), fpath }
  require("go.asyncmake").make(unpack(args))
  utils.log("test cmd", cmd)
  return true
end

M.test_file = function(...)
  local args = { ... }
  log(args)
  -- require sed
  local fpath = vim.fn.expand("%:p:h")
  local fname = vim.fn.expand("%:p")

  log(fpath, fname)

  local workfolder = utils.work_path()
  fname = "." .. fname:sub(#workfolder + 1)

  log(workfolder, fname)
  local test_runner = "ginkgo"
  require("go.install").install(test_runner)

  local cmd_args = {
    [[--regexScansFilePath=true]],
    get_build_tags(args),
    [[ --focus ]],
    fname,
    fpath,
  }

  if _GO_NVIM_CFG.run_in_floaterm then
    table.insert(cmd_args, 1, test_runner)
    utils.log(args)
    local term = require("go.term").run
    term({ cmd = cmd_args, autoclose = false })
    return
  end

  fname = utils.relative_to_cwd(fname) .. [[\ ]]
  vim.cmd("setl makeprg=ginkgo")
  utils.log("test cmd", cmd_args)
  require("go.asyncmake").make(unpack(cmd_args))
end

return M
