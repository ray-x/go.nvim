local util = {}

local os_name = vim.loop.os_uname().sysname
local is_windows = os_name == "Windows" or os_name == "Windows_NT"
-- Check whether current buffer contains main function
local function has_main()
  local output = vim.api.nvim_exec("grep func\\ main\\(\\) %", true)
  local matchCount = vim.split(output, "\n")

  return #matchCount > 3
end

function util.sep()
  if is_windows then
    return "\\"
  end
  return "/"
end

local function get_path_sep()
  if is_windows then
    return ";"
  end
  return ":"
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
  local root = vim.fn.systemlist({ _GO_NVIM_CFG.go, "env", "GOROOT" })
  table.insert(dirs, root[1])
  local paths = vim.fn.systemlist({ _GO_NVIM_CFG.go, "env", "GOPATH" })
  local sp = get_path_sep()

  paths = vim.split(paths[1], sp)
  for _, p in pairs(paths) do
    p = vim.fn.substitute(p, "\\\\", "/", "g")
    table.insert(dirs, p)
  end
  return dirs
end

function util.go_packages(dirs, arglead)
  util.log(debug.traceback())
  local pkgs = {}
  for _, dir in pairs(dirs) do
    util.log(dir)
    local scr_root = vim.fn.expand(dir .. util.sep() .. "src" .. util.sep())
    util.log(scr_root, arglead)
    local roots = vim.fn.globpath(scr_root, arglead .. "*", 0, 1)
    if roots == { "" } then
      roots = {}
    end

    util.log(roots)
    for _, pkg in pairs(roots) do
      util.log(pkg)

      if vim.fn.isdirectory(pkg) then
        pkg = pkg .. util.sep()
        table.insert(pkgs, pkg)
      elseif not pkg:match([[%.a$]]) then
        -- without this the result can have duplicates in form of
        -- 'encoding/json' and '/encoding/json/'
        pkg = strip_path_sep(pkg)

        -- remove the scr root and keep the package in tact
        pkg = vim.fn.substitute(pkg, scr_root, "", "")
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
  local p = vim.fn.systemlist({ _GO_NVIM_CFG.go, "doc", pkg })
  util.log(p)
  local ifaces = {}
  if p then
    contents = p -- vim.split(p[1], "\n")
    for _, content in pairs(contents) do
      util.log(content)
      if content:find("interface") then
        local iface_name = vim.fn.matchstr(content, [[^type\s\+\zs\h\w*\ze\s\+interface]])
        if iface_name ~= "" then
          table.insert(ifaces, pkg .. iface_name)
        end
      end
    end
  end
  util.log(ifaces)
  return ifaces
end

local function smartrun()
  local cmd
  if has_main() then
    -- Found main function in current buffer
    cmd = string.format("lcd %:p:h | :set makeprg=%s\\ run\\ . | :make | :lcd -", _GO_NVIM_CFG.go)
    vim.cmd(cmd)
  else
    cmd = string.format("setl makeprg=%s\\ run\\ . | :make", _GO_NVIM_CFG.go)
    vim.cmd(cmd)
  end
end

