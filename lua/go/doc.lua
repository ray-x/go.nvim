local M = {}
local utils = require('go.utils')
local log = utils.log
local gopls = require('go.gopls')
local help_items = {}
function M.help_complete(arglead, cmdline, cursorPos)
  if #help_items < 1 then
    local doc = vim.fn.systemlist('go help')
    if vim.v.shell_error ~= 0 then
      return
    end

    for _, line in ipairs(doc) do
      local m = string.match(line, '^%s+([%w%p]+)')
      if m ~= nil and m ~= 'go' then
        table.insert(help_items, m)
      end
    end
    table.sort(help_items)
  end
  return table.concat(help_items, '\n')
end

local function match_partial_item_name(pkg, pattern)
  local cmd = string.format('go doc %s', pkg)
  local doc = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return
  end

  local items = {}
  for _, _type in ipairs {'var', 'const', 'func', 'type'} do
    local patterns = {
      string.format('^%%s*%s (%s%%w+)', _type, pattern),
      string.format('^%%s*%s %%(.-%%) (%s%%w+)', _type, pattern)
    }
    log(patterns)
    for _, line in ipairs(doc) do
      local m
      for _, pat in ipairs(patterns) do
        m = string.match(line, pat)
        if m then
          log(m)
          table.insert(items, m)
          break
        end
      end
    end
  end
  table.sort(items)
  log(items)
  return items
end

function M.doc_complete(arglead, cmdline, cursorPos)
  log(arglead, cmdline)
  local words = vim.split(cmdline, '%s+')
  if #words > 2 and string.match(words[#words - 1], '^-') == nil then
    local pkg = words[#words - 1]
    local item = words[#words]
    return table.concat(match_partial_item_name(pkg, item), '\n')
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
    return table.concat(comps or {}, '\n')
  elseif #words > 1 and string.match(words[#words], '^-') == nil then
    local result = gopls.list_known_packages()
    if result and result.result and result.result.Packages then
      local pkgs = result.result.Packages
      return table.concat(pkgs or {}, '\n')
    end
  end
  return ''
end

--
M.run = function(type, args)

  -- local offset = string.format("%s:#%i", fname, byte_offset)

  local setup = {'go', type}

  vim.list_extend(setup, args)
  local j = vim.fn.jobstart(setup, {
    on_stdout = function(jobid, data, event)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      -- log(data)
      local close_events = {"CursorMoved", "CursorMovedI", "BufHidden", "InsertCharPre"}
      local config = {close_events = close_events, focusable = true, border = 'single'}
      vim.lsp.util.open_floating_preview(data, 'go', config)
      -- local result = vim.fn.json_decode(data)
      -- if result.errors ~= nil or result.lines == nil or result["start"] == nil or result["start"]  == 0 then
      --   print("failed to get doc" .. vim.inspect(result))
      -- end
    end
  })
end

return M
