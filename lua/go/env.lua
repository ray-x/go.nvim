-- env fileread
local util = require('go.utils')
local log = util.log
local M = {}
local vfn = vim.fn
local sep = require('go.utils').sep()

-- get env file name with path
function M.envfile(f)
  if vfn.filereadable(f) == 1 then
    return f
  end
  local workfolder = util.get_gopls_workspace_folders()[1] or vfn.getcwd()
  local goenv = workfolder .. sep .. (f or '.env')

  if vfn.filereadable(goenv) == 1 then
    return goenv
  end
end

function M.append(env, val)
  local oldval = vfn.getenv(env)
  if val == vim.NIL or string.find(oldval, val) then
    return
  end
  if oldval == vim.NIL then
    util.notify('failed to get env var: ' .. env)
  end
  if oldval:find(val) then -- presented
    return
  end
  local newval = oldval .. ':' .. val
  vfn.setenv(env, newval)
end

-- load env from env file
-- if setToEnv is false, just return the envs
function M.load_env(envfile, setToEnv)
  setToEnv = setToEnv or true
  local t = type(envfile)
  if t == 'nil' then
    -- load from .env
    envfile = M.envfile()
  elseif t == 'string' then
    envfile = M.envfile(envfile)
  end
  if vfn.filereadable(envfile) == 0 then
    return false
  end
  local lines = util.lines_from(envfile)
  local envs = {}
  for _, line in ipairs(lines) do
    for k, v in string.gmatch(line, '([%w_]+)=([%w%c%p%z]+)') do
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

-- best effort to enabl $GOBIN
function M.setup()
  local home = 'HOME'
  if util.is_windows() then
    home = 'USERPROFILE'
  end
  local gohome = vfn.getenv('GOHOME')
  local gobin = vfn.getenv('GOBIN')
  local user_home = vfn.getenv(home)
  if gobin == vim.NIL then
    if gohome == vim.NIL then
      if user_home == vim.NIL then
        util.notify('failed to setup $GOBIN')
        return
      end
      gobin = user_home .. sep .. 'go' .. sep .. 'bin'
    else
      local gohome1 = vim.split(gohome, ':')[1]
      gobin = gohome1 .. require('go.utils').sep() .. 'bin'
      vfn.setenv('GOBIN', gobin)
    end
  end
  M.append('PATH', gobin)
end

return M
