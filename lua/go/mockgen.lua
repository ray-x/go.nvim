-- local ts_utils = require 'nvim-treesitter.ts_utils'
local utils = require("go.utils")
local log = utils.log
local vfn = vim.fn
local mockgen = "mockgen" -- GoMock f *Foo io.Writer

-- use ts to get name
local function get_interface_name()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local name = require("go.ts.go").get_interface_node_at_pos(row, col)
  if name == nil then
    return nil
  end
  utils.log(name)
  if name == nil then
    return ""
  end
  local node_name = name.name
  -- let move the cursor to end of line of struct name
  local dim = name.dim.e
  -- let move cursor
  local r, c = dim.r, dim.c
  utils.log("move cusror to ", r, c)
  vim.api.nvim_win_set_cursor(0, { r, c })
  return node_name
end

local run = function(opts)
  require("go.install").install(mockgen)

  local long_opts = {
    package = "p",
    source = "s",
    destination = "d",
    interface = "i",
  }

  local getopt = require("go.alt_getopt")
  local short_opts = "p:d:i:s"
  local args = opts.fargs or {}
  log(args)

  local optarg, _, reminder = getopt.get_opts(args, short_opts, long_opts)
  local mockgen_cmd = { mockgen }
  utils.log(arg)

  local sep = require("go.utils").sep()

  local ifname = get_interface_name()

  if optarg["i"] ~= nil and #optarg["i"] > 0 then
    ifname = optarg["i"]
  end

  if optarg["s"] ~= nil then
    ifname = ""
  end
  local fpath = utils.rel_path(true) -- rel/path/only
  log(fpath, mockgen_cmd)
  local sname = vfn.expand("%:t") -- name.go only

  if fpath ~= "" then
    fpath = fpath .. sep
  end

  if ifname == "" or ifname == nil then
    -- source mode default
    table.insert(mockgen_cmd, "-source")
    table.insert(mockgen_cmd, fpath .. sname)
  else
    log("interface ", ifname)
    -- need to get the import path
    local bufnr = vim.api.nvim_get_current_buf()

    local pkg = require("go.package").pkg_from_path(nil, bufnr)
    if pkg ~= nil and type(pkg) == "table" and pkg[1] then
      table.insert(mockgen_cmd, pkg[1])
    else
      utils.notify("no package found, using .")
      table.insert(mockgen_cmd, '.')
    end
    table.insert(mockgen_cmd, ifname)
  end

  local pkgname = optarg["p"] or "mocks"
  table.insert(mockgen_cmd, "-package")
  table.insert(mockgen_cmd, pkgname)

  local dname = fpath .. pkgname .. sep .. "mock_" .. sname
  table.insert(mockgen_cmd, "-destination")
  table.insert(mockgen_cmd, dname)

  log(mockgen_cmd)

  utils.log(mockgen_cmd)
  -- vim.cmd("normal! $%") -- do a bracket match. changed to treesitter
  local opts = {
    on_exit = function(code, signal, data)
      if code ~= 0 or signal ~= 0 then
        -- there will be error popup from runner
        -- utils.warn("mockgen failed" .. vim.inspect(data))
        return
      end
      data = vim.split(data, "\n")
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      --
      vim.schedule(function()
        utils.info(vfn.join(mockgen_cmd, " ") .. " finished " .. vfn.join(data, " "))
      end)
    end,
  }
  local runner = require("go.runner")
  runner.run(mockgen_cmd, opts)
  return mockgen_cmd
end

return { run = run }
