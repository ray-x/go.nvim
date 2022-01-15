local M = {}

local util = require("go.utils")
local log = util.log
local health = require("health")
local tools = require("go.install").tools

local start = health.report_start
local ok = health.report_ok
local error = health.report_error
local warn = health.report_warn
local info = health.report_info

local function binary_check()
  health.report_start("Binaries")
  local no_err = true
  local go_bin = _GO_NVIM_CFG.go or "go"
  if vim.fn.executable(go_bin) == 1 then
    info(go_bin .. " installed.")
  else
    error(go_bin .. " is not installed.")
    no_err = false
  end
  for _, val in ipairs(tools) do
    log(val)
    if vim.fn.executable(val) == 1 then
      info("Tool installed: " .. val)
    else
      warn("Missing tool: " .. val)
    end
  end
  if no_err then
    ok("All binaries installed")
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
  for _, plugin in ipairs(plugins) do
    local pi = util.load_plugin(plugin)
    if pi ~= nil then
      ok(string.format("%s: plugin is installed", plugin))
    else
      any_warn = true
      warn(string.format("%s: not installed/loaded", plugin))
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

function M.check()
  binary_check()
  plugin_check()
end

return M
