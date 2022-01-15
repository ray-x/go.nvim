local bind = require("go.keybind")
local map_cr = bind.map_cr
local utils = require("go.utils")
local log = utils.log
local sep = "." .. utils.sep()

local function setup_telescope()
  require("telescope").setup()
  require("telescope").load_extension("dap")
  local ts_keys = {
    ["n|lb"] = map_cr('<cmd>lua require"telescope".extensions.dap.list_breakpoints{}'):with_noremap():with_silent(),
    ["n|tv"] = map_cr('<cmd>lua require"telescope".extensions.dap.variables{}'):with_noremap():with_silent(),
    ["n|bt"] = map_cr('<cmd>lua require"telescope".extensions.dap.frames{}'):with_noremap():with_silent(),
  }
  bind.nvim_load_mapping(ts_keys)
end

local function keybind()
  if not _GO_NVIM_CFG.dap_debug_keymap then
    return
  end
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
    --
  }
  if _GO_NVIM_CFG.dap_debug_gui then
    keys["n|p"] = map_cr('<cmd>lua require("dapui").eval()'):with_noremap():with_silent()
    keys["v|p"] = map_cr('<cmd>lua require("dapui").eval()'):with_noremap():with_silent()
    keys["n|K"] = map_cr('<cmd>lua require("dapui").float_element()'):with_noremap():with_silent()
    keys["n|B"] = map_cr('<cmd>lua require("dapui").float_element("breakpoints")'):with_noremap():with_silent()
    keys["n|R"] = map_cr('<cmd>lua require("dapui").float_element("repl")'):with_noremap():with_silent()
    keys["n|O"] = map_cr('<cmd>lua require("dapui").float_element("scopes")'):with_noremap():with_silent()
    keys["n|a"] = map_cr('<cmd>lua require("dapui").float_element("stacks")'):with_noremap():with_silent()
    keys["n|w"] = map_cr('<cmd>lua require("dapui").float_element("watches")'):with_noremap():with_silent()
  else
    keys["n|p"] = map_cr('<cmd>lua require"dap.ui.widgets".hover()<CR>'):with_noremap():with_silent()
    keys["v|p"] = map_cr('<cmd>lua require"dap.ui.widgets".hover()<CR>'):with_noremap():with_silent()
  end
  bind.nvim_load_mapping(keys)
end

local function get_build_flags()
  if _GO_NVIM_CFG.build_tags ~= "" then
    return "-tags " .. _GO_NVIM_CFG.build_tags
  else
    return ""
  end
end

local M = {}

M.prepare = function()
  utils.load_plugin("nvim-dap", "dap")
  vim.fn.sign_define("DapBreakpoint", {
    text = _GO_NVIM_CFG.icons.breakpoint,
    texthl = "",
    linehl = "",
    numhl = "",
  })
  vim.fn.sign_define("DapStopped", {
    text = _GO_NVIM_CFG.icons.currentpos,
    texthl = "",
    linehl = "",
    numhl = "",
  })

  if _GO_NVIM_CFG.dap_debug_gui then
    utils.load_plugin("nvim-dap-ui", "dapui")
    if _GO_NVIM_CFG.dap_debug_vt then
      local vt = utils.load_plugin("nvim-dap-virtual-text")
      vt.setup({ enabled_commands = true, all_frames = true })
    end
  end
end

M.breakpt = function()
  M.prepare()
  require("dap").toggle_breakpoint()
end

