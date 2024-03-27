local util = {}
local fn = vim.fn

local uv = vim.loop
local os_name = uv.os_uname().sysname
local is_windows = os_name == 'Windows' or os_name == 'Windows_NT' or os_name:find('MINGW')
local is_git_shell = is_windows
  and (vim.fn.exists('$SHELL') and vim.fn.expand('$SHELL'):find('bash.exe') ~= nil)

local HASNVIM0_9 = vim.fn.has('nvim-0.9') == 1
util.get_node_text = vim.treesitter.get_node_text
if not HASNVIM0_9 or util.get_node_text == nil then
  util.get_node_text = vim.treesitter.query.get_node_text
end

local nvim_exec = vim.api.nvim_exec2
if nvim_exec == nil then
  nvim_exec = vim.api.nvim_exec
end

-- Check whether current buffer contains main function
function util.has_main()
  local output = nvim_exec('grep func\\ main\\(\\) %', true)
  local matchCount = vim.split(output, '\n')

  return #matchCount > 3
end

function util.sep()
  if is_windows then
    return '\\'
  end
  return '/'
end

function util.sep2()
  if is_windows then
    return ';'
  end
  return ':'
end

function util.is_windows()
  return is_windows
end

function util.ext()
  if is_windows then
    return '.exe'
  end
  return ''
end

local function get_path_sep()
  if is_windows then
    return ';'
  end
  return ':'
end

