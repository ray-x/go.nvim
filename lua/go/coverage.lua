local utils = require("go.utils")
local log = utils.log
local coverage = {}
local api = vim.api
local empty = utils.empty
local M = {}
local visable = false
_GO_NVIM_CFG = _GO_NVIM_CFG
local sign_define_cache = {}

M.sign_map = { covered = "goCoverageCovered", uncover = "goCoverageUncover" }

local ns = "gocoverage_ns"

local sign_covered = M.sign_map.covered
local sign_uncover = M.sign_map.uncover

local function sign_get(bufnr, name)
  if sign_define_cache[bufnr] == nil then
    sign_define_cache[bufnr] = {}
  end
  if not sign_define_cache[bufnr][name] then
    local s = vim.fn.sign_getdefined(name)
    if not vim.tbl_isempty(s) then
      sign_define_cache[bufnr][name] = s
    end
  end
  return sign_define_cache[bufnr][name]
end

-- all windows and buffers
local function all_bufnr()
  local bufnrl = {}
  local buffers = vim.fn.getbufinfo({ bufloaded = 1, buflisted = 1 })

  for _, b in pairs(buffers) do
    if not (vim.fn.empty(b.name) == 1 or b.hidden == 1) then
      local name = b.name

      local ext = string.sub(name, #name - 2)
      if ext == ".go" then
        table.insert(bufnrl, b.bufnr)
      end
    end
  end
  return bufnrl
end -- log(bufnr, name, opts, redefine)

function M.define(bufnr, name, opts, redefine)
  if sign_define_cache[bufnr] == nil then
    sign_define_cache[bufnr] = {}
  end
  -- vim.notify(bufnr .. name .. opts .. redefine, vim.lsp.log_levels.DEBUG)
  if redefine then
    sign_define_cache[bufnr][name] = nil
    vim.fn.sign_undefine(name)
    vim.fn.sign_define(name, opts)
  elseif not sign_get(name) then
    -- log("define sign", name, vim.inspect(opts))
    vim.fn.sign_define(name, opts)
  end
  -- vim.cmd([[sign list]])
end

function M.remove(bufnr, lnum)
  if bufnr == nil then
    bufnr = vim.fn.bufnr("$")
  end
  vim.fn.sign_unplace(ns, { buffer = bufnr, id = lnum })
end

local function remove_all()
  local bufnrs = all_bufnr()
  for _, bid in pairs(bufnrs) do
    M.remove(bid)
  end
end

function M.add(bufnr, signs)
  local to_place = {}
  for _, s in pairs(signs or {}) do
    local count = s.cnt
    local stype = "goCoverageCovered"
    if count == 0 then
      stype = "goCoverageUncover"
    end

    M.define(bufnr, stype, { text = _GO_NVIM_CFG.gocoverage_sign, texthl = stype })
    for lnum = s.range.start.line, s.range["end"].line + 1 do
      log(lnum, bufnr)
      to_place[#to_place + 1] = {
        id = lnum,
        group = ns,
        name = stype,
        buffer = bufnr,
        lnum = lnum,
        priority = _GO_NVIM_CFG.gocoverage_sign_priority,
      }
    end
  end

  -- log("placing", to_place)
  vim.fn.sign_placelist(to_place)
  return to_place -- for testing
end

M.highlight = function()
  if vim.o.background == "dark" then
    vim.cmd([[hi! goCoverageCovered guifg=#107040 ctermbg=28]])
    vim.cmd([[hi! goCoverageUncover guifg=#A03040 ctermbg=52]])
  else
    vim.cmd([[hi! goCoverageCovered guifg=#70f0d0 ctermbg=120]])
    vim.cmd([[hi! goCoverageUncover guifg=#f040d0 ctermbg=223]])
  end
end

local function augroup()
  vim.cmd([[ augroup gopher.vim-coverage                                         ]])
  vim.cmd([[   au!                                                               ]])
  vim.cmd([[   au ColorScheme *    lua require'go.coverage'.highlight()          ]])
  vim.cmd([[   au BufWinLeave *.go lua require'go.coverage'remove()              ]])
  vim.cmd([[   au BufWinEnter *.go lua require'go.coverage'enable_all()          ]])
  vim.cmd([[ augroup end                                                         ]])
end

local function enable_all()
  local bufnrs = all_bufnr()
  for _, bufnr in pairs(bufnrs) do
    -- enable
    -- local bufnr = vim.fn.winbufnr(id)
    local fn = vim.fn.bufname(bufnr)

    local filename = vim.fn.fnamemodify(fn, ":t")
    if coverage[fn] ~= nil then
      M.add(bufnr, coverage[fn])
    end
  end
end

M.toggle = function(show)
  if (show == nil and visable == true) or show == false then
    -- hide
    visable = false
    remove_all()
    return
  end

  visable = true
  enable_all()
  -- end
end

local function parse_line(line)
  local m = vim.fn.matchlist(line, [[\v([^:]+):(\d+)\.(\d+),(\d+)\.(\d+) (\d+) (\d+)]])

  if empty(m) then
    return {}
  end
  local path = m[2]
  local filename = vim.fn.fnamemodify(m[2], ":t")
  return {
    file = path,
    filename = filename,
    range = {
      start = { line = tonumber(m[3]), character = tonumber(m[4]) },
      ["end"] = { line = tonumber(m[5]), character = tonumber(m[6]) },
    },
    num = tonumber(m[7]),
    cnt = tonumber(m[8]),
  }
end

if vim.tbl_isempty(vim.fn.sign_getdefined(sign_covered)) then
  vim.fn.sign_define(sign_covered, {
    text = _GO_NVIM_CFG.gocoverage_sign,
    texthl = "goCoverageCovered",
  })
end

if vim.tbl_isempty(vim.fn.sign_getdefined(sign_uncover)) then
  vim.fn.sign_define(sign_uncover, {
    text = _GO_NVIM_CFG.gocoverage_sign,
    texthl = "goCoverageUncover",
  })
end

M.read_cov = function(covfn)
  if vim.fn.filereadable(covfn) == 0 then
    vim.notify(string.format("cov file not exist: %s", covfn), vim.lsp.log_levels.WARN)
    return
  end
  local cov = vim.fn.readfile(covfn)
  -- log(vim.inspect(cov))
  for _, line in pairs(cov) do
    local cl = parse_line(line)
    if cl.filename ~= nil or cl.range ~= nil then
      -- log("cl", vim.inspect(cl))
      if coverage[cl.filename] == nil then
        coverage[cl.filename] = {}
      end
      table.insert(coverage[cl.filename], cl)
    end
  end

  local bufnrs = all_bufnr()
  log("buffers", bufnrs)
  local added = {}
  for _, bid in pairs(bufnrs) do
    -- if added[bid] == nil then
    local fn = vim.fn.bufname(bid)
    fn = vim.fn.fnamemodify(fn, ":t")
    log(bid, fn)
    M.add(bid, coverage[fn])
    visable = true
    added[bid] = true
    -- end
  end
  return coverage
end

M.run = function(...)
  local get_build_tags = require("go.gotest").get_build_tags
  -- local cov = vim.fn.tempname()
  local pwd = vim.fn.getcwd()
  local cov = pwd .. utils.sep() .. "cover.cov"

  local args = { ... }
  log(args)

  local test_runner = "go"
  if _GO_NVIM_CFG.test_runner ~= "go" then
    test_runner = _GO_NVIM_CFG.test_runner
    require("go.install").install(test_runner)
  end

  local cmd = { test_runner, "test", "-coverprofile", cov }
  local tags = ""
  local args2 = {}
  if not empty(args) then
    tags, args2 = get_build_tags(args)
    if tags ~= {} then
      vim.list_extend(cmd, tags)
    end
  end

  if not empty(args2) then
    log(args2)
    cmd = vim.list_extend(cmd, args2)
  else
    argsstr = "." .. utils.sep() .. "..."
    table.insert(cmd, argsstr)
  end

  local lines = { "" }
  coverage = {}

  log("run coverage", cmd)

  local argsstr = ""
  if _GO_NVIM_CFG.run_in_floaterm then
    cmd = table.concat(cmd, " ")
    if empty(args2) then
      cmd = cmd .. "." .. utils.sep() .. "..."
    end
    utils.log(cmd)
    local term = require("go.term").run
    term({ cmd = cmd, autoclose = false })
    return
  end

  local j = vim.fn.jobstart(cmd, {
    on_stdout = function(jobid, data, event)
      log("go coverage " .. vim.inspect(data))
      vim.list_extend(lines, data)
    end,
    on_stderr = function(job_id, data, event)
      data = utils.handle_job_data(data)
      if data == nil then
        return
      end
      vim.notify(
        "go coverage finished with message: "
          .. vim.inspect(cmd)
          .. "error: "
          .. vim.inspect(data)
          .. "job "
          .. tostring(job_id)
          .. "ev "
          .. event,
        vim.lsp.log_levels.ERROR
      )
    end,
    on_exit = function(job_id, data, event)
      if event ~= "exit" then
        vim.notify(string.format("%s %s %s", job_id, event, vim.inspect(data)), vim.lsp.log_levels.ERROR)
      end

      local lp = table.concat(lines, "\n")
      vim.notify(string.format("test finished:\n %s", lp), vim.lsp.log_levels.INFO)
      coverage = M.read_cov(cov)
      vim.fn.setqflist({}, " ", {
        title = cmd,
        lines = lines,
        efm = vim.o.efm .. [[,]] .. require("go.gotest").efm(),
      })
      vim.api.nvim_command("doautocmd QuickFixCmdPost")
      vim.fn.delete(cov)
    end,
  })
end

return M
