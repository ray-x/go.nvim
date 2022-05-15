local launch_json_content = [[
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch main",
            "type": "go",
            "request": "launch",
            "mode": "exec",
            "remotePath": "",
            "port": 38697,
            "host": "127.0.0.1",
            "program": "${workspaceFolder}/main.go",
            "env": {
            },
            "args": [],
            "cwd": ${workspaceFolder}",
            "envFile", "${workspaceFolder}/.env"
            "buildFlags":""
        },
        {
            "name": "debug main",
            "type": "go",
            "request": "launch",
            "mode": "debug",
            "remotePath": "",
            "port": 38697,
            "host": "127.0.0.1",
            "program": "${workspaceFolder}/main.go",
            "env": {
            },
            "args": [],
            "cwd": ${workspaceFolder}",
            "envFile", "${workspaceFolder}/.env"
            "buildFlags":""
        },
        {
            "name": "debug main",
            "type": "go",
            "request": "attach",
            "mode": "debug",
            "remotePath": "",
            "port": 38697,
            "host": "127.0.0.1",
            "program": "${workspaceFolder}/main.go",
            "env": {
            },
            "args": [],
            "cwd": ${workspaceFolder}",
            "processId":"",
            "envFile", "${workspaceFolder}/.env"
            "buildFlags":""
        }
    ]
}
]]

local util = require("go.utils")
local log = util.log
local M = {}
local sep = require("go.utils").sep()

function M.vs_launch()
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vim.fn.getcwd()

  local launch_json = _GO_NVIM_CFG.launch_json or (workfolder .. sep .. ".vscode" .. sep .. "launch.json")
  log(launch_json)
  if vim.fn.filereadable(launch_json) == 1 then
    return true, launch_json
  else
    return false, launch_json
  end
end

function M.config()
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vim.fn.getcwd()
  local launch_json = _GO_NVIM_CFG.launch_json or (workfolder .. sep .. ".vscode" .. sep .. "launch.json")
  local launch_dir = string.match(launch_json, ".*" .. sep)

  local cmd = "e " .. launch_json

  log(launch_json, launch_dir)
  if vim.fn.isdirectory(launch_dir) == 0 then
    vim.fn.mkdir(launch_dir)
  end

  if vim.fn.filereadable(launch_json) == 1 then
    return vim.cmd(cmd)
  end

  -- vim.fn.writefile(launch_json_content, launch_json)
  local contents = vim.fn.split(launch_json_content, "\n")
  vim.fn.writefile(contents, launch_json)
  vim.cmd(cmd)
end

function M.load()
  if _GO_NVIM_CFG.launch_json_loaded == true then
    return
  end

  local dap = require("dap")
  local launch = require("dap.ext.vscode").load_launchjs
  launch(_GO_NVIM_CFG.launch_json)
  _GO_NVIM_CFG.launch_json_loaded = true
  log(dap.configurations)
end

return M