local function smartbuild()
  local cmd
  if has_main() then
    -- Found main function in current buffer
    cmd = string.format("lcd %:p:h | :set makeprg=%s\\ build\\ . | :make | :lcd -", _GO_NVIM_CFG.go)
    vim.cmd(cmd)
  else
    cmd = string.format("setl makeprg=%s\\ build\\ . | :make", _GO_NVIM_CFG.go)
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
  options = util.merge({ noremap = true, silent = false, expr = false, nowait = false }, options or {})
  local buffer = options.buffer
  options.buffer = nil

  if type(modes) ~= "table" then
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
  if orig_type == "table" then
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
  for i = 1, 3, 1 do
    if data[#data] == "" then
      table.remove(data, #data)
    end
  end
  if #data < 1 then
    return nil
  end
  return data
end

local cache_dir = vim.fn.stdpath("cache")
util.log = function(...)
  if not _GO_NVIM_CFG then
    return
  end
  if not _GO_NVIM_CFG.verbose then
    return
  end
  local arg = { ... }

  local log_default = string.format("%s%sgonvim.log", cache_dir, util.sep())

  local log_path = _GO_NVIM_CFG.log_path or log_default
  local str = "  "

  local info = debug.getinfo(2, "Sl")
  str = str .. info.short_src .. ":" .. info.currentline
  for i, v in ipairs(arg) do
    if type(v) == "table" then
      str = str .. " |" .. tostring(i) .. ": " .. vim.inspect(v) .. "\n"
    else
      str = str .. " |" .. tostring(i) .. ": " .. tostring(v)
    end
  end
  if #str > 2 then
    if log_path ~= nil and #log_path > 3 then
      local f, err = io.open(log_path, "a+")
      if err then
        vim.notify("failed to open log" .. log_path .. err, vim.lsp.log_levels.ERROR)
        return
      end
      if not f then
        error("open file " .. log_path, f)
      end
      io.output(f)
      io.write(str .. "\n")
      io.close(f)
    else
      vim.notify(str .. "\n", vim.lsp.log_levels.DEBUG)
    end
  end
end

local rhs_options = {}

function rhs_options:new()
  local instance = {
    cmd = "",
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
  self.cmd = (":%s<CR>"):format(cmd_string)
  return self
end

function rhs_options:map_args(cmd_string)
  self.cmd = (":%s<Space>"):format(cmd_string)
  return self
end

function rhs_options:map_cu(cmd_string)
  self.cmd = (":<C-u>%s<CR>"):format(cmd_string)
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
    local mode, keymap = key:match("([^|]*)|?(.*)")
    if type(value) == "table" then
      local rhs = value.cmd
      local options = value.options
      vim.api.nvim_set_keymap(mode, keymap, rhs, options)
    end
  end
end

function util.load_plugin(name, modulename)
  assert(name ~= nil, "plugin should not empty")
  modulename = modulename or name
  local has, plugin = pcall(require, modulename)
  if has then
    return plugin
  end
  if packer_plugins ~= nil then
    -- packer installed
    local loader = require("packer").loader
    if not packer_plugins[name] or not packer_plugins[name].loaded then
      util.log("packer loader " .. name)
      vim.cmd("packadd " .. name) -- load with default
      if packer_plugins[name] ~= nil then
        loader(name)
      end
    end
  else
    util.log("packadd " .. name)
    vim.cmd("packadd " .. name) -- load with default
  end

  has, plugin = pcall(require, modulename)
  if not has then
    util.info("plugin " .. name .. "  not loaded ")
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
  local rel = vim.fn.isdirectory(name) == 0 and vim.fn.fnamemodify(name, ":h:.") or vim.fn.fnamemodify(name, ":.")
  if rel == "." then
    return "."
  else
    return "." .. util.sep() .. rel
  end
end

function util.all_pkgs()
  return "." .. util.sep() .. "..."
end

-- log and messages
function util.warn(msg)
  vim.notify("WARN: " .. msg, vim.lsp.log_levels.WARN)
end

function util.error(msg)
  vim.notify("ERR: " .. msg, vim.lsp.log_levels.ERROR)
end

function util.info(msg)
  vim.notify("INF: " .. msg, vim.lsp.log_levels.INFO)
end

function util.rel_path()
  local fpath = vim.fn.expand("%:p:h")

  local workfolders = vim.lsp.buf.list_workspace_folders()

  if workfolders ~= nil and next(workfolders) then
    fpath = "." .. fpath:sub(#workfolders[1] + 1)
  end
  return "." .. util.sep() .. vim.fn.fnamemodify(vim.fn.expand("%:p"), ":~:.")
end

function util.rtrim(s)
  local n = #s
  while n > 0 and s:find("^%s", n) do
    n = n - 1
  end
  return s:sub(1, n)
end

function util.ltrim(s)
  return (s:gsub("^%s*", ""))
end

function util.file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

function util.work_path()
  local fpath = vim.fn.expand("%:p:h")
  local workfolders = vim.lsp.buf.list_workspace_folders()
  if #workfolders == 1 then
    return workfolders[1]
  end

  for _, value in pairs(workfolders) do
    local mod = value .. util.sep() .. "go.mod"
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
  return next(t) == nil
end

local open = io.open

function util.read_file(path)
  local file = open(path, "rb") -- r read mode and b binary mode
  if not file then
    return nil
  end
  local content = file:read("*a") -- *a or *all reads the whole file
  file:close()
  return content
end

function util.restart(cmd_args)
  local lsp = require("lspconfig")
  local configs = require("lspconfig.configs")
  for _, client in ipairs(lsp.util.get_clients_from_cmd_args(cmd_args)) do
    if client.name == "gopls" then
      util.log("client to stop: " .. client.name)
      client.stop()
      vim.defer_fn(function()
        configs[client.name].launch()
        util.log("client to launch: " .. client.name)
      end, 500)
    end
  end
end

util.deletedir = function(dir)
  local lfs = require("lfs")
  for file in lfs.dir(dir) do
    local file_path = dir .. "/" .. file
    if file ~= "." and file ~= ".." then
      if lfs.attributes(file_path, "mode") == "file" then
        os.remove(file_path)
        print("remove file", file_path)
      elseif lfs.attributes(file_path, "mode") == "directory" then
        print("dir", file_path)
        util.deletedir(file_path)
      end
    end
  end
  lfs.rmdir(dir)
  util.log("remove dir", dir)
end

function util.file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

-- get all lines from a file, returns an empty
-- list/table if the file does not exist
function util.lines_from(file)
  if not util.file_exists(file) then return {} end
  local lines = {}
  for line in io.lines(file) do
    lines[#lines + 1] = line
  end
  return lines
end

function util.set_env(key, val)
end

function util.list_directory()
  local fn = vim.fn
  local dirs = fn.map(fn.glob(fn.fnameescape('./')..'/{,.}*/', 1, 1), 'fnamemodify(v:val, ":h:t")')
end

function util.set_nulls()
  if _GO_NVIM_CFG.null_ls_document_formatting_disable then
    local query = {}
    if type( _GO_NVIM_CFG.null_ls_document_formatting_disable) ~= 'boolean'
    then
      query = _GO_NVIM_CFG.null_ls_document_formatting_disable
    end
    local ok, nulls = pcall(require, "null-ls")
    if ok then
      nulls.disable(query)
    end
  end
end
return util
