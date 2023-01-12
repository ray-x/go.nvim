local M = {}

local util = require("go.utils")
local log = util.log

local health = vim.health
if not vim.health then
  health = require("health")
end
local tools = require("go.install").tools

local start = health.report_start
local ok = health.report_ok
local error = health.report_error
local warn = health.report_warn
local info = health.report_info
local vfn = vim.fn

local function binary_check()
  health.report_start("Binaries")
  local no_err = true
  local go_bin = "go"
  if vfn.executable(go_bin) == 1 then
    info(go_bin .. " installed.")
  else
    error(go_bin .. " is not installed.")
    no_err = false
  end
  for _, val in ipairs(tools) do
    log(val)
    if vfn.executable(val) == 1 then
      info("Tool installed: " .. val)
    else
      warn("Missing tool: " .. val)
      no_err = false
    end
  end


  if vfn.executable('sed') == 1 then
    info("sed installed. gotests may not fully work")
  else
    no_err = false
    warn("sed is not installed.")
  end

  if vfn.executable('curl') == 1 then
    info("curl installed.")
  else
    no_err = false
    warn("curl is not installed, gocheat will not work.")
  end

  local parser_path = vim.api.nvim_get_runtime_file('parser' .. sep .. 'go.so', false)[1]
  if not parser_path then
    warn('go treesitter parser not found, please Run `:TSInstallSync go`')
    no_err = false
  end

  if no_err then
    ok("All binaries installed")
  else
    warn("Some binaries are not installed, please check if your $HOME/go/bin or $GOBIN $exists and in your $PATH")
  end
end

local function plugin_check()
  start("Go Plugin Check")

  local plugins = {
    "lspconfig",
    "nvim-treesitter",
    "guihua",
    "nvim-dap-virtual-text",
    "telescope",
  }
  local any_warn = false
  local ts_installed = false
  for _, plugin in ipairs(plugins) do
    local pi = util.load_plugin(plugin)
    if pi ~= nil then
      ok(string.format("%s: plugin is installed", plugin))
      if plugin == "nvim-treesitter" then
        ts_installed = true
      end
    else
      any_warn = true
      warn(string.format("%s: not installed/loaded", plugin))
    end
  end
  if ts_installed then
  local _info = require("nvim-treesitter.info").installed_parsers()
  if vim.tbl_contains(_info, "go") then
    ok("nvim-treesitter-go is installed")
  else
    warn("nvim-treesitter-go is not installed, Please run TSInstall go to install")
    any_warn = true
  end
  end
  plugins = {
    ["nvim-dap"] = "dap",
    ["nvim-dap-ui"] = "dapui",
  }
  for name, req in pairs(plugins) do
    local pi = util.load_plugin(name, req)
    if pi ~= nil then
      ok(string.format("%s: plugin is installed", name))
    else
      any_warn = true
      warn(string.format("%s: not installed/loaded", name))
    end
  end

  if any_warn then
    warn("Not all plugin installed")
  else
    ok("All plugin installed")
  end
end

function env_check()
  local envs = {'GOPATH', 'GOROOT', 'GOBIN'}
  local any_warn = false
  for _, env in ipairs(envs) do
    if vim.env[env] == nil then
      info(string.format("%s is not set", env))
      any_warn = true
    else
      ok(string.format("%s is set", env))
    end
  end
  if any_warn then
    info("Not all enviroment variables set")
  else
    ok("All enviroment variables set")
  end
end

function M.check()
  binary_check()
  plugin_check()
  env_check()
end

return M
