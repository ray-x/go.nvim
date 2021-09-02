local uv = vim.loop
local DIR_SEP = package.config:sub(1, 1)

local url = {
  gofumpt = "mvdan.cc/gofumpt",
  gofumports = "mvdan.cc/gofumpt",
  golines = "github.com/segmentio/golines",
  goimports = "golang.org/x/tools/cmd/goimports",
  gorename = "golang.org/x/tools/cmd/gorename",
  gomodifytags = "github.com/fatih/gomodifytags",
  gotests = "github.com/cweill/gotests",
  iferr = 'github.com/koron/iferr',
  impl = 'github.com/josharian/impl',
  fillstruct = 'github.com/davidrjenni/reftools/cmd/fillstruct',
  fixplurals = 'github.com/davidrjenni/reftools/cmd/fixplurals',
  fillswitch = 'github.com/davidrjenni/reftools/cmd/fillswitch'
}

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
    print("command " .. pkg .. " not supported, please update install.lua, or manually install it")
    return
  end

  u = u .. "@latest"
  local setup = {"go", "install", u}

  vim.fn.jobstart(setup, {
    on_stdout = function(c, data, name)
      print(data)
    end
  })
end

local function install(bin)
  if not is_installed(bin) then
    print("installing " .. bin)
    go_install(bin)
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

return {install = install, update = update, install_all = install_all}
