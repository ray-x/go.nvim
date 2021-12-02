local util = {}

local os_name = vim.loop.os_uname().sysname
local is_windows = os_name == 'Windows' or os_name == 'Windows_NT'
-- Check whether current buffer contains main function
local function has_main()
  local output = vim.api.nvim_exec("grep func\\ main\\(\\) %", true)
  local matchCount = vim.split(output, "\n")

  return #matchCount > 3
end

function util.sep()
  if is_windows then
    return '\\'
  end
  return '/'
end

local function smartrun()
  if has_main() then
    -- Found main function in current buffer
    vim.cmd("lcd %:p:h | :set makeprg=go\\ run\\ . | :make | :lcd -")
  else
    vim.cmd("setl makeprg=go\\ run\\ . | :make")
  end
end

local function smartbuild()
  if has_main() then
    -- Found main function in current buffer
    vim.cmd("lcd %:p:h | :set makeprg=go\\ build\\ . | :make | :lcd -")
  else
    vim.cmd("setl makeprg=go\\ build\\ . | :make")
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
  options = util.merge({noremap = true, silent = false, expr = false, nowait = false}, options or {})
  local buffer = options.buffer
  options.buffer = nil

  if type(modes) ~= "table" then
    modes = {modes}
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
  if data[#data] == '' then
    table.remove(data, #data)
  end
  if #data < 1 then
    return nil
  end
  return data
end

util.log = function(...)
  if not _GO_NVIM_CFG.verbose then
    return
  end
  local arg = {...}
  local log_default = string.format("%s%s%s.log", vim.api.nvim_call_function("stdpath", {"data"}), util.sep(), "gonvim")

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
        print("failed to open log", log_path, err)
        return
      end
      if not f then
        error('open file ' .. log_path, f)
      end
      io.output(f)
      io.write(str .. "\n")
      io.close(f)
    else
      print(str .. "\n")
    end
  end
end

local rhs_options = {}

function rhs_options:new()
  local instance = {
    cmd = '',
    options = {noremap = false, silent = false, expr = false, nowait = false}
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
    if type(value) == 'table' then
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
    local loader = require"packer".loader
    if not packer_plugins[name] or not packer_plugins[name].loaded then
      loader(name)
    end
  else
    vim.cmd("packadd " .. name) -- load with default
  end

  has, plugin = pcall(require, modulename)
  if not has then
    util.warn("plugin failed to load " .. name)
  end
  return plugin
end

function util.check_capabilities(feature, client_id)
  local clients = vim.lsp.buf_get_clients(client_id or 0)

  local supported_client = false
  for _, client in pairs(clients) do
    util.log(client.resolved_capabilities)
    supported_client = client.resolved_capabilities[feature]
    if supported_client then
      goto continue
    end
  end

  ::continue::
  if supported_client then
    return true
  else
    if #clients == 0 then
      util.log("LSP: no client attached")
    else
      util.log("LSP: server does not support " .. feature)
    end
    return false
  end
end

function util.relative_to_cwd(name)
  local rel = vim.fn.isdirectory(name) == 0 and vim.fn.fnamemodify(name, ':h:.') or vim.fn.fnamemodify(name, ':.')
  if rel == '.' then
    return '.'
  else
    return '.' .. util.sep() .. rel
  end
end

function util.all_pkgs()
  return '.' .. util.sep() .. '...'
end

-- log and messages
function util.warn(msg)
  vim.api.nvim_echo({{"WRN: " .. msg, "WarningMsg"}}, true, {})
end

function util.error(msg)
  vim.api.nvim_echo({{"ERR: " .. msg, "ErrorMsg"}}, true, {})
end

function util.info(msg)
  vim.api.nvim_echo({{"Info: " .. msg}}, true, {})
end

function util.rel_path()
  local fpath = vim.fn.expand('%:p:h')
  local workfolder = vim.lsp.buf.list_workspace_folders()[1]
  if workfolder ~= nil then
    fpath = "." .. fpath:sub(#workfolder + 1)
  end
  return fpath
end

function util.rtrim(s)
  local n = #s
  while n > 0 and s:find("^%s", n) do
    n = n - 1
  end
  return s:sub(1, n)
end

return util
