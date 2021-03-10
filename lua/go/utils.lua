local util = {}
util.check_same = function(tbl1, tbl2)
  if #tbl1 ~= #tbl2 then
    return
  end
  for k, v in ipairs(tbl1) do
    if v ~= tbl2[k] then
      return true
    end
  end
  return false
end

util.copy_array = function(from, to)
  for i = 1, #from do
   to[i] = from[i]
  end
end

util.deepcopy = function (orig)
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

util.log = function(...)
  if vim.g.go_nvim_verbose then
    print(...)
  end
end

return util