local function strip_path_sep(path)
  local l = path[#path]
  util.log(l, util.sep(), path:sub(1, #path - 1))
  if l == util.sep() then
    return path:sub(1, #path - 1)
  end
  return path
end

function util.root_dirs()
  local dirs = {}
  local root = fn.systemlist({ _GO_NVIM_CFG.go, 'env', 'GOROOT' })
  table.insert(dirs, root[1])
  local paths = fn.systemlist({ _GO_NVIM_CFG.go, 'env', 'GOPATH' })
  local sp = get_path_sep()

  paths = vim.split(paths[1], sp)
  for _, p in pairs(paths) do
    p = fn.substitute(p, '\\\\', '/', 'g')
    table.insert(dirs, p)
  end
  return dirs
end

function util.go_packages(dirs, arglead)
  util.log(debug.traceback())
  local pkgs = {}
  for _, dir in pairs(dirs) do
    util.log(dir)
    local scr_root = fn.expand(dir .. util.sep() .. 'src' .. util.sep())
    util.log(scr_root, arglead)
    local roots = fn.globpath(scr_root, arglead .. '*', 0, 1)
    if roots == { '' } then
      roots = {}
    end

    util.log(roots)
    for _, pkg in pairs(roots) do
      util.log(pkg)

      if fn.isdirectory(pkg) then
        pkg = pkg .. util.sep()
        table.insert(pkgs, pkg)
      elseif not pkg:match([[%.a$]]) then
        -- without this the result can have duplicates in form of
        -- 'encoding/json' and '/encoding/json/'
        pkg = strip_path_sep(pkg)

        -- remove the scr root and keep the package in tact
        pkg = fn.substitute(pkg, scr_root, '', '')
        table.insert(pkgs, pkg)
      end
    end
  end
  util.log(pkgs)
  return pkgs
end

-- function! s:interface_list(pkg) abort
--   let [contents, err] = go#util#Exec(['go', 'doc', a:pkg])
--   if err
--     return []
--   endif
--
--   let contents = split(contents, "\n")
--   call filter(contents, 'v:val =~# ''^type\s\+\h\w*\s\+interface''')
--   return map(contents, 'a:pkg . "." . matchstr(v:val, ''^type\s\+\zs\h\w*\ze\s\+interface'')')
-- endfunction

function util.interface_list(pkg)
  local p = fn.systemlist({ _GO_NVIM_CFG.go, 'doc', pkg })
  util.log(p)
  local ifaces = {}
  if p then
    local contents = p -- vim.split(p[1], "\n")
    for _, content in pairs(contents) do
      util.log(content)
      if content:find('interface') then
        local iface_name = fn.matchstr(content, [[^type\s\+\zs\h\w*\ze\s\+interface]])
        if iface_name ~= '' then
          table.insert(ifaces, pkg .. iface_name)
        end
      end
    end
  end
  util.log(ifaces)
  return ifaces
end

-- https://alpha2phi.medium.com/neovim-101-regular-expression-f15a6d782add
function util.get_fname_num(line)
  line = util.trim(line)

  local reg = [[\(.\+\.go\)\:\(\d\+\):]]
  local f = fn.matchlist(line, reg)
  if f[1] and f[1] ~= '' then
    return f[2], tonumber(f[3])
  end
end

function util.smartrun()
  local cmd
  if util.has_main() then
    cmd = string.format('lcd %:p:h | :set makeprg=%s\\ run\\ . | :make | :lcd -', _GO_NVIM_CFG.go)
    vim.cmd(cmd)
  else
    cmd = string.format('setl makeprg=%s\\ run\\ . | :make', _GO_NVIM_CFG.go)
    vim.cmd(cmd)
  end
end

function util.smartbuild()
  local cmd
  if util.has_main() then
    cmd = string.format('lcd %:p:h | :set makeprg=%s\\ build\\ . | :make | :lcd -', _GO_NVIM_CFG.go)
    vim.cmd(cmd)
  else
    cmd = string.format('setl makeprg=%s\\ build\\ . | :make', _GO_NVIM_CFG.go)
    vim.cmd(cmd)
  end
end

util.check_same = function(tbl1, tbl2)
  if #tbl1 ~= #tbl2 then
    return false
  end
  for k, v in ipairs(tbl1) do
    if v ~= tbl2[k] then
      return false
    end
  end
  return true
end

util.map = function(modes, key, result, options)
  options =
    util.merge({ noremap = true, silent = false, expr = false, nowait = false }, options or {})
  local buffer = options.buffer
  options.buffer = nil

  if type(modes) ~= 'table' then
    modes = { modes }
  end

  for i = 1, #modes do
    if buffer then
      vim.api.nvim_buf_set_keymap(0, modes[i], key, result, options)
    else
      vim.api.nvim_set_keymap(modes[i], key, result, options)
    end
  end
end

util.copy_array = function(from, to)
  for i = 1, #from do
    to[i] = from[i]
  end
end

util.deepcopy = function(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[util.deepcopy(orig_key)] = util.deepcopy(orig_value)
    end
    setmetatable(copy, util.deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

util.handle_job_data = function(data)
  if not data then
    return nil
  end
  -- Because the nvim.stdout's data will have an extra empty line at end on some OS (e.g. maxOS), we should remove it.
  for _ = 1, 3, 1 do
    if data[#data] == '' then
      table.remove(data, #data)
    end
  end
  if #data < 1 then
    return nil
  end
  -- remove ansi escape code
  for i, v in ipairs(data) do
    data[i] = util.remove_ansi_escape(data[i])
  end

  return data
end

local function fs_write(path, data)
  local uv = vim.uv or vim.loop

  -- Open the file in append mode
  uv.fs_open(path, 'a', tonumber('644', 8), function(open_err, fd)
    if open_err then
      -- Handle error in opening file
      print('Error opening file: ' .. open_err)
      return
    end

    -- Write data to the file
    uv.fs_write(fd, data, -1, function(write_err)
      if write_err then
        -- Handle error in writing to file
        print('Error writing to file: ' .. write_err)
      end

      -- Close the file descriptor
      uv.fs_close(fd, function(close_err)
        if close_err then
          -- Handle error in closing file
          print('Error closing file: ' .. close_err)
        end
      end)
    end)
  end)
end


local cache_dir = fn.stdpath('cache')
util.log = function(...)
  if not _GO_NVIM_CFG or not _GO_NVIM_CFG.verbose then
    return
  end
  local arg = { ... }

  local log_default = string.format('%s%sgonvim.log', cache_dir, util.sep())

  local log_path = _GO_NVIM_CFG.log_path or log_default
  local str = '  '

  local info = debug.getinfo(2, 'Sl')
  str = str .. info.short_src .. ':' .. info.currentline
  local _, ms = uv.gettimeofday()
  str = string.format('[%s %d] %s', os.date(), ms, str)
  for i, v in ipairs(arg) do
    if type(v) == 'table' then
      str = str .. ' |' .. tostring(i) .. ': ' .. vim.inspect(v or 'nil') .. '\n'
    else
      str = str .. ' |' .. tostring(i) .. ': ' .. tostring(v or 'nil')
    end
  end
  if #str > 2 then
    if log_path ~= nil and #log_path > 3 then
      fs_write(log_path, str .. '\n')
    else
      vim.notify(str .. '\n', vim.log.levels.DEBUG)
    end
  end
end

util.trace = function(...) end

local rhs_options = {}

function rhs_options:new()
  local instance = {
    cmd = '',
    options = { noremap = false, silent = false, expr = false, nowait = false },
  }
  setmetatable(instance, self)
  self.__index = self
  return instance
end

function rhs_options:map_cmd(cmd_string)
  self.cmd = cmd_string
  return self
end

function rhs_options:map_cr(cmd_string)
  self.cmd = (':%s<CR>'):format(cmd_string)
  return self
end

function rhs_options:map_args(cmd_string)
  self.cmd = (':%s<Space>'):format(cmd_string)
  return self
end

function rhs_options:map_cu(cmd_string)
  self.cmd = (':<C-u>%s<CR>'):format(cmd_string)
  return self
end

function rhs_options:with_silent()
  self.options.silent = true
  return self
end

function rhs_options:with_noremap()
  self.options.noremap = true
  return self
end

function rhs_options:with_expr()
  self.options.expr = true
  return self
end

function rhs_options:with_nowait()
  self.options.nowait = true
  return self
end

function util.map_cr(cmd_string)
  local ro = rhs_options:new()
  return ro:map_cr(cmd_string)
end

function util.map_cmd(cmd_string)
  local ro = rhs_options:new()
  return ro:map_cmd(cmd_string)
end

function util.map_cu(cmd_string)
  local ro = rhs_options:new()
  return ro:map_cu(cmd_string)
end

function util.map_args(cmd_string)
  local ro = rhs_options:new()
  return ro:map_args(cmd_string)
end

function util.nvim_load_mapping(mapping)
  for key, value in pairs(mapping) do
    local mode, keymap = key:match('([^|]*)|?(.*)')
    if type(value) == 'table' then
      local rhs = value.cmd
      local options = value.options
      vim.api.nvim_set_keymap(mode, keymap, rhs, options)
    end
  end
end
util.loaded = {}
function util.load_plugin(name, modulename)
  assert(name ~= nil, 'plugin should not empty')
  modulename = modulename or name
  local has, plugin = pcall(require, modulename)
  if has then
    return plugin
  end
  if util.loaded[name] then
    return nil -- already loaded/tried
  end
  util.loaded[name] = true
  local pkg = packer_plugins

  local has_packer = pcall(require, 'packer')
  local has_lazy = pcall(require, 'lazy')
  if has_packer or has_lazy then
    -- packer installed
    if has_packer then
      local loader = require('packer').loader
      if not pkg[name] or not pkg[name].loaded then
        util.log('packer loader ' .. name)
        vim.cmd('packadd ' .. name) -- load with default
        if pkg[name] ~= nil then
          loader(name)
        end
      end
    else
      if not require('lazy.core.config').plugins[name] then
        util.log('lazy loader failed not installed ' .. name)
      else
        require('lazy').load({ plugins = name })
      end
    end
  else
    util.log('packadd ' .. name)
    local paths = vim.o.runtimepath
    if paths:find(name) then
      vim.cmd('packadd ' .. name)
    end
  end

  has, plugin = pcall(require, modulename)
  if not has then
    util.info('plugin ' .. name .. ' module ' .. modulename .. '  not loaded ')
    return nil
  end
  return plugin
end

-- deprecated
-- function util.check_capabilities(feature, client_id)
--   local clients = vim.lsp.buf_get_clients(client_id or 0)
--
--   local supported_client = false
--   for _, client in pairs(clients) do
--     -- util.log(client.resolved_capabilities)
--     util.log(client.server_capabilities)
--     supported_client = client.resolved_capabilities[feature]
--     supported_client = client.resolved_capabilities[feature]
--     if supported_client then
--       break
--     end
--   end
--
--   if supported_client then
--     return true
--   else
--     if #clients == 0 then
--       util.log("LSP: no client attached")
--     else
--       util.log("LSP: server does not support " .. feature)
--     end
--     return false
--   end
-- end

function util.relative_to_cwd(name)
  local rel = fn.isdirectory(name) == 0 and fn.fnamemodify(name, ':h:.')
    or fn.fnamemodify(name, ':.')
  if rel == '.' then
    return '.'
  else
    return '.' .. util.sep() .. rel
  end
end

function util.chdir(dir)
  if fn.exists('*chdir') then
    return fn.chdir(dir)
  end

  local oldir = fn.getcwd()
  local cd = 'cd'
  if fn.exists('*haslocaldir') and fn.haslocaldir() then
    cd = 'lcd'
    vim.cmd(cd .. ' ' .. fn.fnameescape(dir))
    return oldir
  end
end

function util.all_pkgs()
  return '.' .. util.sep() .. '...'
end

-- log and messages
function util.warn(msg)
  vim.schedule(function()
    vim.notify('WARN: ' .. msg, vim.log.levels.WARN)
  end)
end

function util.error(msg)
  vim.schedule(function()
    vim.notify('ERR: ' .. msg, vim.log.levels.ERROR)
  end)
end

function util.info(msg)
  vim.schedule(function()
    vim.notify('INFO: ' .. msg, vim.log.levels.INFO)
  end)
end

function util.debug(msg)
  vim.schedule(function()
    vim.notify('DEBUG: ' .. msg, vim.log.levels.DEBUG)
  end)
end

function util.rel_path(folder)
  -- maybe expand('%:p:h:t')
  local mod = '%:p'
  if folder then
    mod = '%:p:h'
  end
  local fpath = fn.expand(mod)
  -- workfolders does not work if user does not setup neovim to follow workspace
  local workfolders = vim.lsp.buf.list_workspace_folders()
  local pwd = fn.getcwd()

  if fn.empty(workfolders) == 0 then
    if workfolders[1] ~= pwd then
      vim.notify('current dir is not workspace dir', vim.log.levels.DEBUG)
      -- change current folder to workspace folder
      vim.cmd('cd ' .. workfolders[1])
    end
    fpath = '.' .. fpath:sub(#workfolders[1] + 1)
  else
    fpath = fn.fnamemodify(fn.expand(mod), ':p:.')
  end

  util.log(fpath:sub(#fpath), fpath, util.sep())
  if fpath:sub(#fpath) == util.sep() then
    fpath = fpath:sub(1, #fpath - 1)
    util.log(fpath)
  end
  return fpath
end

function util.trim(s)
  if s then
    s = util.ltrim(s)
    return util.rtrim(s)
  end
end

function util.rtrim(s)
  local n = #s
  while n > 0 and s:find('^%s', n) do
    n = n - 1
  end
  return s:sub(1, n)
end

function util.ltrim(s)
  return (s:gsub('^%s*', ''))
end

function util.work_path()
  local fpath = fn.expand('%:p:h')
  local workfolders = vim.lsp.buf.list_workspace_folders()
  if #workfolders == 1 then
    return workfolders[1]
  end

  for _, value in pairs(workfolders) do
    local mod = value .. util.sep() .. 'go.mod'
    if util.file_exists(mod) then
      return value
    end
  end

  return workfolders[1] or fpath
end

function util.empty(t)
  if t == nil then
    return true
  end
  if type(t) ~= 'table' then
    return false
  end
  return next(t) == nil
end

local open = io.open

function util.read_file(path)
  local file = open(path, 'rb') -- r read mode and b binary mode
  if not file then
    return nil
  end
  local content = file:read('*a') -- *a or *all reads the whole file
  file:close()
  return content
end

function util.restart(cmd_args)
  local old_lsp_client = require('go.lsp').client()
  local configs = require('lspconfig.configs')
  if old_lsp_client then
    vim.lsp.stop_client(old_lsp_client.id)
  end

  if configs['gopls'] ~= nil then
    vim.defer_fn(function()
      configs['gopls'].launch()
    end, 500)
  end
end

util.deletedir = function(dir)
  local lfs = require('lfs')
  for file in lfs.dir(dir) do
    local file_path = dir .. '/' .. file
    if file ~= '.' and file ~= '..' then
      if lfs.attributes(file_path, 'mode') == 'file' then
        os.remove(file_path)
        print('remove file', file_path)
      elseif lfs.attributes(file_path, 'mode') == 'directory' then
        print('dir', file_path)
        util.deletedir(file_path)
      end
    end
  end
  lfs.rmdir(dir)
  util.log('remove dir', dir)
end

function util.file_exists(name)
  local f = io.open(name, 'r')
  if f ~= nil then
    io.close(f)
    return true
  end
  return false
end

-- get all lines from a file, returns an empty
-- list/table if the file does not exist
function util.lines_from(file)
  if not util.file_exists(file) then
    return {}
  end
  local lines = {}
  for line in io.lines(file) do
    lines[#lines + 1] = line
  end
  return lines
end

function util.list_directory()
  return fn.map(fn.glob(fn.fnameescape('./') .. '/{,.}*/', 1, 1), 'fnamemodify(v:val, ":h:t")')
end

function util.get_active_buf()
  local lb = fn.getbufinfo({ buflisted = 1 })
  util.log(lb)
  local result = {}
  for _, item in ipairs(lb) do
    if fn.empty(item.name) == 0 and item.hidden == 0 then
      util.log('buf loaded', item.name)
      table.insert(result, { name = fn.shellescape(item.name), bufnr = item.bufnr })
    end
  end

  return result
end

-- for l:item in l:blist
--     "skip unnamed buffers; also skip hidden buffers?
--     if empty(l:item.name) || l:item.hidden
--         continue
--     endif
--     call add(l:result, shellescape(l:item.name))
-- return l:result

function util.set_nulls()
  if _GO_NVIM_CFG.null_ls_document_formatting_disable then
    local query = {}
    if type(_GO_NVIM_CFG.null_ls_document_formatting_disable) ~= 'boolean' then
      query = _GO_NVIM_CFG.null_ls_document_formatting_disable
    end
    local ok, nulls = pcall(require, 'null-ls')
    if ok then
      nulls.disable(query)
    end
  end
end

-- run in current source code path
function util.exec_in_path(cmd, bufnr, ...)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path
  if type(bufnr) == 'string' then
    path = bufnr
  else
    path = fn.fnamemodify(fn.bufname(bufnr), ':p:h')
  end
  local dir = util.chdir(path)
  local result
  if type(cmd) == 'function' then
    result = cmd(bufnr, ...)
  else
    result = fn.systemlist(cmd, ...)
  end
  util.log(result)
  util.chdir(dir)
  return result
end

function util.line_ending()
  if vim.o.fileformat == 'dos' then
    return '\r\n'
  elseif vim.o.fileformat == 'mac' then
    return '\r'
  end
  return '\n'
end

function util.offset(line, col)
  util.log(line, col)
  if vim.o.encoding ~= 'utf-8' then
    print('only utf-8 encoding is supported current encoding: ', vim.o.encoding)
  end
  return fn.line2byte(line) + col - 2
end

-- parse //+build integration unit
-- //go:build ci
function util.get_build_tags(buf)
  local tags = {}
  buf = buf or '%'
  local pattern = [[^//\s*[+|(go:)]*build\s\+\(.\+\)]]
  local cnt = vim.fn.getbufinfo(buf)[1]['linecount']
  cnt = math.min(cnt, 10)
  for i = 1, cnt do
    local line = vim.fn.trim(vim.fn.getbufline(buf, i)[1])
    if string.find(line, 'package') then
      break
    end
    local t = vim.fn.substitute(line, pattern, [[\1]], '')
    if t ~= line then -- tag found
      t = vim.fn.substitute(t, [[ \+]], ',', 'g')
      table.insert(tags, t)
    end
  end
  if #tags > 0 then
    return tags
  end
end

-- a uuid
function util.uuid()
  math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 9)))
  local random = math.random
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
    return string.format('%x', v)
  end)
end

local lorem =
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum'
function util.lorem()
  return lorem
end

function util.random_words(len)
  local str = util.lorem()
  local words = fn.split(str, ' ')
  str = ''
  for i = 1, len do
    str = str .. ' ' .. words[math.random(#words)]
  end
  return str
end

function util.random_line()
  local lines = vim.split(lorem, ', ')
  return lines[math.random(#lines)] .. ','
end

function util.run_command(cmd, ...)
  local result = fn.systemlist(cmd, ...)
  return result
end

function util.quickfix(cmd)
  if _GO_NVIM_CFG.trouble == true then
    local ok, trouble = pcall(require, 'trouble')
    if ok then
      if cmd:find('copen') then
        trouble.open('quickfix')
      else
        trouble.open('loclist')
      end
    else
      vim.notify('trouble not found')
    end
  else
    vim.cmd(cmd)
  end
end

util.throttle = function(func, duration)
  local timer = uv.new_timer()
  -- util.log(func, duration)
  local function inner(...)
    -- util.log('throttle', ...)
    if not timer:is_active() then
      timer:start(duration, 0, function() end)
      pcall(vim.schedule_wrap(func), select(1, ...))
    end
  end

  local group = vim.api.nvim_create_augroup('gonvim__CleanupLuvTimers', {})
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    pattern = '*',
    callback = function()
      if timer then
        if timer:has_ref() then
          timer:stop()
          if not timer:is_closing() then
            timer:close()
          end
        end
        timer = nil
      end
    end,
  })

  return inner, timer
end

-- function M.debounce_trailing(ms, fn)
--   local timer = uv.new_timer()
--   return function(...)
--     local argv = { ... }
--     if timer:is_active() then
--       timer:stop()
--       return
--     end
--     timer:start(ms, 0, function()
--       timer:stop()
--       fn(unpack(argv))
--     end)
--   end
-- end
--
util.debounce = function(func, ms)
  local timer = uv.new_timer()
  local function inner(...)
    local argv = { ... }
    if not timer:is_active() then
      timer:start(ms, 0, function()
        timer:stop()
        pcall(vim.schedule_wrap(func), unpack(argv))
      end)
    end
  end
  return inner, timer
end

local namepath = {}

util.extract_filepath = function(msg, pkg_path)
  msg = msg or ''
  -- util.log(msg)
  --[[     or [[    findAllSubStr_test.go:234: Error inserting caseResult1: operation error DynamoDB: PutItem, exceeded maximum number of attempts]]
  -- or 'path/path2/filename.go:50:11: Error invaild
  -- or /home/ray/go/src/github/sample/app/driver.go:342 +0x19e5
  local ma = fn.matchlist(msg, [[\v\s*(\w+.+\.go):(\d+):]])
  ma = ma or fn.matchlist(msg, [[\v\s*(\w+.+\.go):(\d+)]])
  local filename, lnum
  if ma[2] then
    util.log(ma)
    filename = ma[2]
    lnum = ma[3]
  else
    return
  end
  util.log('fname : ' .. (filename or 'nil') .. ':' .. (lnum or '-1'))

  if namepath[filename] then
    --  if name is same, no need to update path
    return (namepath[filename] ~= filename), namepath[filename], lnum
  end
  if vim.fn.filereadable(filename) == 1 then
    util.log('filename', filename)
    -- no need to extract path, already quickfix format
    namepath[filename] = filename
    return false, filename, lnum
  end

  if pkg_path then
    local pn = pkg_path:gsub('%.%.%.', '')
    local fname = pn .. util.sep() .. filename
    if vim.fn.filereadable(fname) == 1 then
      namepath[filename] = fname
      util.log('fname with pkg_name', fname)
      return true, fname, lnum
    end
  end

  local fname = fn.fnamemodify(fn.expand('%:h'), ':~:.') .. util.sep() .. ma[2]
  util.log(fname, namepath[fname])
  if vim.fn.filereadable(fname) == 1 then
    namepath[filename] = fname
    return true, fname, lnum
  end

  if namepath[filename] ~= nil then
    util.log(namepath[filename])
    return namepath[filename], lnum
  end
  if vim.fn.executable('find') == 0 then
    return false, fname, lnum
  end
  -- note: slow operations
  local cmd = 'find ./ -type f -name ' .. "'" .. filename .. "'"
  local path = vim.fn.systemlist(cmd)

  if vim.v.shell_error ~= 0 then
    util.warn('find failed ' .. cmd .. vim.inspect(path))
  end
  for _, value in pairs(path) do
    local st, _ = value:find(filename)
    if st then
      -- find cmd returns `./path/path2/filename.go`, the leading './' is not needed for quickfix
      local p = value:sub(1, st - 1)
      util.log(value, st, p)
      namepath[filename] = p
      return true, p, lnum
    end
  end
  -- nothing... we will not check this file again
  namepath[filename] = filename
end

util.remove_ansi_escape = function(str)
  local ansi_escape_pattern = '\27%[%d+;%d*;%d*m'
  -- Replace all occurrences of the pattern with an empty string
  str = str:gsub(ansi_escape_pattern, '')
  str = str:gsub('\27%[[%d;]*%a', '')
  return str
end

-- Keeps track of tools that are already installed.
-- The keys are the names of tools and the values are booleans
-- indicating whether the tools is available or not.
util.installed_tools = {}

-- Check if host has goenv in path.
util.goenv_mode = function()
  if is_windows then
    -- always return false for Windows because goenv doesn't seem to be supported there.
    return false
  end

  local cmd = 'command -v goenv > /dev/null 2>&1'
  local status = os.execute(cmd)
  return status == 0
end

return util
