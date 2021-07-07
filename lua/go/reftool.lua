local reftool = {}
local fn, api = vim.fn, vim.api

local function format(text, pos)
  if text == nil then
    return
  end
  local lines = fn.split(text, "\n")
  if #lines > 0 then
    fn.setpos(".", pos)
    local cmd = string.format("normal j$d==", #lines - 1)
    vim.cmd(cmd)
  end
end

-- can only be fillstruct and fillswitch
local function fill(cmd)
  return function()
    if cmd ~= 'fillstruct' and cmd ~= 'fillswitch' then
      error('cmd not supported by go.nvim', cmd)
    end
    require("go.install").install(cmd)

    local file = fn.expand("%:p")
    local line = fn.line(".")
    local run = string.format("%s -file=%s -line=%d 2>/dev/null", cmd, file, line)
    -- print(run)
    -- local str = fn.system(run)
    local farg = string.format('-file=%s', file)
    local larg = string.format('-line=%d', line)
    local args = {cmd, farg, larg, '2>/dev/null' }
    vim.fn.jobstart(
    args,
    {
      on_stdout = function(jobid, str, event)
        -- print(str)
        if #str == 0 then print('reftools', cmd, 'finished with no result') end
        local json = fn.json_decode(str)
        if #json == 0 then print('reftools', cmd, 'finished with no result') end
        local result = json[1]
        local curpos = fn.getcurpos()
        local goto = string.format('goto %d', result.start + 1)
        local change = string.format('normal! %ds%s', result['end'] - result.start, result.code)
        vim.cmd(goto)
        vim.cmd(change)
        format(result.code, curpos)
        fn.setpos('.', curpos)
        vim.lsp.buf.formatting()
      end
    })
  end
end

function reftool.fixplurals()
  local fx = "fixplurals"
  require("go.install").install(fx)
  local curdir = fn.getcwd()
  local filedir = fn.expand("%:p:h")
  local setup = {fx, ","}
  local cdpkg = string.format("exec cd %s", filedir)
  local cdback = string.format("exec cd %s", curdir)
  vim.cmd(cdpkg)
  vim.fn.jobstart(
    setup,
    {
      on_stdout = function(jobid, data, event)
        vim.cmd(cdback)
        -- print("fixplurals finished  ")
      end
    }
  )
end

reftool.fillstruct = fill('fillstruct')
reftool.fillswitch = fill('fillswitch')

return reftool
