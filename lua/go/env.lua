-- env fileread
local util = require("go.utils")
local log = util.log
local M = {}
local vfn = vim.fn
local sep = require("go.utils").sep()

function M.envfile(f)
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vfn.getcwd()
  local goenv = workfolder .. sep .. (f or ".env")

  if vfn.filereadable(goenv) == 1 then
    return goenv
  end
end

function M.append(env, val)
  local oldval = vfn.getenv(env)
  if val == vim.NIL or string.find(oldval, val) then
    return
  end
  local newval = oldval .. ":" .. val
  vfn.setenv(env, newval)
end

function M.load_env(env, setToEnv)
  setToEnv = setToEnv or true
  env = env or M.envfile()
  if vfn.filereadable(env) == 0 then
    return false
  end
  local lines = util.lines_from(env)
  local envs = {}
  for _, line in ipairs(lines) do
    for k, v in string.gmatch(line, "([%w_]+)=([%w%c%p%z]+)") do
      envs[k] = v
    end
  end

  log(envs)
  if setToEnv then
    for key, val in pairs(envs) do
      vfn.setenv(key, val)
    end
  end

  return envs
end

return M
