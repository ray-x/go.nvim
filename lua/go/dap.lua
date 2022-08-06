local bind = require("go.keybind")
local utils = require("go.utils")
local log = utils.log
local sep = "." .. utils.sep()
local getopt = require("go.alt_getopt")
local dapui_setuped
local keys = {}
local long_opts = {
  compile = "c",
  run = "r",
  attach = "a",
  test = "t",
  restart = "R",
  stop = "s",
  help = "h",
  nearest = "n",
  package = "p",
  file = "f",
  breakpoint = "b",
  tag = "T",
}
local opts = "tcraRsnpfsbhT:"
local function help()
  return "Usage: GoDebug [OPTION]\n"
    .. "Options:\n"
    .. "  -c, --compile         compile\n"
    .. "  -r, --run             run\n"
    .. "  -t, --test            run tests\n"
    .. "  -R, --restart         restart\n"
    .. "  -s, --stop            stop\n"
    .. "  -h, --help            display this help and exit\n"
    .. "  -n, --nearest         debug nearest file\n"
    .. "  -p, --package         debug package\n"
    .. "  -f, --file            display file\n"
    .. "  -b, --breakpoint      set breakpoint"
end

-- not sure if anyone still use telescope for debug
local function setup_telescope()
  require("telescope").setup()
  require("telescope").load_extension("dap")
  local ts_keys = {
    ["n|lb"] = '<cmd>lua require"telescope".extensions.dap.list_breakpoints{}',
    ["n|tv"] = '<cmd>lua require"telescope".extensions.dap.variables{}',
    ["n|bt"] = '<cmd>lua require"telescope".extensions.dap.frames{}',
  }
  bind.nvim_load_mapping(ts_keys)
end

local keymaps_backup
local function keybind()
  if not _GO_NVIM_CFG.dap_debug_keymap then
    return
  end
  -- TODO: put keymaps back
  keymaps_backup = vim.api.nvim_get_keymap("n")
  keys = {
    -- DAP --
    -- run
    ["r"] = { f = require("go.dap").run, desc = "run" },
    ["c"] = { f = require("dap").continue, desc = "continue" },
    ["n"] = { f = require("dap").step_over, desc = "step_over" },
    ["s"] = { f = require("dap").step_into, desc = "step_into" },
    ["o"] = { f = require("dap").step_out, desc = "step_out" },
    ["S"] = { f = require("go.dap").stop, desc = "stop" },
    ["u"] = { f = require("dap").up, desc = "up" },
    ["D"] = { f = require("dap").down, desc = "down" },
    ["C"] = { f = require("dap").run_to_cursor, desc = "run_to_cursor" },
    ["b"] = { f = require("dap").toggle_breakpoint, desc = "toggle_breakpoint" },
    ["P"] = { f = require("dap").pause, desc = "pause" },
    --
  }
  if _GO_NVIM_CFG.dap_debug_gui then
    keys["p"] = { f = require("dapui").eval, m = { "n", "v" }, desc = "eval" }
    keys["K"] = { f = require("dapui").float_element, desc = "float_element" }
    keys["B"] = {
      f = function()
        require("dapui").float_element("breakpoints")
      end,
      desc = "float_element('breakpoints')",
    }
    keys["R"] = {
      f = function()
        require("dapui").float_element("repl")
      end,
      desc = "float_element('repl')",
    }
    keys["O"] = {
      f = function()
        require("dapui").float_element("scopes")
      end,
      desc = "float_element('scopes')",
    }
    keys["a"] = {
      f = function()
        require("dapui").float_element("stacks")
      end,
      desc = "float_element('stacks')",
    }
    keys["w"] = {
      f = function()
        require("dapui").float_element("watches")
      end,
      desc = "float_element('watches')",
    }
  else
    keys["p"] = { f = require("dap.ui.widgets").hover, m = { "n", "v" }, desc = "hover" }
  end
  bind.nvim_load_mapping(keys)
end

local function get_test_build_tags()
  local get_build_tags = require("go.gotest").get_build_tags
  local tags = get_build_tags({})
  if tags then
    return tags
  else
    return ""
  end
end

local M = {}

