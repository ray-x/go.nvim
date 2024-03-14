-- this file allow a setup load per project
--[[
-- sample cfg
return  {
  go = "go", -- set to go1.18beta1 if necessary
  goimport = "gopls", -- if set to 'gopls' will use gopls format, also goimport
  gofmt = "gofumpt", -- if set to gopls will use gopls format
  tag_transform = false,
  test_dir = "",
  sign_priority = 5,
  launch_json = nil, -- the launch.json file path, default to .vscode/launch.json
  -- launch_json = vfn.getcwd() .. "/.vscode/launch.json",

  build_tags = "", --- you can provide extra build tags for tests or debugger

}

]]

-- if the file existed, load it into config
local vfn = vim.fn
local util = require("go.utils")
local log = util.log
local M = {}
local sep = require("go.utils").sep()

function M.project_existed()
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vfn.getcwd()
  local gocfgfd = workfolder .. sep .. ".gonvim"
  local gocfgbrks = gocfgfd .. sep .. "breakpoints.lua"
  local gocfg = gocfgfd .. sep .. "init.lua"
  if vfn.filereadable(gocfg) == 1 or  vfn.filereadable(gocfgbrks) == 1 then
    log("projects existed", gocfg, gocfgbrks)
    return gocfg, gocfgbrks
  end
end

function M.setup()
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vfn.getcwd()
  local gocfgfd = workfolder .. sep .. ".gonvim"
  local gocfg = gocfgfd .. sep .. "init.lua"

  if vfn.isdirectory(gocfgfd) == 0 then
    vfn.mkdir(gocfgfd)
  end
  if vfn.filereadable(gocfg) == 0 then
    local f = io.open(gocfg, "w")
    f:write("return {}")
    f:close()
  end
  return gocfg, gocfgfd
end

function M.load_project()
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vfn.getcwd()
  local gocfg = workfolder .. sep .. ".gonvim" .. sep .. "init.lua"
  if _GO_NVIM_CFG.disable_per_project_cfg then
    log("project setup existed but disabled")
    return
  end
  if vfn.filereadable(gocfg) == 1 then
    local f = assert(loadfile(gocfg))
    log(f())
    _GO_NVIM_CFG = vim.tbl_deep_extend("force", _GO_NVIM_CFG, f())
  else
    return false
  end
end

M.load_project()

return M
