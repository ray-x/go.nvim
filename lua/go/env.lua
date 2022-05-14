-- env fileread
local util = require("go.utils")
local log = util.log
local M = {}
local sep = require("go.utils").sep()

function M.envfile(f)
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vim.fn.getcwd()
  local goenv = workfolder .. sep .. (f or ".env")

  if vim.fn.filereadable(goenv) == 1 then
    return goenv
  end
end

function M.load_env(env, setToEnv)
  setToEnv = setToEnv or true
  env = env or M.envfile()
  if vim.fn.filereadable(env) == 0 then
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
      vim.fn.setenv(key, val)
    end
  end

  return envs
end

return M
