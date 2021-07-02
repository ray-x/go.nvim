local url = {
  gofumpt      = "mvdan.cc/gofumpt",
  gofumports   = "mvdan.cc/gofumpt",
  golines      = "github.com/segmentio/golines",
  gomodifytags = "github.com/fatih/gomodifytags",
  gotsts       = "github.com/cweill/gotests",
  iferr        = 'github.com/koron/iferr',
  fillstruct   = 'github.com/davidrjenni/reftools/cmd/fillstruct',
  fixplurals   = 'github.com/davidrjenni/reftools/cmd/fixplurals',
  fillswitch   = 'github.com/davidrjenni/reftools/cmd/fillswitch',
}

local function install(bin)
  local state = vim.cmd("!which " .. bin)
  if string.find(state, "not found") then
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

local function go_install(pkg)
  local u = url[pkg]
  if u == nil then
    print("command " .. pkg .. " not supported, please update install.lua")
    return
  end

  u = u .. "@latest"
  local setup = {"go", "install", u}

  vim.fn.jobstart(
    setup,
    {
      on_stdout = function(c, data, name)
        print(data)
      end
    }
  )
end

return {install = install, update = update, install_all = install_all}
