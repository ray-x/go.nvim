local launch_json_content = [[
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch package",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "remotePath": "",
            "port": 38697,
            "host": "127.0.0.1",
            "program": "${workspaceFolder}",
            "env": {
            },
            "args": [],
            "cwd": "${workspaceFolder}",
            "envFile": "${workspaceFolder}/.env",
            "buildFlags":""
        },
        {
            "name": "Debug current package",
            "type": "go",
            "request": "launch",
            "mode": "debug",
            "remotePath": "",
            "port": 38697,
            "host": "127.0.0.1",
            "program": "${fileDirname}",
            "env": {
            },
            "args": [],
            "cwd": "${workspaceFolder}",
            "envFile": "${workspaceFolder}/.env",
            "buildFlags":""
        },
        {
            "name": "Launch test function",
            "type": "go",
            "request": "launch",
            "mode": "test",
            "program": "${workspaceFolder}",
            "args": [
                "-test.run",
                "MyTestFunction"
            ]
        },
        {
            "name": "Attach main",
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
            "cwd": "${workspaceFolder}",
            "processId":"",
            "envFile": "${workspaceFolder}/.env",
            "buildFlags":""
        },
        {
            "name": "Attach to Process",
            "type": "go",
            "request": "attach",
            "mode": "local",
            "processId": 0
        },
        {
            "name": "Launch file",
            "type": "go",
            "request": "launch",
            "mode": "debug",
            "program": "${file}"
        }
    ]
}
]]

local util = require("go.utils")
local log = util.log
local M = {}
local sep = require("go.utils").sep()
local vfn = vim.fn
function M.vs_launch()
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vfn.getcwd()

  local launch_json = _GO_NVIM_CFG.launch_json or (workfolder .. sep .. ".vscode" .. sep .. "launch.json")
  log(launch_json)
  if vfn.filereadable(launch_json) == 1 then
    return true, launch_json
  else
    return false, launch_json
  end
end

function M.config()
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vfn.getcwd()
  local launch_json = _GO_NVIM_CFG.launch_json or (workfolder .. sep .. ".vscode" .. sep .. "launch.json")
  local launch_dir = string.match(launch_json, ".*" .. sep)

  local cmd = "e " .. launch_json

  if vfn.isdirectory(launch_dir) == 0 then
    vfn.mkdir(launch_dir)
  end

  if vfn.filereadable(launch_json) == 1 then
    return vim.cmd(cmd)
  end

  -- vfn.writefile(launch_json_content, launch_json)
  local contents = vfn.split(launch_json_content, "\n")
  vfn.writefile(contents, launch_json)
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
