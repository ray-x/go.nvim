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

function M.vs_launch()
  local launch_json = _GO_NVIM_CFG.launch_json or (vim.fn.getcwd() .. "/.vscode/launch.json")
  log(launch_json)
  if vim.fn.filereadable(launch_json) == 1 then
    return true, launch_json
  else
    return false, launch_json
  end
end

function M.config()
  local launch_json = _GO_NVIM_CFG.launch_json or (vim.fn.getcwd() .. "/.vscode/launch.json")

  local cmd = "e " .. launch_json
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
