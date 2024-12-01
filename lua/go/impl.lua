-- local ts_utils = require 'nvim-treesitter.ts_utils'
local utils = require('go.utils')
local log = utils.log
local vfn = vim.fn
local impl = 'impl' -- GoImpl f *Foo io.Writer
-- use ts to get name
local function get_type_name()
  local name = require('go.ts.go').get_struct_node_at_pos()
  if name == nil then
    name = require('go.ts.go').get_type_node_at_pos()
  end
  utils.log(name)
  if name == nil then
    return ''
  end
  local node_name = name.name
  -- let move the cursor to end of line of struct name
  local dim = name.dim.e
  local r, c = dim.r, dim.c
  utils.log('move cusror to ', r, c)
  vim.api.nvim_win_set_cursor(0, { r, c - 1 })
  return node_name, name.type
end

local function get_interface_name()
  local name = require('go.ts.go').get_interface_node_at_pos()

  utils.log(name)
  if name == nil then
    return nil
  end
  local node_name = name.name
  -- let move the cursor to end of line of struct name
  local dim = name.dim.e
  local r, c = dim.r, dim.c
  utils.log('move cusror to ', r, c)
  vim.api.nvim_win_set_cursor(0, { r, c - 1 })

  local pkg = require('go.package').pkg_from_path(nil, vim.api.nvim_get_current_buf())
  log(pkg[1])
  if pkg then
    return pkg[1] .. '.' .. node_name
  end
end

local run = function(...)
  require('go.install').install(impl)
  local impl_cmd = 'impl'
  local iface = ''
  local recv_name = ''
  local arg = { ... }
  utils.log(#arg, arg)

  local recv = get_type_name()
  iface = get_interface_name()

  if #arg == 0 then
    if not iface then
      iface = vfn.input('Impl: generating method stubs for interface: ')
    end
    vim.cmd('redraw!')
    if iface == '' then
      utils.notify(
        'Impl: please input interface name e.g. io.Reader or receiver name e.g. GoImpl MyType'
      )
      -- print("Usage: GoImpl f *File io.Reader")
    end
  elseif #arg == 1 then -- at least interface or type are specified
    -- " i.e: ':GoImpl io.Writer'
    if iface ~= nil then
      recv = select(1, ...)
      recv = string.lower(recv) .. ' *' .. recv
    else
      recv = string.lower(recv) .. ' *' .. recv
      iface = select(1, ...)
    end
    if recv == '' and iface == '' then
      vim.notify('put cursor on struct or a interface or specify a receiver & interface')
    end
    utils.log(recv)
    vim.cmd('redraw!')
  elseif #arg == 2 then
    -- utils.log(recv, iface)
    if iface ~= nil then
      -- " i.e: ':GoImpl s TypeName'
      recv = select(1, ...)
      local recv_type = select(2, ...)
      recv = string.lower(recv) .. ' *' .. recv_type
    else
      recv_name = select(1, ...)
      recv = string.format('%s *%s', string.lower(recv_name), recv_name)
      local l = #arg
      iface = select(l, ...)
    end
  elseif #arg > 2 then
    local l = #arg
    iface = select(l, ...)
    recv = select(l - 1, ...)
    recv_name = select(l - 2, ...)
    recv = string.format('%s %s', recv_name, recv)
  end

  utils.log(#arg, recv_name, recv, iface)
  local dir = vfn.fnameescape(vfn.expand('%:p:h'))

  impl_cmd = { impl_cmd, '-dir', dir, recv, iface }
  utils.log(impl_cmd)
  -- vim.cmd("normal! $%") -- do a bracket match. changed to treesitter
  local opts = {
    update_buffer = true,
    loclist = false,
    on_exit = function(code, signal, data)
      if code ~= 0 or signal ~= 0 then
        utils.warn('impl failed' .. vim.inspect(data))
        return
      end
      data = vim.split(data, '\n')
      data = utils.handle_job_data(data)
      if not data then
        utils.warn('impl failed' .. vim.inspect(data))
        return
      end
      vim.schedule(function()
        local lnum = vfn.getcurpos()[2]
        table.insert(data, 1, '')
        vfn.setpos('.', { 0, lnum, 1, 0 })
        vfn.append(lnum, data)
        vim.cmd('w')
      end)
    end,
  }
  local runner = require('go.runner')
  opts.sprite_enable = false
  runner.run(impl_cmd, opts)
end

local function match_iface_name(part)
  local pkg, iface = string.match(part, '^(.*)%.(.*)$')

  utils.log(pkg, iface)
  local cmd = string.format('go doc %s', pkg)
  local doc = vfn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    utils.warn('go doc failed' .. vim.inspect(doc))
    return
  end

  local ifaces = {}
  local pat = string.format('^type (%s.*) interface', iface)
  for _, line in ipairs(doc) do
    local m = string.match(line, pat)
    if m ~= nil then
      table.insert(ifaces, string.format('%s.%s', pkg, m))
    end
  end
  return ifaces
end

-- function complete(arglead, cmdline, cursorpos)
local function complete(_, cmdline, _)
  local words = vim.split(cmdline, [[%s+]])
  local gopls = require('go.gopls')
  local last = words[#words]
  log(words)
  -- by default complete with local type

  local iface = get_interface_name()
  local query = require('go.ts.go').query_type_declaration
  local bufnr = vim.api.nvim_get_current_buf()
  local all_nodes = function(except)
    local nodes = require('go.ts.nodes').nodes_in_buf(query, 'go', nil, bufnr, 100000, 100000)
    local ns = {}
    log(nodes)
    for _, node in ipairs(nodes) do
      table.insert(ns, node.name)
    end
    if except then
      log('remove', except)
      for i, n in ipairs(ns) do
        if n == except then
          table.remove(ns, i)
          break
        end
      end
      if #words > 1 and #last > 1 then
        local pkgs = vfn.uniq(vfn.sort(gopls.list_pkgs()))
        -- attach ns in front of pkgs
        for _, n in ipairs(ns) do
          table.insert(pkgs, 1, n)
        end
        return pkgs
      else
        return ns
      end
    else
      return vfn.uniq(ns)
    end
  end
  if iface ~= nil then
    local iname = vim.split(iface, '%.')
    iname = iname[#iname]
    log('iface', iface)
    return all_nodes(iname)
  end

  local struct = get_type_name()
  if struct ~= nil then
    log('structs', struct)
    return all_nodes(struct)
  end

  if string.match(last, '^.+%..*') ~= nil then
    local part = match_iface_name(last)
    if part ~= nil then
      return part
    end
  end

  return vfn.uniq(vfn.sort(gopls.list_pkgs()))
end

return { run = run, complete = complete }
