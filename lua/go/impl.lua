-- local ts_utils = require 'nvim-treesitter.ts_utils'
local utils = require("go.utils")

local impl = "impl"
-- GoImpl f *Foo io.Writer
-- use ts to get name
local function get_struct_name()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local name = require("go.ts.go").get_struct_node_at_pos(row, col)
  if name == nil then
    print("put cursor on struct or specify a receiver")
  end
  utils.log(name)
  name = name.name
  return string.lower(name) .. " *" .. name
end

local run = function(...)
  require("go.install").install(impl)
  local setup = "impl"
  local recv = ""
  local iface = ""

  local arg = { ... }
  if #arg == 0 then
    recv = get_struct_name()

    iface = vim.fn.input("Impl: generating method stubs for interface: ")
    vim.cmd("redraw!")
    -- print("Usage: GoImpl f *File io.Reader")
    if iface == "" then
      print("Impl: please input interface name e.g. io.Reader")
    end
  elseif #arg == 1 then
    -- " i.e: ':GoImpl io.Writer'
    recv = get_struct_name()
    iface = select(1, ...)
  elseif #arg > 2 then
    local l = #arg
    iface = select(l, ...)
    recv = select(l - 1, ...)
    local recv_name = select(l - 2, ...)
    recv = string.format("%s %s", recv_name, recv)
  end

  local dir = vim.fn.fnameescape(vim.fn.expand("%:p:h"))

  setup = string.format("%s -dir %s '%s' %s ", setup, dir, recv, iface)
  utils.log(setup)
  vim.cmd("normal! $%")

  local data = vim.fn.systemlist(setup)

  data = utils.handle_job_data(data)
  if not data then
    return
  end

  utils.log(data)
  local pos = vim.fn.getcurpos()[2]
  vim.fn.append(pos, data)

  -- vim.cmd("silent normal! j=2j")
  vim.fn.setpos(".", pos)
  vim.cmd("silent normal! 4j")
  --
end

local function match_iface_name(part)
  local pkg, iface = string.match(part, "^(.*)%.(.*)$")

  utils.log(pkg, iface)
  local cmd = string.format("go doc %s", pkg)
  local doc = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
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

function complete(arglead, cmdline, cursorpos)
  local words = vim.split(cmdline, [[%s+]])
  local gopls = require("go.gopls")
  local last = words[#words]

  if string.match(last, "^.+%..*") ~= nil then
    local part = match_iface_name(last)
    if part ~= nil then
      return part
    end
  end

  local bnum = vim.api.nvim_get_current_buf()
  return vim.fn.uniq(vim.fn.sort(gopls.list_pkgs(bnum)))
end

return { run = run, complete = complete }
