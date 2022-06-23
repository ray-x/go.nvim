local golist = require("go.list").list
local util = require("go.utils")
local log = util.log
local vfn = vim.fn
local api = vim.api
local complete = function()
  local ok, l = golist(false, { util.all_pkgs() })
  if not ok then
    log("Failed to find all packages for current module/project.")
  end
  local curpkgmatch = false
  local curpkg = vfn.fnamemodify(vfn.expand("%"), ":h:.")
  local pkgs = {}
  for _, p in ipairs(l) do
    local d = vfn.fnamemodify(p.Dir, ":.")
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
  table.insert(pkgs, ".")
  if curpkgmatch then
    table.insert(pkgs, util.relative_to_cwd(curpkg))
  end
  return table.concat(pkgs, "\n")
end

local all_pkgs = function()
  local ok, l = golist(false, { util.all_pkgs() })
  if not ok then
    log("Failed to find all packages for current module/project.")
  end
  return l
end

local pkg_from_path = function(arg)
  log(arg, path)
  return util.exec_in_path({ "go", "list" })
end

local show_float = function(result)
  local textview = util.load_plugin("guihua.lua", "guihua.textview")
  if not textview then
    util.log("Failed to load guihua.textview")

    vim.fn.setloclist({}, " ", {
      title = "go package outline",
      lines = result,
    })
    vim.cmd("lopen")
    return
  end
  local win = textview:new({
    relative = "cursor",
    syntax = "lua",
    rect = { height = math.min(40, #result), pos_x = 0, pos_y = 10 },
    data = result,
  })
  log("draw data", result)
  vim.api.nvim_buf_set_option(win.buf, "filetype", "go")
  return win:on_draw(result)
end

local show_panel = function(result, pkg)
  local fname = vim.fn.tempname() .. "._go" -- avoid lsp activation
  log("tmp:" .. fname)
  local uri = vim.uri_from_fname(fname)
  local bufnr = vim.uri_to_bufnr(uri)
  vim.fn.writefile(result, fname)
  vfn.bufload(bufnr)
  local defs = require("go.ts.utils").list_definitions_toc(bufnr)

  log("defs", defs)
  local panel = util.load_plugin("guihua.lua", "guihua.panel")
  pkg = pkg or 'pkg'
  pkg = vfn.split(pkg, '/')
  pkg = pkg[#pkg] or 'pkg'
  if panel then
    local p = panel:new({
      header = "    " .. pkg .. "   ",
      render = function(b)
        log("render for ", bufnr, b)
        return defs
      end,
    })
    p:open(true)
  else
    vim.fn.setloclist({}, " ", {
      title = "go package outline",
      lines = defs,
    })
    vim.cmd("lopen")
  end

  vim.api.nvim_buf_delete(bufnr, { unload = true })
  os.remove(fname)
end
-- get package info

local outline = function(...)
  local arg = select(1, ...)
  local path = './...'
  if arg == '-p' then
    path = select(2, ...)
  end
  local listcmd = { "go", "list", path }
  local pkg = util.exec_in_path(listcmd)
  if vfn.empty(pkg) == 1 then
    util.log("No package found in current directory.")
    return nil
  end
  local setup = { "go", "doc", "-all", "-u", "-cmd", pkg[1] }
  local result = {}
  vfn.jobstart(setup, {
    on_stdout = function(_, data, _)
      data = util.handle_job_data(data)
      if not data then
        return
      end
      local types = { "CONSTANTS", "FUNCTIONS", "TYPES", "VARIABLES" }
      for i, val in ipairs(data) do
        -- first strip the filename
        if vim.tbl_contains(types, val) then
          val = "//" .. val
        end

        local sp = string.match(val, "^(%s*)")
        if sp and #sp == 4 then
          val = "//" .. val
        end
        local f = string.match(val, "^func ")
        if f then
          -- incase the func def is mulilines
          local next_line = data[i + 1]
          if next_line then
            local next_sp = string.match(next_line, "^(%s*)") -- one tab in front
            if next_sp and #next_sp == 1 then -- tab size 1
              next_line = next_line .. "{}"
              data[i+1] = next_line
            else
              val = val .. "{}"
            end
          else
            val = val .. "{}"
          end
        end
        -- todo search in current dir with lsp workspace symbols
        log(val)
        table.insert(result, val)
      end
    end,
    on_exit = function(_, data, _)
      if data ~= 0 then
        vim.notify("no packege info data", vim.lsp.log_levels.WARN)
        return
      end

      if arg == "-f" then
        return show_float(result)
      end

      show_panel(result, pkg[1])
    end,
  })
end

return {
  complete = complete,
  all_pkgs = all_pkgs,
  pkg_from_path = pkg_from_path,
  outline = outline,
}
