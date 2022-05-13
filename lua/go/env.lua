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
  env = env or M.envfile()
  if vim.fn.filereadable(env) == 0 then
    return false
  end
  local e = io.open(env, "r")
  local lines = util.lines_from(e)
  local envs = {}
  for _, line in ipairs(lines) do
    for k, v in string.gmatch(line, "(%w+)=(%w+)") do
      envs[k] = v
    end
  end

  if setToEnv then
    for key, val in pairs(envs) do
      vim.fn.setenv(key, val)
    end
  end

  return envs
end

M.load_project()

return M