function M.debug_keys()
  local keymap_help = {}
  for key, val in pairs(keys) do
    -- local m = vim.fn.matchlist(val, [[\v(\p+)\.(\p+\(\p*\))]]) -- match last function e.g.float_element("repl")

    table.insert(keymap_help, key .. " -> " .. val.desc)
  end

  local guihua = utils.load_plugin("guihua.lua", "guihua.listview")

  if guihua then
    local ListView = require("guihua.listview")
    return ListView:new({
      loc = "top_center",
      border = "none",
      prompt = true,
      enter = true,
      rect = { height = 20, width = 50 },
      data = keymap_help,
    })
  end


  local close_events = { "CursorMoved", "CursorMovedI", "BufHidden", "InsertCharPre" }
  local config = { close_events = close_events, focusable = true, border = "single" }
  vim.lsp.util.open_floating_preview(keymap_help, "lua", config)
end

M.prepare = function()
  utils.load_plugin("nvim-dap", "dap")
  if _GO_NVIM_CFG.icons ~= false then
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
  end
  if _GO_NVIM_CFG.dap_debug_gui then
    utils.load_plugin("nvim-dap-ui", "dapui")
    if dapui_setuped ~= true then
      require("dapui").setup()
      dapui_setuped = true
    end
  end
  if _GO_NVIM_CFG.dap_debug_vt then
    local vt = utils.load_plugin("nvim-dap-virtual-text")
    vt.setup({ enabled_commands = true, all_frames = true })
  end
end

M.breakpt = function()
  M.prepare()
  require("dap").toggle_breakpoint()
end

M.save_brks = function()
  M.prepare()
  local bks = require("dap.breakpoints").get()
  local all_bks = {}
  if bks and next(bks) then
    local _, fld = require("go.project").setup()
    for bufnr, bk in pairs(bks) do
      local uri = vim.uri_from_bufnr(bufnr)
      local _bk = {}
      for _, value in pairs(bk) do
        table.insert(_bk, { line = value.line })
      end
      all_bks[uri] = _bk
    end
    local bkfile = fld .. utils.sep() .. "breakpoints.lua"
    local writeStr = "return " .. vim.inspect(all_bks)

    local writeLst = vim.split(writeStr, "\n")

    vim.fn.writefile(writeLst, bkfile, "b")
  end
end

M.load_brks = function()
  M.prepare()
  local _, brkfile = require("go.project").project_existed()
  if vim.fn.filereadable(brkfile) == 0 then
    return
  end
  local f = assert(loadfile(brkfile))
  local brks = f()
  for uri, brk in pairs(brks) do
    local bufnr = vim.uri_to_bufnr(uri)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      vim.fn.bufload(bufnr)
    end
    for index, lnum in ipairs(brk) do
      require("dap.breakpoints").set({}, bufnr, lnum.line)
    end
  end
end

M.clear_bks = function()
  utils.load_plugin("nvim-dap", "dap")

  require("dap.breakpoints").clear()
  M.save_bks()
  local _, brkfile = require("go.project").project_existed()
  if vim.fn.filereadable(brkfile) == 0 then
    return
  end
  local f = assert(loadfile(brkfile))
  local brks = f()
  for uri, brk in pairs(brks) do
    local bufnr = vim.uri_to_bufnr(uri)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      vim.fn.bufload(bufnr)
    end
    for _, lnum in ipairs(brk) do
      require("dap.breakpoints").set({}, bufnr, lnum.line)
    end
  end
end

local function dapui_opened()
  local lys = require("dapui.windows").layouts or {}
  local opened = false
  for _, ly in ipairs(lys) do
    if ly:is_open() == true then
      opened = true
    end
  end
  return opened
end

