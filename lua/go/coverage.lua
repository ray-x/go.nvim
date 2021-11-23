local utils = require('go.utils')
local log = utils.log
local coverage = {}
local api = vim.api
local M = {}
local visable = false
_GO_NVIM_CFG = _GO_NVIM_CFG
local sign_define_cache = {}

M.sign_map = {covered = 'goCoverageCovered', uncover = 'goCoverageUncover'}

local ns = 'gocoverage_ns'

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
local function all_win_bufnr()
  local winids = {}
  local bufnrl = {}
  for i = 1, vim.fn.tabpagenr('$') do
    for j = 1, vim.fn.tabpagewinnr(i, '$') do
      local winid = vim.fn.win_getid(j, i)
      local bufnr = vim.fn.winbufnr(winid)
      if vim.fn.buflisted(bufnr) then
        local fn = vim.fn.bufname(bufnr)
        local ext = string.sub(fn, #fn - 2)
        if ext == '.go' then
          table.insert(winids, winid)
          table.insert(bufnrl, bufnr)
        end
      end
    end
  end
  return winids, bufnrl
end

function M.define(bufnr, name, opts, redefine)
  if sign_define_cache[bufnr] == nil then
    sign_define_cache[bufnr] = {}
  end
  -- log(bufnr, name, opts, redefine)
  -- print(bufnr, name, opts, redefine)
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
    bufnr = vim.fn.bufnr('$')
  end
  vim.fn.sign_unplace(ns, {buffer = bufnr, id = lnum})
end

local function remove_all()
  local _, bufnrs = all_win_bufnr()
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

    M.define(bufnr, stype, {text = _GO_NVIM_CFG.gocoverage_sign, texthl = stype})
    for lnum = s.range.start.line, s.range['end'].line + 1 do
      to_place[#to_place + 1] = {
        id = lnum,
        group = ns,
        name = stype,
        buffer = bufnr,
        lnum = lnum,
        priority = _GO_NVIM_CFG.gocoverage_sign_priority
      }
    end
  end

  -- log("placing", to_place)
  vim.fn.sign_placelist(to_place)
  return to_place -- for testing
end

M.highlight = function()
  if vim.o.background == 'dark' then
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
  local _, bufnrs = all_win_bufnr()
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

  if m == nil or #m == 0 then
    return {}
  end
  local path = m[2]
  local filename = vim.fn.fnamemodify(m[2], ":t")
  return {
    file = path,
    filename = filename,
    range = {
      start = {line = tonumber(m[3]), character = tonumber(m[4])},
      ['end'] = {line = tonumber(m[5]), character = tonumber(m[6])}
    },
    num = tonumber(m[7]),
    cnt = tonumber(m[8])
  }
end

if vim.tbl_isempty(vim.fn.sign_getdefined(sign_covered)) then
  vim.fn.sign_define(sign_covered, {
    text = _GO_NVIM_CFG.gocoverage_sign,
    texthl = "goCoverageCovered"
  })
end

if vim.tbl_isempty(vim.fn.sign_getdefined(sign_uncover)) then
  vim.fn.sign_define(sign_uncover, {
    text = _GO_NVIM_CFG.gocoverage_sign,
    texthl = "goCoverageUncover"
  })
end

M.read_cov = function(covfn)
  local cov = vim.fn.readfile(covfn)
  -- log(vim.inspect(cov))
  for _, line in pairs(cov) do
    local cl = parse_line(line)
    if cl.file == nil or cl.range == nil then
      goto continue
    end
    -- log("cl", vim.inspect(cl))
    if coverage[cl.filename] == nil then
      coverage[cl.filename] = {}
    end
    table.insert(coverage[cl.filename], cl)
    ::continue::
  end

  local _, bufnrs = all_win_bufnr()
  log("buffers", bufnrs)
  for _, bid in pairs(bufnrs) do
    local bufnr = vim.fn.winbufnr(bid)
    local fn = vim.fn.bufname(bufnr)

    fn = vim.fn.fnamemodify(fn, ":t")

    M.add(bid, coverage[fn])
    visable = true
  end
  return coverage
end

M.run = function(...)
  local get_build_tags = require('go.gotest').get_build_tags
  -- local cov = vim.fn.tempname()
  local cov = vim.fn.expand("%:p:h") .. "/cover.cov"

  local args = {...}
  log(args)

  local test_runner = 'go'
  if _GO_NVIM_CFG.test_runner ~= 'go' then
    test_runner = _GO_NVIM_CFG.test_runner
    require("go.install").install(test_runner)
  end

  local cmd = {test_runner, 'test', '-coverprofile', cov}
  local tags = ''
  local args2 = {}
  if args ~= nil and args ~= {} then
    tags, args2 = get_build_tags(args)
    if tags ~= '' then
      vim.list_extend(cmd, {tags})
    end
    vim.list_extend(cmd, args2)
  end

  local lines = {""}
  coverage = {}

  if args == {} then
    -- pkg provided?
    table.insert(cmd, "." .. utils.spe() .. vim.fn.expand('%:.:h'))
  end

  log("run coverage", cmd)

  local argsstr = ''
  if _GO_NVIM_CFG.run_in_floaterm then
    cmd = table.concat(cmd, " ")
    if args2 == {} then
      cmd = cmd .. '.' .. utils.sep() .. '...'
    end
    utils.log(cmd)
    local term = require('go.term').run
    term({cmd = cmd, autoclose = false})
    return
  end

  local j = vim.fn.jobstart(cmd, {
    on_stdout = function(jobid, data, event)
      log("go coverage " .. vim.inspect(data))
      vim.list_extend(lines, data)
    end,
    on_stderr = function(job_id, data, event)
      print("go coverage finished with message: " .. vim.inspect(tag) .. "error: " .. vim.inspect(data) .. "job"
                .. tostring(job_id) .. "ev" .. event)
    end,
    on_exit = function(job_id, data, event)
      if event ~= "exit" then
        print(job_id, event, vim.inspect(data))
      end
      log("test finished")
      coverage = M.read_cov(cov)

      -- log("coverage", coverage)

      vim.fn.delete(cov)
      vim.fn.setqflist({}, " ", {
        title = cmd,
        lines = lines
        -- efm = vim.api.nvim_buf_get_option(bufnr, "errorformat")
      })
      vim.api.nvim_command("doautocmd QuickFixCmdPost")
      vim.cmd([[copen]])
    end
  })
end

return M
