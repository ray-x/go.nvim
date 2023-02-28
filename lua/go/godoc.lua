local utils = require('go.utils')
local log = utils.log
local gopls = require('go.gopls')
local help_items = {}
local vfn = vim.fn
local m = {}
function m.help_complete(_, _, _)
  if #help_items < 1 then
    local doc = vfn.systemlist('go help')
    if vim.v.shell_error ~= 0 then
      vim.notify(string.format('failed to run go help %d', vim.v.shell_error), vim.log.levels.ERROR)
      return
    end

    for _, line in ipairs(doc) do
      local m1 = string.match(line, '^%s+([%w-]+)')
      if m1 ~= nil and m1 ~= 'go' then
        table.insert(help_items, m1)
      end
    end
    table.sort(help_items)
  end
  return help_items
end

local function match_doc_flag(lead)
  local doc_flags = { '-all', '-c', '-cmd', '-short', '-src', '-u' }

  local items = {}
  local p = string.format('^%s', lead)
  for _, f in ipairs(doc_flags) do
    local k = string.match(f, p)
    log(k, f, p)
    if k then
      table.insert(items, f)
    end
  end
  table.sort(items)
  log(items)

  return items or {}
end

local function match_partial_item_name(pkg, pattern)
  local cmd = string.format('go doc %s', pkg)
  local doc = vfn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    utils.warn('go doc failed', vim.inspect(doc))
    return
  end

  local items = {}
  for _, _type in ipairs({ 'var', 'const', 'func', 'type' }) do
    local patterns = {
      string.format('^%%s*%s (%s%%w+)', _type, pattern),
      string.format('^%%s*%s %%(.-%%) (%s%%w+)', _type, pattern),
    }
    log(patterns)
    for _, line in ipairs(doc) do
      local k
      for _, pat in ipairs(patterns) do
        k = string.match(line, pat)
        if k then
          log(k)
          table.insert(items, k)
          break
        end
      end
    end
  end
  table.sort(items)
  log(items)
  return items
end

function m.doc_complete(_, cmdline, _)
  local words = vim.split(cmdline, '%s+')
  if string.match(words[#words], '^-') then
    log(words)
    return match_doc_flag(words[#words])
  end

  if #words > 2 and string.match(words[#words - 1], '^-') == nil then
    local pkg = words[#words - 1]
    local item = words[#words]
    return match_partial_item_name(pkg, item)
  elseif #words > 1 and string.match(words[#words], '^[^-].+%..*') ~= nil then
    local pkg, item, method = unpack(vim.split(words[#words], '%.'))
    if method then
      pkg = string.format('%s.%s', pkg, item)
      item = method
    end
    local comps = match_partial_item_name(pkg, item)
    for i, comp in ipairs(comps or {}) do
      comps[i] = string.format('%s.%s', pkg, comp)
    end
    return comps or {}
  elseif #words >= 1 and not string.match(words[#words], '^-') then
    local pkgs = gopls.list_pkgs()
    if pkgs then
      local match = {}
      if #words > 1 and #words[#words] > 0 then
        for _, value in ipairs(pkgs) do
          if string.match(value, words[#words]) then
            table.insert(match, value)
          end
        end
      else
        match = pkgs
      end
      log(match)
      return match or {}
    end
  end
  return ''
end

m.run = function(fargs)
  log(fargs)

  if vim.fn.empty(fargs) == 1 then
    return vim.lsp.buf.hover()
  end

  local setup = { 'go', 'doc', unpack(fargs or {}) }
  --
  return vfn.jobstart(setup, {
    on_stdout = function(_, data, _)
      log(data)
      data = utils.handle_job_data(data)
      if not data then
        return
      end

      local close_events = { 'CursorMoved', 'CursorMovedI', 'BufHidden', 'InsertCharPre' }
      local config = { close_events = close_events, focusable = true, border = 'single' }
      vim.lsp.util.open_floating_preview(data, 'go', config)
    end,
  }),
    setup
end
return m