local stdout, stderr, handle
M.run = function(...)
  local args = { ... }
  local mode = "test"

  local optarg, optind = getopt.get_opts(args, opts, long_opts)
  log(optarg, optind)

  if optarg["h"] then
    return utils.info(help())
  end

  if optarg["c"] then
    local fpath = vim.fn.expand("%:p:h")
    local out = vim.fn.systemlist(table.concat({
      "go",
      "test",
      "-v",
      "-cover",
      "-covermode=atomic",
      "-coverprofile=cover.out",
      "-tags " .. _GO_NVIM_CFG.build_tags,
      "-c",
      fpath,
    }, " "))
    if #out ~= 0 then
      utils.info("building " .. vim.inspect(out))
    end
    return
  end

  if optarg["b"] then
    return require("dap").toggle_breakpoint()
  end

  local guihua = utils.load_plugin("guihua.lua", "guihua.gui")

  local original_select = vim.ui.select
  if guihua then
    vim.ui.select = require("guihua.gui").select
  end

  -- testopts = {"test", "nearest", "file", "stop", "restart"}
  log("plugin loaded", mode, optarg)

  if optarg["s"] and (optarg["t"] or optarg["r"]) then
    M.stop(false)
  elseif optarg["s"] then
    return M.stop(true)
  end

  -- restart
  if optarg["R"] then
    M.stop(false)
    if optarg["t"] then
      mode = "test"
    else
      mode = M.pre_mode or "file"
    end
  else
    M.pre_mode = mode
  end

  M.prepare()
  local session = require("dap").session()
  if session ~= nil and session.initialized == true then
    if not optarg["R"] then
      utils.info("debug session already started, press c to continue")
      return
    else
      utils.info("debug session already started, press c to restart and stop the session")
    end
  end

  local run_cur = optarg["r"] -- undocumented mode, smartrun current program in interactive mode
  -- e.g. edit and run
  local testfunc

  if not run_cur then
    keybind()
  else
    M.stop() -- rerun
    testfunc = require("go.gotest").get_test_func_name()
    if not string.find(testfunc.name, "[T|t]est") then
      log("no test func found", testfunc.name)
      testfunc = nil -- no test func avalible, run main
    end
  end

  if _GO_NVIM_CFG.dap_debug_gui and not run_cur then
    if dapui_opened() == false then
      require("dapui").open()
    end
  end

  local port = _GO_NVIM_CFG.dap_port
  if _GO_NVIM_CFG.dap_port == nil or _GO_NVIM_CFG.dap_port == -1 then
    math.randomseed(os.time())
    port = 38000 + math.random(1, 1000)
  end
  local dap = require("dap")
  dap.adapters.go = function(callback, config)
    stdout = vim.loop.new_pipe(false)
    stderr = vim.loop.new_pipe(false)
    local pid_or_err
    port = config.port or port

    local host = config.host or "127.0.0.1"

    local addr = string.format("%s:%d", host, port)
    local function onread(err, data)
      if err then
        log(err, data)
        -- print('ERROR: ', err)
        vim.notify("dlv exited with code " + tostring(err), vim.lsp.log_levels.WARN)
      end
      if not data or data == "" then
        return
      end
      if data:find("couldn't start") then
        vim.schedule(function()
          utils.error(data)
        end)
      end

      vim.schedule(function()
        require("dap.repl").append(data)
      end)
    end

    handle, pid_or_err = vim.loop.spawn("dlv", {
      stdio = { nil, stdout, stderr },
      args = { "dap", "-l", addr },
      detached = true,
    }, function(code)
      if code ~= 0 then
        vim.schedule(function()
          log("Dlv exited", code)
          vim.notify(string.format("Delve exited with exit code: %d", code), vim.lsp.log_levels.WARN)
          if _GO_NVIM_CFG.dap_port ~= nil then
            _GO_NVIM_CFG.dap_port = _GO_NVIM_CFG.dap_port + 1
          end
        end)
      end

      _ = stdout and stdout:close()
      _ = stderr and stderr:close()
      _ = handle and handle:close()
      stdout = nil
      stderr = nil
      handle = nil
    end)
    assert(handle, "Error running dlv: " .. tostring(pid_or_err))
    stdout:read_start(onread)
    stderr:read_start(onread)

    if not optarg["r"] then
      dap.repl.open()
    end
    vim.defer_fn(function()
      callback({ type = "server", host = host, port = port })
    end, 1000)
  end

  log(get_test_build_tags())
  local dap_cfg = {
    type = "go",
    name = "Debug",
    request = "launch",
    dlvToolPath = vim.fn.exepath("dlv"),
    buildFlags = get_test_build_tags(),
  }

  local empty = utils.empty

  local launch = require("go.launch")
  local cfg_exist, cfg_file = launch.vs_launch()
  log(mode, cfg_exist, cfg_file)

  -- if breakpoint is not set add breakpoint at current pos
  local pts = require("dap.breakpoints").get()
  if utils.empty(pts) then
    require("dap").set_breakpoint()
  end

  testfunc = require("go.gotest").get_test_func_name()
  log(testfunc)

  if testfunc then
    if testfunc.name ~= "main" then
      optarg["t"] = true
    end
  end
  if optarg["t"] then
    dap_cfg.name = dap_cfg.name .. " test"
    dap_cfg.mode = "test"
    dap_cfg.request = "launch"
    dap_cfg.program = sep .. "${relativeFileDirname}"

    if testfunc then
      dap_cfg.args = { "-test.run", "^" .. testfunc.name }
    end
    dap.configurations.go = { dap_cfg }
    dap.continue()
  elseif optarg["n"] then
    local ns = require("go.ts.go").get_func_method_node_at_pos()
    if empty(ns) then
      log("ts not not found, debug while file")
    end
    dap_cfg.name = dap_cfg.name .. " test_nearest"
    dap_cfg.mode = "test"
    dap_cfg.request = "launch"
    dap_cfg.program = sep .. "${relativeFileDirname}"
    if not empty(ns) then
      dap_cfg.args = { "-test.run", "^" .. ns.name }
    end
    dap.configurations.go = { dap_cfg }
    dap.continue()
  elseif optarg["a"] then
    dap_cfg.name = dap_cfg.name .. " attach"
    dap_cfg.mode = "local"
    dap_cfg.request = "attach"
    dap_cfg.processId = require("dap.utils").pick_process
    dap.configurations.go = { dap_cfg }
    dap.continue()
  elseif optarg["p"] then
    dap_cfg.name = dap_cfg.name .. " package"
    dap_cfg.mode = "test"
    dap_cfg.request = "launch"
    dap_cfg.program = sep .. "${fileDirname}"
    dap.configurations.go = { dap_cfg }
    dap.continue()
  elseif run_cur then
    dap_cfg.name = dap_cfg.name .. " run current"
    dap_cfg.request = "launch"
    dap_cfg.mode = "debug"
    dap_cfg.request = "launch"
    if testfunc then
      dap_cfg.args = { "-test.run", "^" .. testfunc.name }
      dap_cfg.mode = "test"
    end
    dap_cfg.program = sep .. "${relativeFileDirname}"
    dap.configurations.go = { dap_cfg }
    dap.continue()
    -- dap.run_to_cursor()
  elseif cfg_exist then
    log("using launch cfg")
    launch.load()
    log(dap.configurations.go)
    for _, cfg in ipairs(dap.configurations.go) do
      cfg.dlvToolPath = vim.fn.exepath("dlv")
    end
    dap.continue()
  else -- no args
    log("debug main")
    dap_cfg.program = sep .. "${relativeFileDirname}"
    dap_cfg.args = args
    dap_cfg.mode = "debug"
    dap_cfg.request = "launch"
    dap.configurations.go = { dap_cfg }
    dap.continue()
  end
  log(dap_cfg, args, optarg)

  M.pre_mode = dap_cfg.mode or M.pre_mode

  vim.ui.select = original_select
