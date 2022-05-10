local M = {}
local util = require("go.utils")
local log = util.log
local warn = require("go.utils").warn

local function create_boilerplate(name)
  if not _GO_NVIM_CFG.go_boilplater_url then
    return warn("go boilerplate url missing")
  end
  local path = name or vim.fn.expand("%:p:h")
  local cmd = 'git clone --depth 1 --branch master ' .. _GO_NVIM_CFG.go_boilplater_url .. ' ' .. path
  log(cmd)
  vim.notify( "create boilerplate project: " .. vim.fn.system(cmd))
  util.deletedir(path .. "/.git")
end

return {create_boilerplate=create_boilerplate}
