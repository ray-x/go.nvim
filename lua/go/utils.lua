local util = {}
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
  local arg = {...}
  local log_path = _GO_NVIM_CFG.log_path or "/tmp/gonvim.log"
  if _GO_NVIM_CFG.verbose == true then
    local str = "  "
    for i, v in ipairs(arg) do
      if type(v) == "table" then
        str = str .. " |" .. tostring(i) .. ": " .. vim.inspect(v) .. "\n"
      else
        str = str .. " |" .. tostring(i) .. ": " .. tostring(v)
      end
    end
    if #str > 2 then
      if log_path ~= nil and #log_path > 3 then
        local f = io.open(log_path, "a+")
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
  assert(has, "plugin failed to load " .. name)
  return plugin
end

return util