end

local unmap = function()
  if not _GO_NVIM_CFG.dap_debug_keymap then
    return
  end
  local unmap_keys = {
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
  for _, value in pairs(unmap_keys) do
    local cmd = "silent! unmap " .. value
    vim.cmd(cmd)
  end

  vim.cmd([[silent! vunmap p]])

  for _, k in pairs(unmap_keys) do
    for _, v in pairs(keymaps_backup or {}) do
      if v.lhs == k then
        local nr = (v.noremap == 1)
        local sl = (v.slient == 1)
        local exp = (v.expr == 1)
        local mode = v.mode
        local desc = v.desc or "go-dap"
        if v.mode == " " then
          mode = {'n', 'v'}
        end

        log(v)
        vim.keymap.set(mode, v.lhs, v.rhs or v.callback, { noremap = nr, silent = sl, expr = exp, desc = desc })
        -- vim.api.nvim_set_keymap('n', v.lhs, v.rhs, {noremap=nr, silent=sl, expr=exp})
      end
    end
  end
  keymaps_backup = {}

end

M.disconnect_dap = function()
  local has_dap, dap = pcall(require, "dap")
  if has_dap then
    dap.disconnect()
    dap.repl.close()
    vim.cmd("sleep 100m") -- allow cleanup
  else
    vim.notify("dap not found")
  end
end

M.stop = function(unm)
  if unm then
    unmap()
  end
  M.disconnect_dap()

  local has_dap, dap = pcall(require, "dap")
  if not has_dap then
    return
  end
  local has_dapui, dapui = pcall(require, "dapui")
  if has_dapui then
    if dapui_opened() then
      dapui.close()
    end
  end

  dap.repl.close()
  if stdout then
    stdout:close()
    stdout = nil
  end
  if stderr then
    stderr:close()
    stderr = nil
  end
  if handle then
    handle:close()
    handle = nil
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
          buildFlags = get_test_build_tags(),
        },
        parse_result = function(lines)
          return lines[#lines] == "FAIL" and 1 or 0
        end,
      }
    end,
  }

  local ul = utils.load_plugin("vim-ultest", "ultest")
  if ul then
    ul.setup({ builders = builders })
  end
end

return M
