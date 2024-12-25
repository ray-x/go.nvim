-- local get_project_root = require("project_nvim.project").get_project_root
local save_path = vim.fn.expand("$HOME/.go_build.json")
local popup = require("plenary.popup")

local buildtargets = {}
local cache = {}
local current_buildtarget = {}
local menu = 'menu'
local items = 'items'


function buildtargets.get_current_buildtarget()
  local project_root = get_project_root()
  local current_target = current_buildtarget[project_root]
  if current_target then
    if #cache[project_root][menu][items] > 1 then
      return current_target
    end
  end
  return nil
end

-- local menu_* vars are used to keep manage menu
local menu_visible_for_proj
local menu_winnr
local menu_coroutines = {}
local show_menu = function(opts, projs, co)
  local project_root = get_project_root()
  -- TODO test this
  if menu_visible_for_proj then
    -- menu is visible for current project
    if menu_visible_for_proj == project_root then
      table.insert(menu_coroutines, co)
      return
    end
    -- user request menu for different project
    -- close prevoius menu
    vim.api.nvim_win_close(menu_winnr, true)
  end
  table.insert(menu_coroutines, co)
  menu_visible_for_proj = project_root

  -- capture bufnr of current buffer for scan_project()
  local bufnr_called_from = vim.api.nvim_get_current_buf()

  local user_selection

  local height = opts.height
  local width = opts.width
  local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
  menu_winnr = popup.create(opts.items, {
    title = {
      { pos = "N", text = "Select Build Target", },
      { pos = "S", text = "Press 'r' to Refresh" } },
    -- highlight = "Cursor",
    line = math.floor(((vim.o.lines - height) / 5.0) - 1),
    col = math.floor((vim.o.columns - width) / 2),
    minwidth = 30,
    minheight = 13,
    borderchars = borderchars,
    callback = function(_, sel)
      user_selection = projs[sel][2]
      -- local project_root = get_project_root()
      update_buildtarget_map(project_root, sel)
      require('lualine').refresh()
    end
  })

  vim.api.nvim_win_set_option(menu_winnr, 'cursorline', true)
  local bufnr = vim.api.nvim_win_get_buf(menu_winnr)

  -- close menu
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", ":q<CR>", { silent = false })

  -- refresh menu
  vim.keymap.set("n", "r", function()
    -- local project_root = get_project_root()
    buildtargets.scan_project(project_root, bufnr_called_from)
    vim.cmd("set modifiable")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, opts.items)
    vim.cmd("set nomodifiable")
  end, { buffer = bufnr, silent = true })

  -- disable insert mode
  vim.cmd("set nomodifiable")
  -- disable the cursor; https://github.com/goolord/alpha-nvim/discussions/75
  local hl = vim.api.nvim_get_hl_by_name('Cursor', true)
  hl.blend = 100
  vim.api.nvim_set_hl(0, 'Cursor', hl)
  vim.opt.guicursor:append('a:Cursor/lCursor')

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(menu_winnr),
    callback = function()
      for _, cr in pairs(menu_coroutines) do
        coroutine.resume(cr, user_selection)
      end
      menu_coroutines = {}
      menu_visible_for_proj = nil
      -- menu_winr = nil
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = bufnr,
    callback = function()
      vim.cmd("set nomodifiable")
      hl.blend = 100
      vim.api.nvim_set_hl(0, 'Cursor', hl)
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      vim.cmd("set modifiable")
      hl.blend = 0
      vim.api.nvim_set_hl(0, 'Cursor', hl)
    end,
  })
end

function buildtargets.get_current_buildtarget_location()
  local project_root = get_project_root()
  local current_target = current_buildtarget[project_root]
  if current_target then
    local buildtarget_location = cache[project_root][current_target][2]
    return buildtarget_location
  end
  return nil
end

function buildtargets.select_buildtarget(co)
  -- TODO check being called from *.go file
  local project_root = get_project_root()
  -- project_root hasn't been scanned yet
  if not cache[project_root] then
    buildtargets.scan_project(project_root)
  end
  show_menu(cache[project_root][menu], cache[project_root], co)
end

function update_buildtarget_map(project_root, selection)
  current_buildtarget[project_root] = selection
  local selection_idx = cache[project_root][selection][1]
  if selection_idx == 1 then
    return
  end

  local selection_backup = cache[project_root][selection]
  cache[project_root][selection] = nil
  selection_backup[1] = 1
  cache[project_root][menu] = nil

  local lines = {}
  local width = #selection
  local height = 1

  for target, target_details in pairs(cache[project_root]) do
    local target_idx = target_details[1]
    if target_idx < selection_idx or target_idx == 2 then
      target_idx = target_idx + 1
      target_details[1] = target_idx
    end
    lines[target_idx] = target
    height = height + 1
    if #target > width then
      width = #target
    end
  end
  cache[project_root][selection] = selection_backup
  lines[1] = selection

  cache[project_root][menu] = { items = lines, width = width, height = height }
