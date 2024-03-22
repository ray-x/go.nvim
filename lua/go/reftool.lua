local reftool = {}

local utils = require('go.utils')
local log = utils.log
local vfn = vim.fn

local function insert_result(result)
  local curpos = vfn.getcurpos()
  local goto_l = string.format('goto %d', result['start'] + 1)
  vim.cmd(goto_l)
  local inserts = result.code
  inserts = vim.split(inserts, '\n')
  local change = string.format('normal! %ds%s', result['end'] - result.start, inserts[1])
  vim.cmd(change)
  vim.cmd('startinsert!')
  log(change)
  local curline = curpos[2]
  for i = 2, #inserts do
    log('append ', curline, inserts[i])
    vfn.append(curline, inserts[i])
    curline = curline + 1
  end

  vim.cmd('stopinsert!')
  vim.cmd('write')
  -- format(#inserts, curpos)
  vfn.setpos('.', curpos)
  require('go.format').gofmt()
end

-- can only be fillstruct and fillswitch
local function fill(cmd)
  if vim.tbl_contains({ 'fillstruct', 'fillswitch' }, cmd) == false then
    error('reftool fill cmd not supported: ' .. cmd)
    return
  end
  require('go.install').install(cmd)

  log(cmd)
  local file = vfn.expand('%:p')
  local line = vfn.line('.')
  -- local run = string.format("%s -file=%s -line=%d 2>/dev/null", cmd, file, line)
  local farg = string.format('-file=%s', file)
  local larg = string.format('-line=%d', line)
  local args = { cmd, farg, larg, '2>/dev/null' }
  log(args)
  vfn.jobstart(args, {
    on_stdout = function(_, str, _)
      log(str)
      if #str < 2 then
        log('reftools', cmd, 'finished with no result')
        return
      end
      local json = vfn.json_decode(str)
      if #json == 0 then
        vim.notify('reftools ' .. cmd .. ' finished with no result', vim.log.levels.DEBUG)
      end

      local result = json[1]
      insert_result(result)
    end,
  })
end

local function gopls_fillstruct()
  log('fill struct with gopls')
  require('go.lsp').codeaction('apply_fix', 'refactor.rewrite')
end

function reftool.fillstruct()
  if _GO_NVIM_CFG.fillstruct == 'gopls' then
    gopls_fillstruct()
  else
    fill('fillstruct')
  end
end

reftool.fillswitch = function()
  fill('fillswitch')
end

return reftool
