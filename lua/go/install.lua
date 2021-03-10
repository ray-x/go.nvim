local uv = vim.loop
local gopath = vim.fn.expand("$GOPATH")
local gobinpath = gopath .. "/bin/"
local url = {
  golines = "segmentio/golines",
  gofumpt = "mvdan/gofumpt",
  gofumports = "mvdan/gofumpt",
  gomodifytags = "fatih/gomodifytags",
  gotsts = "cweill/gotests",
}

local function install(bin)
  local state = uv.fs_stat(gobinpath .. bin)
  if not state then
    print("installing " .. bin)
    local u = url[bin]
    if u == nil then
      print("command " .. bin .. " not supported, please update install.lua")
      return
    end
    local setup = {
      "go", "get",
      u
    }
    vim.fn.jobstart(
      setup,
      -- setup.args,
      {
        on_stdout = function(c, data, name)
          print(data)
        end
      }
    )
  end
end

local function update(bin)
  local u = url[bin]
  if u == nil then
    print("command " .. bin .. " not supported, please update install.lua")
    return
  end
  local setup = {"go", "get", "-u", u}

  vim.fn.jobstart(
    setup,
    {
      on_stdout = function(c, data, name)
        print(data)
      end
    }
  )
end

local function install_all()
  for key, value in pairs(url) do
    install(key)
  end
end

return {install = install, update = update, install_all = install_all}
