local M = {}

local util = require('go.utils')
local log = util.log
local sep = util.sep()
local health = vim.health
if not vim.health then
  health = require('health')
end
local tools = require('go.install').tools

local nvim_09 = vim.fn.has('nvim-0.9') == 1

local start = nvim_09 and health.start or health.report_start
local ok = nvim_09 and health.ok or health.report_ok
local error = nvim_09 and health.error or health.report_error
local warn = nvim_09 and health.warn or health.report_warn
local info = nvim_09 and health.info or health.report_info

local vfn = vim.fn

local function binary_check()
  start('Binaries')
  local no_err = true
  local go_bin = 'go'
  if vfn.executable(go_bin) == 1 then
    info(go_bin .. ' installed.')
  else
    error(go_bin .. ' is not installed.')
    no_err = false
  end
  for _, val in ipairs(tools) do
    log(val)
    if vfn.executable(val) == 1 then
      info('Tool installed: ' .. val)
    else
      warn('Missing tool: ' .. val)
      no_err = false
    end
  end

  if vfn.executable('sed') == 1 then
    info('sed installed.')
  else
    no_err = false
    warn('sed is not installed. gotests may not fully work')
  end

  if vfn.executable('curl') == 1 then
    info('curl installed.')
  else
    no_err = false
    warn('curl is not installed, gocheat will not work.')
  end

  -- check golangci-lint version
  local ret = vim.system({ 'golangci-lint', '--version' }, { text = true }):wait()
  if ret.code ~= 0 then
    no_err = false
    warn('golangci-lint is not installed, GoLint will not work.')
  end
  -- check version, sample output "golangci-lint has version v2.0.1 built ...
  local version = ret.stdout:match('v(%d+%.%d+)')
  if version then
    local major, _ = version:match('(%d+)%.(%d+)')
    print(major)
    if tonumber(major) < 2 then
      no_err = false
      warn('please update golangci-lint to v2 and update .golangci.yml')
      return
    else
      info('golangci-lint version: ' .. version)
    end
  else
    no_err = false
    warn('golangci-lint version not found, please update to v2.x.x')
    return
  end

  local required_parsers = {
    'go',
  }
  local optional_parsers = {
    'gowork',
    'gomod',
    'gosum',
    'sql',
    'gotmpl',
    'json',
    'comment',
  }

  local checkparser = function(parsers, required)
    local req = ' is required'
    if not required then
      req = ' is optional'
    end
    for _, parser in ipairs(parsers) do
      local parser_path =
        vim.api.nvim_get_runtime_file('parser' .. sep .. parser .. '.so', false)[1]
      if not parser_path then
        warn(
          'treesitter parser '
            .. parser
            .. req
            .. ' but it is not found, please Run `:TSInstallSync '
            .. parser
            .. '`'
            .. ' to install or some features may not work'
        )
        no_err = false
      else
        info('treesitter parser ' .. parser .. ' found')
      end
    end
  end
  checkparser(required_parsers, true)
  checkparser(optional_parsers, false)

  if no_err then
    ok('All binaries installed')
  else
    warn(
      'Some binaries are not installed, please check if your $HOME/go/bin or $GOBIN $exists and in your $PATH'
    )
  end
end

local function plugin_check()
  start('Go Plugin Check')

  local plugins = {
    'lspconfig',
    'nvim-treesitter',
    'guihua',
    'nvim-dap-virtual-text',
    'telescope',
  }
  local any_warn = false
  local ts_installed = false
  for _, plugin in ipairs(plugins) do
    local pi = util.load_plugin(plugin)
    if pi ~= nil then
      ok(string.format('%s: plugin is installed', plugin))
      if plugin == 'nvim-treesitter' then
        ts_installed = true
      end
    else
      any_warn = true
      warn(string.format('%s: not installed/loaded', plugin))
    end
  end
  if ts_installed then
    local _info = require('nvim-treesitter.info').installed_parsers()
    if vim.tbl_contains(_info, 'go') then
      ok('nvim-treesitter-go is installed')
    else
      warn('nvim-treesitter-go is not installed, Please run TSInstall go to install')
      any_warn = true
    end
  end
  plugins = {
    ['nvim-dap'] = 'dap',
    ['nvim-dap-ui'] = 'dapui',
  }
  for name, req in pairs(plugins) do
    local pi = util.load_plugin(name, req)
    if pi ~= nil then
      ok(string.format('%s: plugin is installed', name))
    else
      any_warn = true
      warn(string.format('%s: not installed/loaded', name))
    end
  end

  if any_warn then
    warn('Not all plugin installed')
  else
    ok('All plugin installed')
  end
end

-- check if GOBIN is in PATH
local function path_check(gobin)
  local path = os.getenv('PATH')
  if gobin == '' or vim.v.shell_error ~= 0 then
    util.error('GOBIN is not set')
    return false
  end
  gobin = gobin or 'notfound'
  -- check GOBIN inside PATH
  if not vim.tbl_contains(vim.split(path, ':', { trimempty = true }), gobin) then
    return false
  end
  return true
end

local function goenv()
  local env = {}
  local raw = vim.fn.system('go env')
  for key, value in string.gmatch(raw, '([^=]+)=[\'"]([^\'"]*)[\'"]\n') do
    env[key] = #value > 0 and value or nil
  end
  return env
end

local function env_check()
  local env = goenv()
  local keys = { 'GOROOT', 'GOBIN' }
  local any_warn = false
  for _, key in ipairs(keys) do
    if env[key] == nil then
      info(string.format('%s is not set', key))
      any_warn = true
    else
      ok(string.format('%s is set', key))
    end
  end
  if any_warn then
    info('Not all environment variables set')
  else
    ok('All environment variables set')
  end
  if not path_check(env['GOBIN']) then
    warn('GOBIN is not in PATH')
  else
    ok('GOBIN is in PATH')
  end
end

function M.check()
  if vim.fn.has('nvim-0.9') == 0 then
    warn('Suggested neovim version 0.9 or higher')
  end

  binary_check()
  plugin_check()
  env_check()
end

return M
