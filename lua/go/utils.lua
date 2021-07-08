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
  local log_path = vim.g.go_nvim_log_path or "/tmp/gonvim.log"
  if vim.g.go_nvim_debug == true then
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
        io.output(f)
        io.write(str .. "\n")
        io.close(f)
      else
        print(str .. "\n")
      end
    end
  end
end

return util
