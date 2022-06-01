local golist = require'go.list'.list
local util = require 'go.utils'
local log = util.log
local vfn = vim.fn
return {
  complete = function()
    local ok, l = golist(false, {util.all_pkgs()})
    if not ok then
      log('Failed to find all packages for current module/project.')
    end
    local curpkgmatch = false
    local curpkg = vfn.fnamemodify(vfn.expand('%'), ':h:.')
    local pkgs = {}
    for _, p in ipairs(l) do
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
    return table.concat(pkgs, '\n')
  end,
  all_pkgs = function()
    local ok, l = golist(false, {util.all_pkgs()})
    if not ok then
      log('Failed to find all packages for current module/project.')
    end
    return l
  end

}