end

function buildtargets.scan_project(project_root, bufnr)
  bufnr = bufnr or 0
  local ms = require('vim.lsp.protocol').Methods
  local method = ms.workspace_symbol

  local result = vim.lsp.buf_request_sync(bufnr, method, { query = "main" })

  local lines = {}
  local width = 0
  local height = 0
  local targets = {}
  if result then
    for _, ress in pairs(result) do
      for _, resss in pairs(ress) do
        for _, res in pairs(resss) do
          if res.name == "main" then
            -- filter functions only (vlaue 12)
            if res.kind == 12 then
              local filelocation = vim.uri_to_fname(res.location.uri)

              if not vim.startswith(filelocation, project_root) then
                goto continue
              end

              -- TODO check if filelocation already opened
              -- open file
              vim.api.nvim_command('badd ' .. filelocation)

              local bufnr = vim.fn.bufnr(filelocation)

              local parser = vim.treesitter.get_parser(bufnr, "go")
              local tree = parser:parse()[1]

              -- search for file with 'package main' and 'func main()'
              local query = vim.treesitter.query.parse(
                "go",
                [[
                  (package_clause
                    (package_identifier) @main.package)
                  (function_declaration
                    name: (identifier) @main.function
                    parameters: (parameter_list) @main.function.parameters
                    !result
                  (#eq? @main.package "main")
                  (#eq? @main.function "main"))
                  (#eq? @main.function.parameters "()")
                ]])

              local ts_query_match = 0
              for _, _, _, _ in query:iter_captures(tree:root(), bufnr, nil, nil) do
                ts_query_match = ts_query_match + 1
              end

              if ts_query_match == 3 then
                local projectname = get_buildtarget_name(filelocation)
                height = height + 1
                targets[projectname] = { height, filelocation }
                if #projectname > width then
                  width = #projectname
                end
                lines[height] = projectname
              end
            end
          end
          ::continue::
        end
      end
    end
  end
  if height > 0 then
    targets[menu] = { items = lines, width = width, height = height }
    if not cache[project_root] then
      cache[project_root] = targets
    else -- refresh
      refresh_project_buildtargerts(cache[project_root], target)
      -- for buildtarget, target_details in cache[project_root] do
      -- end
    end
  else
    -- TODO error message unable to find main package with main function
  end
end

local refresh_project_buildtargerts = function(original, refresh)
  local original_idx = #original[menu][items]
  local refresh_idx = #refresh[menu][items]
  if original_idx == refresh_idx and
      vim.deep_equal(original[menu][items], refresh[menu][items]) then
    vim.notify(vim.inspect({ retur = "return 1" }))
    return
  end

  for buildtarget, _ in pairs(refresh) do
    -- new target found in refresh
    if not original[buildtarget] then
      original_idx = original_idx + 1
      refresh[buildtarget][1] = original_idx
      original[buildtarget] = refresh[buildtarget]
      original[menu][items][original_idx] = buildtarget
      original[menu]['height'] = original[menu]['height'] + 1
      if #buildtarget > original[menu]['width'] then
        original[menu]['width'] = #buildtarget
      end
    end
  end

  original_idx = #original[menu][items]
  if original_idx == refresh_idx then --  and
    -- vim.deep_equal(original[menu][items], refresh[menu][items]) then
    vim.notify(vim.inspect({ retur = "return 2" }))
    return
  end

  local removed_idxs = {}
  for buildtarget, target_details in pairs(original) do
    -- target found in original but not in refresh
    if not refresh[buildtarget] then
      local target_idx = target_details[1]
      table.insert(removed_idxs, target_idx)
      original[buildtarget] = nil
    end
  end

  -- TODO recalculate menu items, height, width
  if #removed_idxs > 0 then
    local lines = {}
    local width = 0
    local height = 0
    original[menu] = nil
    for buildtarget, target_details in pairs(original) do
      local target_idx = target_details[1]
      local count = 0
      for _, idx in ipairs(removed_idxs) do
        if target_idx > idx then
          count = count + 1
        end
      end
      target_idx = target_idx - count
      target_details[1] = target_idx
      lines[target_idx] = buildtarget
      height = height + 1
      if #buildtarget > width then
        width = #buildtarget
      end
    end
    original[menu] = { items = lines, width = width, height = height }
  end
end

function get_buildtarget_name(location)
  local filename = location:match("^.*/(.*)%.go$")
  if filename ~= "main" then
    return filename
  end

  local name = location:match("^.*/(.*)/.*$")
  return name
end

function writebuildsfile(data)
  local data = vim.json.encode(data)
  if cache ~= data then
    require("bookmarks.util").write_file(save_path, data)
  end
end

function readbuildsfile()
  require("bookmarks.util").read_file(save_path, function(data)
    cache = vim.json.decode(data)
  end)
end

buildtargets._refresh_project_buildtargerts = refresh_project_buildtargerts

return buildtargets