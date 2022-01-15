local uv = vim.loop
local DIR_SEP = package.config:sub(1, 1)
local log = require("go.utils").log

local url = {
  gofumpt = "mvdan.cc/gofumpt",
  golines = "github.com/segmentio/golines",
  ["golangci-lint"] = "github.com/golangci/golangci-lint/cmd/golangci-lint",
  goimports = "golang.org/x/tools/cmd/goimports",
  gorename = "golang.org/x/tools/cmd/gorename",
  gomodifytags = "github.com/fatih/gomodifytags",
  gopls = "golang.org/x/tools/gopls",
  gotests = "github.com/cweill/gotests",
  iferr = "github.com/koron/iferr",
  impl = "github.com/josharian/impl",
  fillstruct = "github.com/davidrjenni/reftools/cmd/fillstruct",
  fixplurals = "github.com/davidrjenni/reftools/cmd/fixplurals",
  fillswitch = "github.com/davidrjenni/reftools/cmd/fillswitch",
  dlv = "github.com/go-delve/delve/cmd/dlv",
  ginkgo = "github.com/onsi/ginkgo/ginkgo",
  richgo = "github.com/kyoh86/richgo",
}

local tools = {}
for tool, _ in pairs(url) do
  table.insert(tools, tool)
end
local function is_installed(bin)
  local env_path = os.getenv("PATH")
  local base_paths = vim.split(env_path, ":", true)

  for key, value in pairs(base_paths) do
    if uv.fs_stat(value .. DIR_SEP .. bin) then
      return true
    end
  end
  return false
end

local function go_install(pkg)
  local u = url[pkg]
  if u == nil then
    vim.notify(
      "command " .. pkg .. " not supported, please update install.lua, or manually install it",
      vim.lsp.log_levels.WARN
    )
    return
  end

  u = u .. "@latest"
  local setup = { "go", "install", u }

  vim.fn.jobstart(setup, {
    on_stdout = function(c, data, name)
      log(setup)
      if type(data) == "table" and #data > 0 then
        data = table.concat(data, " ")
      end

      local msg = "install " .. u .. " finished"
      if #data > 1 then
        msg = msg .. data
      end
      vim.notify(msg, vim.lsp.log_levels.DEBUG)
    end,
  })
end

local function install(bin, verbose)
  if not is_installed(bin) then
    vim.notify("installing " .. bin, vim.lsp.log_levels.INFO)
    go_install(bin)
  else
    if verbose then
      vim.notify(bin .. " already install, use GoUpdateBinary to update it", vim.lsp.log_levels.INFO)
    end
  end
end

local function update(bin)
  go_install(bin)
end

local function install_all()
  for key, value in pairs(url) do
    install(key)
  end
end

local function update_all()
  for key, value in pairs(url) do
    update(key)
  end
end

return {
  install = install,
  update = update,
  install_all = install_all,
  update_all = update_all,
  tools = tools,
}
