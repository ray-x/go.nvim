-- local ts_utils = require 'nvim-treesitter.ts_utils'
local utils = require("go.utils")
local vfn = vim.fn
local impl = "impl" -- GoImpl f *Foo io.Writer
-- use ts to get name
local function get_struct_name()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local name = require("go.ts.go").get_struct_node_at_pos(row, col)
  if name == nil then
    print("put cursor on struct or specify a receiver")
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

local run = function(...)
  require("go.install").install(impl)
  local impl_cmd = "impl"
  local iface = ""
  local recv_name = ""
  local arg = { ... }
  utils.log(#arg, arg)

  local recv = get_struct_name()
  if #arg == 0 then
    iface = vfn.input("Impl: generating method stubs for interface: ")
    vim.cmd("redraw!")
    if iface == "" then
      print("Impl: please input interface name e.g. io.Reader")
      -- print("Usage: GoImpl f *File io.Reader")
    end
  elseif #arg == 1 then
    -- " i.e: ':GoImpl io.Writer'
    recv = string.lower(recv) .. " *" .. recv
    utils.log(recv)
    vim.cmd("redraw!")
    iface = select(1, ...)
  elseif #arg == 2 then
    -- " i.e: ':GoImpl s io.Writer'
    utils.log(recv)
    recv_name = select(1, ...)
    recv = string.format("%s *%s", recv_name, recv)
    local l = #arg
    iface = select(l, ...)
  elseif #arg > 2 then
    local l = #arg
    iface = select(l, ...)
    recv = select(l - 1, ...)
    recv_name = select(l - 2, ...)
    recv = string.format("%s %s", recv_name, recv)
  end

  utils.log(#arg, recv_name, recv, iface)
  local dir = vfn.fnameescape(vfn.expand("%:p:h"))

  impl_cmd = { impl_cmd, "-dir", dir, recv, iface }
  utils.log(impl_cmd)
  -- vim.cmd("normal! $%") -- do a bracket match. changed to treesitter
  local opts = {
    update_buffer = true,
    on_exit = function(code, signal, data)
      if code ~= 0 or signal ~= 0 then
        utils.warn("impl failed" .. vim.inspect(data))
        return
      end
      data = vim.split(data, "\n")
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      --
      vim.schedule(function()
        local pos = vfn.getcurpos()[2]
        table.insert(data, 1, "")
        vfn.append(pos, data)
      end)
    end,
  }
  local runner = require('go.runner')
  runner.run(impl_cmd, opts)

end

local function match_iface_name(part)
  local pkg, iface = string.match(part, "^(.*)%.(.*)$")

  utils.log(pkg, iface)
  local cmd = string.format("go doc %s", pkg)
  local doc = vfn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    utils.warn("go doc failed" .. vim.inspect(doc))
    return
  end

  local ifaces = {}
  local pat = string.format("^type (%s.*) interface", iface)
  for _, line in ipairs(doc) do
    local m = string.match(line, pat)
    if m ~= nil then
      table.insert(ifaces, string.format("%s.%s", pkg, m))
    end
  end
  return ifaces
end

-- function complete(arglead, cmdline, cursorpos)
local function complete(_, cmdline, _)
  local words = vim.split(cmdline, [[%s+]])
  local gopls = require("go.gopls")
  local last = words[#words]

  if string.match(last, "^.+%..*") ~= nil then
    local part = match_iface_name(last)
    if part ~= nil then
      return part
    end
  end

  return vfn.uniq(vfn.sort(gopls.list_pkgs()))
end

return { run = run, complete = complete }