M.run = function(...)
  local args = { ... }
  local mode = select(1, ...)
  local ctl_opt = select(2, ...)

  -- testopts = {"test", "nearest", "file", "stop", "restart"}
  log("plugin loaded", mode, ctl_opt)
  if mode == "stop" or ctl_opt == "stop" then
    return require("go.dap").stop(true)
  end

  if mode == "restart" or ctl_opt == "restart" then
    require("go.dap").stop()
    if ctl_opt == "restart" then
      mode = mode
    else
      mode = M.pre_mode or "file"
    end
  else
    M.pre_mode = mode
  end

  M.prepare()
  local session = require("dap").session()
  if session ~= nil and session.initialized == true then
    vim.notify("debug session already start, press c to continue", vim.lsp.log_levels.INFO)
    return
  end

  keybind()

  if _GO_NVIM_CFG.dap_debug_gui then
    require("dapui").setup()
    if not require("dapui.windows").sidebar:is_open() then
      require("dapui").open()
    end
  end
  local dap = require("dap")
  dap.adapters.go = function(callback, config)
    local stdout = vim.loop.new_pipe(false)
    local handle
    local pid_or_err
    local port = 38697
    handle, pid_or_err = vim.loop.spawn("dlv", {
      stdio = { nil, stdout },
      args = { "dap", "-l", "127.0.0.1:" .. port },
      detached = true,
    }, function(code)
      stdout:close()
      handle:close()
      if code ~= 0 then
        vim.schedule(function()
          vim.notify(string.format("Delve exited with exit code: %d", code), vim.lsp.log_levels.WARN)
        end)
      end
    end)
    assert(handle, "Error running dlv: " .. tostring(pid_or_err))
    stdout:read_start(function(err, chunk)
      assert(not err, err)
      if chunk then
        vim.schedule(function()
          require("dap.repl").append(chunk)
        end)
      end
    end)
    -- Wait 500ms for delve to start
    vim.defer_fn(function()
      dap.repl.open()
      callback({ type = "server", host = "127.0.0.1", port = port })
    end, 500)
  end

  local dap_cfg = {
    type = "go",
    name = "Debug",
    request = "launch",
    dlvToolPath = vim.fn.exepath("dlv"),
    buildFlags = get_build_flags(),
  }

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1

  local empty = utils.empty
  local ns = require("go.ts.go").get_func_method_node_at_pos(row, col)
  if empty(ns) then
    log("ts not not found, debug while file")
    if mode == "nearest" then
      mode = "test"
    end
  end

  local launch = require("go.launch")
  local cfg_exist, cfg_file = launch.vs_launch()
  log(mode, cfg_exist, cfg_file)
  if mode == "test" then
    dap_cfg.name = dap_cfg.name .. " test"
    dap_cfg.mode = "test"
    -- dap_cfg.program = "${workspaceFolder}"
    -- dap_cfg.program = "${file}"
    dap_cfg.program = sep .. "${relativeFileDirname}"
    dap.configurations.go = { dap_cfg }
    dap.continue()
  elseif mode == "nearest" then
    dap_cfg.name = dap_cfg.name .. " test_nearest"
    dap_cfg.mode = "test"
    dap_cfg.program = sep .. "${relativeFileDirname}"
    dap_cfg.args = { "-test.run", "^" .. ns.name }
    log(dap_cfg)
    dap.configurations.go = { dap_cfg }
    dap.continue()
  elseif cfg_exist then
    log("using cfg")
    launch.load()
    for _, cfg in ipairs(dap.configurations.go) do
      cfg.dlvToolPath = vim.fn.exepath("dlv")
    end
    dap.continue()
  else
    dap_cfg.program = sep .. "${relativeFileDirname}"
    dap_cfg.args = args
    dap.configurations.go = { dap_cfg }
    dap.continue()
  end
  log(args)
end

local unmap = function()
  if not _GO_NVIM_CFG.dap_debug_keymap then
    return
  end
  local keys = {
    "r",
    "c",
    "n",
    "s",
    "o",
    "S",
    "u",
    "D",
    "C",
    "b",
    "P",
    "p",
    "K",
    "B",
    "R",
    "O",
    "a",
    "w",
  }
  for _, value in pairs(keys) do
    local cmd = "silent! unmap " .. value
    vim.cmd(cmd)
  end

  vim.cmd([[silent! vunmap p]])
end

M.stop = function(unm)
  if unm then
    unmap()
  end
  require("dap").disconnect()
  require("dap").close()
  require("dap").repl.close()

  local has_dapui, dapui = pcall(require, "dapui")
  if has_dapui then
    dapui.close()
  end
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
          program = sep .. "${relativeFileDirname}",
          dlvToolPath = vim.fn.exepath("dlv"),
          args = args,
          buildFlags = get_build_flags(),
        },
        parse_result = function(lines)
          return lines[#lines] == "FAIL" and 1 or 0
        end,
      }
    end,
  }

  ul = utils.load_plugin("vim-ultest", "ultest")
  if ul then
    ul.setup({ builders = builders })
  end
end

return M
