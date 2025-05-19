local golist = require('go.list').list
local util = require('go.utils')
local log = util.log
local vfn = vim.fn
local api = vim.api

local path_to_pkg = {}
local pkgs = {}
local complete = function(sep)
  log('complete', sep)
  sep = sep or '\n'
  local ok, l = golist({ util.all_pkgs() })
  if not ok then
    log('Failed to find all packages for current module/project.')
    return
  end
  log(l)
  local curpkgmatch = false
  local curpkg = vfn.fnamemodify(vfn.expand('%'), ':h:.')
  local pf = function()
    for _, p in ipairs(l or {}) do
      local d = vfn.fnamemodify(p.Dir, ':.')
      if curpkg ~= d then
        if d ~= vfn.getcwd() then
          table.insert(pkgs, util.relative_to_cwd(d))
        end
      else
        curpkgmatch = true
      end
    end
    table.sort(pkgs)
    table.insert(pkgs, util.all_pkgs())
    table.insert(pkgs, '.')
    if curpkgmatch then
      table.insert(pkgs, util.relative_to_cwd(curpkg))
    end
  end
  if vim.fn.empty(pkgs) == 0 then
    vim.defer_fn(function()
      pf()
    end, 1)
    return pkgs
  else
    pf()
    return pkgs
  end
end

local all_pkgs = function()
  local ok, l = golist({ util.all_pkgs() })
  if not ok then
    log('Failed to find all packages for current module/project.')
  end
  return l
end

-- short form of go list
local all_pkgs2 = function()
  local l = require('go.list').list_pkgs()
  if not l then
    log('Failed to find all packages for current module/project.')
  end
  return l
end

local pkg_from_path = function(pkg, bufnr)
  local cmd = { 'go', 'list' }
  if pkg ~= nil then
    table.insert(cmd, pkg)
  end
  log(cmd)
  return util.exec_in_path(cmd, bufnr)
end

