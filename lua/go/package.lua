local golist = require'go.list'.list
local util = require 'go.utils'
local log = util.log
return {
  complete = function()
    local ok, l = golist(false, {util.all_pkgs()})
    if not ok then
      log('Failed to find all packages for current module/project.')
    end
    local curpkgmatch = false
    local curpkg = vim.fn.fnamemodify(vim.fn.expand('%'), ':h:.')
    local pkgs = {}
    for _, p in ipairs(l) do
      local d = vim.fn.fnamemodify(p.Dir, ':.')
      if curpkg ~= d then
        if d ~= vim.fn.getcwd() then
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
    return table.concat(pkgs, '\n')
  end
}
