local M = {}
function M.list(args)
  local cmd = {'go', 'list', '-json'}
  vim.list_extend(cmd, args or {'.'})

  local out = vim.fn.systemlist(table.concat(cmd, ' '))
  if vim.v.shell_error ~= 0 then
    require('go.utils').warn('go list failed', vim.inspect(out))
    return false
  end
  for i, e in ipairs(out) do
    if e == '}' and out[i + 1] == '{' then
      out[i] = '},'
    end
  end
  return true, vim.json.decode('[' .. table.concat(out, '') .. ']')
end

function M.list_pkgs(path)
  local cmd = {'go', 'list'}

  vim.list_extend(cmd, args or {'.'})
  out = vim.fn.systemlist(table.concat(cmd, ' '))
  if vim.v.shell_error ~= 0 then
    require('go.utils').warn('go list failed', vim.inspect(out))
    return false
  end
  return table.concat(out, ',')
end
return M
