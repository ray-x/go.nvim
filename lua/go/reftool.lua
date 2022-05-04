local reftool = {}

local utils = require("go.utils")
local log = utils.log
local fn = vim.fn

local function insert_result(result)
  local curpos = fn.getcurpos()
  local goto_l = string.format("goto %d", result["start"] + 1)
  vim.cmd(goto_l)
  local inserts = result.code
  inserts = vim.split(inserts, "\n")
  local change = string.format("normal! %ds%s", result["end"] - result.start, inserts[1])
  vim.cmd(change)
  vim.cmd("startinsert!")
  log(change)
  local curline = curpos[2]
  for i = 2, #inserts do
    log("append ", curline, inserts[i])
    vim.fn.append(curline, inserts[i])
    curline = curline + 1
  end

  vim.cmd("stopinsert!")
  vim.cmd("write")
  -- format(#inserts, curpos)
  fn.setpos(".", curpos)
  vim.lsp.buf.format({ async = true })
end

-- can only be fillstruct and fillswitch
local function fill(cmd)
  if cmd ~= "fillstruct" and cmd ~= "fillswitch" then
    log(cmd, "not found")
    error("cmd not supported by go.nvim", cmd)
  end
  require("go.install").install(cmd)

  log(cmd)
  local file = fn.expand("%:p")
  local line = fn.line(".")
  local run = string.format("%s -file=%s -line=%d 2>/dev/null", cmd, file, line)
  local farg = string.format("-file=%s", file)
  local larg = string.format("-line=%d", line)
  local args = { cmd, farg, larg, "2>/dev/null" }
  log(args)
  vim.fn.jobstart(args, {
    on_stdout = function(jobid, str, event)
      log(str)
      if #str < 2 then
        log("reftools", cmd, "finished with no result")
        return
      end
      local json = fn.json_decode(str)
      if #json == 0 then
        vim.notify("reftools " .. cmd .. " finished with no result", vim.lsp.log_levels.DEBUG)
      end

      local result = json[1]
      insert_result(result)
    end,
  })
end

local function gopls_fillstruct(timeout_ms)
  log("fill struct with gopls")
  local codeaction = require("go.lsp").codeaction
  codeaction("fill_struct", "refactor.rewrite", timeout_ms)
end

function reftool.fillstruct()
  if _GO_NVIM_CFG.fillstruct == "gopls" then
    gopls_fillstruct(1000)
  else
    log("fillstruct")
    fill("fillstruct")
  end
end

reftool.fillswitch = function()
  fill("fillswitch")
end

return reftool
