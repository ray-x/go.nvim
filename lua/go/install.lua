local uv = vim.loop
local DIR_SEP = package.config:sub(1, 1)
local utils = require('go.utils')
local log = utils.log

local url = {
  gofumpt = 'mvdan.cc/gofumpt',
  golines = 'github.com/segmentio/golines',
  ['golangci-lint'] = 'github.com/golangci/golangci-lint/cmd/golangci-lint',
  goimports = 'golang.org/x/tools/cmd/goimports',
  gomodifytags = 'github.com/fatih/gomodifytags',
  gopls = 'golang.org/x/tools/gopls',
  gotests = 'github.com/cweill/gotests/...',
  iferr = 'github.com/koron/iferr',
  callgraph = 'golang.org/x/tools/cmd/callgraph',
  impl = 'github.com/josharian/impl',
  fillswitch = 'github.com/davidrjenni/reftools/cmd/fillswitch',
  dlv = 'github.com/go-delve/delve/cmd/dlv',
  ginkgo = 'github.com/onsi/ginkgo/v2/ginkgo',
  richgo = 'github.com/kyoh86/richgo',
  gotestsum = 'gotest.tools/gotestsum',
  mockgen = 'go.uber.org/mock/mockgen',
  ['json-to-struct'] = 'github.com/tmc/json-to-struct',
  gojsonstruct = 'github.com/twpayne/go-jsonstruct/v3/cmd/gojsonstruct',
  gomvp = 'github.com/abenz1267/gomvp',
  govulncheck = 'golang.org/x/vuln/cmd/govulncheck',
  ['go-enum'] = 'github.com/abice/go-enum',
  gonew = 'golang.org/x/tools/cmd/gonew',
}

local tools = {}
for tool, _ in pairs(url) do
  table.insert(tools, tool)
end

local function is_installed(bin)
  if utils.installed_tools[bin] then
    return true
  end

  local sep = utils.sep2()
  local ext = utils.ext()

  if utils.goenv_mode() then
    local cwd = vim.fn.getcwd()
    local cmd = 'cd ' .. cwd .. ' && goenv which ' .. bin .. ' 2>&1'

    local status = os.execute(cmd)

    if status == 0 then
      utils.installed_tools[bin] = true
      return true
    end
    return false
  end

  if vim.fn.executable(bin) == 1 then
    utils.installed_tools[bin] = true
    return true
  end

  local env_path = os.getenv('PATH')
  local base_paths = vim.split(env_path, sep, { trimempty = true })

  for _, value in pairs(base_paths) do
    if uv.fs_stat(value .. DIR_SEP .. bin .. ext) then
      utils.installed_tools[bin] = true
      return true
    end
  end
  return false
end

local function go_install_sync(pkg)
  local u = url[pkg]
  if u == nil then
    vim.notify(
      'command ' .. pkg .. ' not supported, please update install.lua, or manually install it',
      vim.log.levels.WARN
    )
    return
  end

  u = u .. '@latest'
  local setup = { 'go', 'install', u }
  if utils.goenv_mode() then
    setup = { 'goenv', 'exec', 'go', 'install', u }
  end
  local output = vim.fn.system(table.concat(setup, ' '))
  if vim.v.shell_error ~= 0 then
    vim.notify('install ' .. pkg .. ' failed: ' .. output, vim.log.levels.ERROR)
  else
    vim.notify(
      'install ' .. pkg .. ' installed to ' .. (vim.env['GOBIN'] or vim.fn.system('go env GOBIN')),
      vim.log.levels.INFO
    )
  end
end

-- async install pkg
local function go_install(pkg)
  local u = url[pkg]
  if u == nil then
    vim.notify(
      'command ' .. pkg .. ' not supported, please update install.lua, or manually install it',
      vim.log.levels.WARN
    )
    return
  end

  u = u .. '@latest'
  local setup = { 'go', 'install', u }
  if utils.goenv_mode() then
    setup = { 'goenv', 'exec', 'go', 'install', u }
  end

  vim.fn.jobstart(setup, {
    on_stdout = function(_, data, _)
      log(setup)
      if type(data) == 'table' and #data > 0 then
        data = table.concat(data, ' ')
      end

      local msg = 'install ' .. u .. ' finished'
      if #data > 1 then
        msg = msg .. data
      end
      vim.notify(msg, vim.log.levels.INFO)
    end,
  })
end

local function install(bin, verbose)
  if verbose == nil and _GO_NVIM_CFG then
    verbose = _GO_NVIM_CFG.verbose
  end
  if not is_installed(bin) then
    go_install(bin)
    vim.notify('installing ' .. bin, vim.log.levels.INFO)
  end
  return is_installed(bin)
end

local function update(bin)
  go_install(bin)
end

local function update_sync(bin)
  go_install_sync(bin)
end

local function install_all()
  for key, _ in pairs(url) do
    install(key)
  end
end

local function install_all_sync()
  for key, _ in pairs(url) do
    if not is_installed(key) then
      vim.notify('installing ' .. key, vim.log.levels.INFO)
      go_install_sync(key)
    end
  end
end

local function update_all()
  for key, _ in pairs(url) do
    update(key)
  end
end

local function update_all_sync()
  for key, _ in pairs(url) do
    update_sync(key)
  end
end

return {
  install = install,
  update = update,
  install_all = install_all,
  install_all_sync = install_all_sync,
  update_all = update_all,
  update_all_sync = update_all_sync,
  tools = tools,
}