local show_float = function(result)
  local textview = util.load_plugin('guihua.lua', 'guihua.textview')
  if not textview then
    util.log('Failed to load guihua.textview')

    vim.fn.setloclist(0, {}, 'r', {
      title = 'go package outline',
      lines = result,
    })
    util.quickfix('lopen')
    return
  end
  local win = textview:new({
    relative = 'cursor',
    syntax = 'lua',
    rect = { height = math.min(40, #result), pos_x = 0, pos_y = 10 },
    data = result,
  })
  log('draw data', result)
  vim.api.nvim_buf_set_option(win.buf, 'filetype', 'go')
  return win:on_draw(result)
end

local defs
local render_outline = function(result)
  if not result then
    log('result nil', debug.traceback())
    return
  end
  local fname = vim.fn.tempname() .. '._go' -- avoid lsp activation
  log('tmp: ' .. fname)
  local uri = vim.uri_from_fname(fname)
  local bufnr = vim.uri_to_bufnr(uri)
  vim.fn.writefile(result, fname)
  vfn.bufload(bufnr)
  defs = require('go.ts.utils').list_definitions_toc(bufnr)
  if vfn.empty(defs) == 1 then
    vim.notify('No definitions found in package.')
    return
  end
  return bufnr, fname
end

local outline
local render
local show_panel = function(result, pkg, rerender)
  local bufnr, fname = render_outline(result)
  if rerender or not defs then
    return true -- just re-gen the outline
  end

  log('defs 1', defs and defs[1])
  local panel = util.load_plugin('guihua.lua', 'guihua.panel')
  local pkg_name = pkg or 'pkg'
  pkg_name = vfn.split(pkg_name, '/')
  pkg_name = pkg_name[#pkg_name] or 'pkg'
  log('create panel')
  if panel then
    local p = panel:new({
      header = '  󰏖  ' .. pkg_name .. '   ',
      render = function(b)
        log('render for ', bufnr, b)
        -- log(debug.traceback())
        -- outline("-r")
        render()
        return defs
      end,
      on_confirm = function(n)
        log('on_confirm symbol ', n)
        if not n or not n.symbol then
          log('info missing: symbol ', n)
          return
        end
        -- need to change to main window first to enable gopls
        local wins = api.nvim_list_wins()
        local panel_win = api.nvim_get_current_win()
        log(wins, panel_win)
        local cur_win
        for _, w in ipairs(wins) do
          if w ~= panel_win then
            api.nvim_set_current_win(w)
            local cur = api.nvim_win_get_cursor(w)
            api.nvim_win_set_cursor(w, cur)
            cur_win = w
            break
          end
        end

        vim.lsp.buf_request(0, 'workspace/symbol', { query = "'" .. n.symbol }, function(e, lsp_result, ctx)
          local filtered = {}
          for _, r in pairs(lsp_result) do
            local container = r.containerName
            if pkg == container and r.name == n.symbol then
              table.insert(filtered, r)
            end
          end
          log('filtered', filtered)
          if #filtered == 0 then
            log('nothing found fallback to result', pkg, n.symbol)
            filtered = lsp_result
          end

          if vfn.empty(filtered) == 1 then
            log(e, lsp_result, ctx)
            vim.notify('no symbol found for ' .. vim.inspect(pkg))
            return false
          end
          if #filtered == 1 then
            -- jump to pos
            local loc = filtered[1].location
            local buf = vim.uri_to_bufnr(loc.uri)
            vfn.bufload(buf)
            api.nvim_set_current_win(cur_win)
            api.nvim_set_current_buf(buf)
            api.nvim_win_set_buf(cur_win, buf)
            api.nvim_win_set_cursor(cur_win, { loc.range.start.line + 1, loc.range.start.character })
          else
            -- lets just call workspace/symbol handler
            vim.lsp.handlers['workspace/symbol'](e, filtered, ctx)
          end
        end)
        -- vim.lsp.buf.workspace_symbol("'" .. n.symbol)
        return n.symbol
      end,
    })
    p:open(true)
  else
    vim.fn.setloclist(0, {}, 'r', {
      title = 'go package outline',
      lines = defs,
    })
    util.quickfix('lopen')
  end
  log('cleanup')
  vim.api.nvim_buf_delete(bufnr, { unload = true })
  os.remove(fname)
end

local show_pkg_panel = function(result, pkg, rerender)
  local gopls = require('go.gopls')
  gopls.package_symbols({}, function(result)
    -- log('gopls package symbols', result)
    if not result or vim.tbl_isempty(result) or vim.tbl_isempty(result.Symbols) then
      vim.notify('no symbols found')
      return
    end
    local files = result.Files
    local items = {}
    local kinds = require('guihua.lspkind').symbol_kind
    for i = 1, #result.Symbols do
      item = result.Symbols[i]
      -- items[i].node_text = items[i].detail
      item.uri =files[(item.file or 0) + 1]
      item.filename = vim.uri_to_fname(item.uri)
      item.kind = kinds(item.kind)
      item.text = item.kind .. item.name
      item.lnum = item.range.start.line + 1

      table.insert(items, item)
      if item.children then
        local prefix = '  ┊ '
        for j = 1, #item.children do
          -- if j == 1 then
          --   prefix = ' 󱞩 '
          -- else
          --   prefix = '  '
          -- end
          local child = item.children[j]
          child.lnum = child.range.start.line + 1
          child.uri = files[(child.file or 0) + 1]
          child.filename = vim.uri_to_fname(child.uri)
          child.kind = kinds(child.kind)
          child.text = prefix .. child.kind .. child.name
          table.insert(items, child)
        end
      end
    end
    log('gopls package symbols', items[1])
    log('gopls package symbols', items[2])
    log('gopls package symbols', items[3])

    local panel = require('guihua.panel')
    local log = require('guihua.log').info
    local p = panel:new({
      header = '  󰏖 ' .. result.PackageName .. '  ',
      render = function(bufnr)
        log('render for ', bufnr)
        return items
      end,
      -- override format function
      -- format = function(item)
        --   return item.indent ..  '>' .. item.node_text
        -- end
      })
      log(p)
      p:open(true)
  end)
end

local gopls_pkg_symbols = function()
  local gopls = require('go.gopls')

end


local pkg_info = {}
-- get package info
local function handle_data_out(_, data, ev)
  data = util.handle_job_data(data)
  if not data then
    return
  end
  pkg_info = {}
  local types = { 'CONSTANTS', 'FUNCTIONS', 'TYPES', 'VARIABLES' }
  for i, val in ipairs(data) do
    -- first strip the filename
    if vim.tbl_contains(types, val) then
      val = '//' .. val
    end

    local sp = string.match(val, '^(%s*)')
    if sp and #sp == 4 then
      val = '//' .. val
    end
    local f = string.match(val, '^func ')
    if f then
      -- incase the func def is mulilines
      local next_line = data[i + 1]
      if next_line then
        local next_sp = string.match(next_line, '^(%s*)') -- one tab in front
        if next_sp and #next_sp == 1 then -- tab size 1
          next_line = next_line .. '{}'
          data[i + 1] = next_line
        else
          val = val .. '{}'
        end
      else
        val = val .. '{}'
      end
    end
    -- log(val)
    table.insert(pkg_info, val)
  end
end

local gen_pkg_info = function(cmd, pkg, arg, rerender)
  log('gen_pkg_info', cmd, pkg, rerender)
  vfn.jobstart(cmd, {
    on_stdout = handle_data_out,
    on_exit = function(e, data, _)
      if data ~= 0 then
        local info = string.format(
          'no packege (%s) \n errcode %s \n cmd: %s \n code %s',
          vim.inspect(pkg),
          e,
          vim.inspect(cmd),
          tostring(data)
        )
        vim.notify(info)
        log(cmd, info, data)
        return
      end
      if arg == '-f' then
        return show_float(pkg_info)
      end
      show_panel(pkg_info, pkg[1], rerender)
    end,
  })
end

local function symbols_to_items(result)
  local locations = {}
  result = result or {}
  log(#result)
  for i = 1, #result do
    local item = result[i].location
    if item ~= nil and item.range ~= nil then
      item.kind = result[i].kind

      local kind
      item.name = result[i].name -- symbol name
      item.text = result[i].name
      if kind ~= nil then
        item.text = kind .. ': ' .. item.text
      end
      if not item.filename then
        item.filename = vim.uri_to_fname(item.uri)
      end
      item.display_filename = item.filename:gsub(cwd .. path_sep, path_cur, 1)
      if item.range == nil or item.range.start == nil then
        log('range not set', result[i], item)
      end
      item.lnum = item.range.start.line + 1

      if item.containerName ~= nil then
        item.text = ' ' .. item.containerName .. item.text
      end
      table.insert(locations, item)
    end
  end
  -- log(locations[1])
  return locations
end



outline = function(...)
  -- log(debug.traceback())
  local arg = select(1, ...)
  local path = vim.fn.expand('%:p:h')
  path = vfn.fnamemodify(path, ':p')

  if arg == '-p' then
    local pkg = select(2, ...)
    if pkg ~= nil then
      path = pkg
    else
      vim.notify('no package provided')
    end
  else
    path = '.' .. util.sep() .. '...' -- how about window?
  end

  local re_render = false
  if arg == '-r' then
    re_render = true
  end
  local pkg = path_to_pkg[path]
  log(path, pkg)
  if not pkg then
    pkg = pkg_from_path(path) -- return list of all packages only check first one
    path_to_pkg[path] = pkg
  end
  if pkg and pkg[1] and pkg[1]:find('does not contain') then
    util.log('no package found for ' .. vim.inspect(path))
    pkg = { '' }
    path_to_pkg[path] = pkg
  end
  if vfn.empty(pkg) == 1 then
    vim.notify('no package found ' .. pkg .. ' in path' .. path)
    util.log('No package found in current directory.')
    local setup = { 'go', 'doc', '-all', '-u', '-cmd' }
    gen_pkg_info(setup, pkg, arg, re_render)
    return
  end
  local setup = { 'go', 'doc', '-all', '-u', '-cmd', pkg[1] }
  gen_pkg_info(setup, pkg, arg, re_render)
end

render = function(bufnr)
  util.log(debug.traceback())
  local fpath = vfn.fnamemodify(vfn.bufname(bufnr or 0), ':p')
  local pkg = path_to_pkg[fpath]
  if not pkg then
    pkg = pkg_from_path('.' .. util.sep() .. '...', bufnr) -- return list of all packages only check first one
    path_to_pkg[fpath] = pkg
  end
  if vfn.empty(pkg) == 1 then
    util.log('No package found in current directory.')
    return nil
  end
  local cmd = { 'go', 'doc', '-all', '-u', '-cmd', pkg[1] }
  log('gen_pkg_info', cmd, pkg)
  vfn.jobstart(cmd, {
    on_stdout = handle_data_out,
    on_exit = function(e, data, _)
      if data ~= 0 then
        log('no packege info data ' .. e .. tostring(data))
        return
      end
      local buf, fname = render_outline()
      log(buf, fname)
    end,
  })
  return defs
end

return {
  complete = complete,
  all_pkgs = all_pkgs,
  all_pkgs2 = all_pkgs2,
  pkg_from_path = pkg_from_path,
  outline = outline,
  symbols = show_pkg_panel,
}

--[[
result of workspacesymbol
{ {
    containerName = "github.com/vendor/packagename/internal/aws",
    kind = 12,
    location = {
      range = {
        end = {
          character = 23,
          line = 39
        },
        start = {
          character = 5,
          line = 39
        }
      },
      uri = "file:///go_home/src/vendor/packagename/internal/aws/aws.go"
    },
    name = "S3EndpointResolver"
  } }
]]
