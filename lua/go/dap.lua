local bind = require("keymap.bind")
local map_cr = bind.map_cr
local utils = require('go.utils')
local function setup_telescope()
  require('telescope').setup()
  require('telescope').load_extension('dap')
  local ts_keys = {
    ["n|lb"] = map_cr('<cmd>lua require"telescope".extensions.dap.list_breakpoints{}'):with_noremap()
        :with_silent(),
    ["n|tv"] = map_cr('<cmd>lua require"telescope".extensions.dap.variables{}'):with_noremap()
        :with_silent(),
    ["n|bt"] = map_cr('<cmd>lua require"telescope".extensions.dap.frames{}'):with_noremap()
        :with_silent()
  }
  bind.nvim_load_mapping(ts_keys)
end

local function keybind()
  local keys = {
    -- DAP --
    -- run
    ["n|r"] = map_cr('<cmd>lua require"go.dap".run()<CR>'):with_noremap():with_silent(),
    ["n|c"] = map_cr('<cmd>lua require"dap".continue()<CR>'):with_noremap():with_silent(),
    ["n|n"] = map_cr('<cmd>lua require"dap".step_over()<CR>'):with_noremap():with_silent(),
    ["n|s"] = map_cr('<cmd>lua require"dap".step_into()<CR>'):with_noremap():with_silent(),
    ["n|o"] = map_cr('<cmd>lua require"dap".step_out()<CR>'):with_noremap():with_silent(),
    ["n|S"] = map_cr('<cmd>lua require"go.dap".stop()<CR>'):with_noremap():with_silent(),
    ["n|u"] = map_cr('<cmd>lua require"dap".up()<CR>'):with_noremap():with_silent(),
    ["n|D"] = map_cr('<cmd>lua require"dap".down()<CR>'):with_noremap():with_silent(),
    ["n|C"] = map_cr('<cmd>lua require"dap".run_to_cursor()<CR>'):with_noremap():with_silent(),
    ["n|b"] = map_cr('<cmd>lua require"dap".toggle_breakpoint()<CR>'):with_noremap():with_silent(),
    ["n|P"] = map_cr('<cmd>lua require"dap".pause()<CR>'):with_noremap():with_silent(),
    ["n|p"] = map_cr('<cmd>lua require"dap.ui.variables".hover()<CR>'):with_noremap():with_silent(),
    ["v|p"] = map_cr('<cmd>lua require"dap.ui.variables".visual_hover()<CR>'):with_noremap()
        :with_silent()
    --
  }

  bind.nvim_load_mapping(keys)

end

local M = {}

M.prepare = function()
  vim.g.dap_virtual_text = 'all frames'
  utils.load_plugin('nvim-dap', "dap")
  if _GO_NVIM_CFG.dap_debug_gui then
    utils.load_plugin('nvim-dap-ui', "dapui")
    utils.load_plugin('nvim-dap-virtual-text')
  end

  vim.fn.sign_define('DapBreakpoint', {text = '🧘', texthl = '', linehl = '', numhl = ''})
  vim.fn.sign_define('DapStopped', {text = '🏃', texthl = '', linehl = '', numhl = ''})
end

M.breakpt = function()
  M.prepare()
  require"dap".toggle_breakpoint()
end

M.run = function(...)
  keybind()
  M.prepare()
  local args = {...}

  local mode = select(1, ...)

  utils.log("plugin loaded", mode)
  if _GO_NVIM_CFG.dap_debug_gui then
    require("dapui").setup()
    require("dapui").open()
  end
  local dap = require "dap"
  dap.adapters.go = function(callback, config)
    local handle
    local pid_or_err
    local port = 38697
    handle, pid_or_err = vim.loop.spawn("dlv", {
      args = {"dap", "-l", "127.0.0.1:" .. port},
      detached = true
    }, function(code)
      handle:close()
      print("Delve exited with exit code: " .. code)
    end)
    -- Wait 100ms for delve to start
    vim.defer_fn(function()
      dap.repl.open()
      callback({type = "server", host = "127.0.0.1", port = port})
    end, 100)

  end

  local dap_cfg = {
    type = "go",
    name = "Debug",
    request = "launch",
    dlvToolPath = vim.fn.exepath("dlv")
  }
  if mode == 'test' then
    dap_cfg.name = dap_cfg.name .. ' test'
    dap_cfg.mode = "test"
    dap_cfg.program = "${workspaceFolder}"

    dap.configurations.go = {dap_cfg}
    dap.continue()
  else
    dap_cfg.program = "${file}"
    dap_cfg.args = args
    dap.configurations.go = {dap_cfg}
    dap.continue()
  end
  utils.log(args)
end

M.stop = function()
  local keys = {"r", "c", "n", "s", "o", "S", "u", "D", "C", "b", "P"}
  for _, value in pairs(keys) do
    local cmd = "unmap " .. value
    vim.cmd(cmd)
  end

  vim.cmd([[uvmap p]])
  require'dap'.disconnect()
  require'dap'.stop();
  require"dap".repl.close()
  require("dapui").close()
end

function M.ultest_post()
  vim.g.ultest_use_pty = 1
  local builders = {
    ["go#richgo"] = function(cmd)
      local args = {}
      for i = 3, #cmd, 1 do
        local arg = cmd[i]
        if vim.startswith(arg, "-") then
          arg = "-test." .. string.sub(arg, 2)
        end
        args[#args + 1] = arg
      end
      return {
        dap = {
          type = "go",
          request = "launch",
          mode = "test",
          program = "${workspaceFolder}",
          dlvToolPath = vim.fn.exepath("dlv"),
          args = args
        },
        parse_result = function(lines)
          return lines[#lines] == "FAIL" and 1 or 0
        end
      }
    end
  }

  ok, ul = utils.load_plugin('vim-ultest', "ultest")

  ul.setup({builders = builders})
end

return M
