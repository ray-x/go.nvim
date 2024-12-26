local get_project_root = require("project_nvim.project").get_project_root
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
local menu_visible_for_proj = nil
local menu_winnr = nil
local menu_coroutines = {}
local show_menu = function(co)
  local project_root = get_project_root()
  -- if satement below needed for race condition
  if menu_visible_for_proj then
    -- menu is visible for current project
    if menu_visible_for_proj == project_root then
      vim.api.nvim_set_current_win(menu_winnr)
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

  local menu_opts = cache[project_root][menu]
  local height = menu_opts.height
  local width = menu_opts.width
  local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
  menu_winnr = popup.create(menu_opts.items, {
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
      user_selection = cache[project_root][sel][2]
      update_buildtarget_map(project_root, sel)
      require('lualine').refresh()
    end
  })

  vim.api.nvim_win_set_option(menu_winnr, 'cursorline', true)
  local bufnr = vim.api.nvim_win_get_buf(menu_winnr)

  -- close menu
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", ":q<CR>", { silent = false })

  local err
  -- refresh menu
  vim.keymap.set("n", "r", function()
    vim.cmd("set modifiable")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    vim.cmd('redraw')
    err = buildtargets.scan_project(project_root, bufnr_called_from)
    if err then
      vim.api.nvim_win_close(menu_winnr, true)
      vim.notify("error refreshing build target: " .. err, vim.log.levels.ERROR)
      return
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, menu_opts.items)
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
      for _, cr in ipairs(menu_coroutines) do
        coroutine.resume(cr, user_selection, err)
      end
      menu_coroutines = {}
      menu_visible_for_proj = nil
      -- menu_winnr = nil
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
      vim.schedule(function()
        if menu_visible_for_proj then
          vim.api.nvim_win_close(menu_winnr, true)
        end
      end)
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
  if not cache[project_root] then
    -- project_root hasn't been scanned yet
    local err = buildtargets.scan_project(project_root)
    if err then
      vim.notify("error finding build target: " .. err, vim.log.levels.ERROR)
      return nil, err
    end
  end

  local targets = cache[project_root][menu][items]
  -- if only one build target, return build target location
  if #targets == 1 then
    local target = targets[1]
    current_buildtarget[project_root] = target
    local target_location = cache[project_root][target][2]
    return target_location, nil
  end

  -- if multiple build targets, then launch menu and ask user to select
  show_menu(co)
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

local match_location = function(original_dir, refresh_dir)
  local original_loc = original_dir:match('^(.*)/.*$')
  local refresh_loc = refresh_dir:match('^(.*)/.*$')
  if original_loc == refresh_loc then
    return true
  end
  return false
end

local refresh_project_buildtargerts = function(original, refresh)
  local idxs = {}
  original[menu] = nil
  refresh[menu] = nil
  for _, ref_target_details in pairs(refresh) do
    local ref_dir = ref_target_details[2]
    ref_target_details[1] = nil
    for orig_buildtarget, orig_target_details in pairs(original) do
      local orig_dir = orig_target_details[2]
      if match_location(orig_dir, ref_dir) then
        ref_target_details[1] = orig_target_details[1]
        table.insert(idxs, ref_target_details[1])
        original[orig_buildtarget] = nil
        break
      end
    end
  end

  table.sort(idxs)

  local idx_increase = {}
  local difference = 1 - idxs[1]
  if difference > 1 then
    idx_increase[1] = difference - 1
  end
  for i = 2, (#idxs) do
    difference = idxs[i] - idxs[i - 1]
    if difference > 1 then
      idx_increase[i] = difference - 1
    end
  end

  local height = #idxs
  local lines = {}
  local width = 0
  for buildtarget, ref_target_details in pairs(refresh) do
    local target_idx
    if not ref_target_details[1] then
      height = height + 1
      target_idx = height
      ref_target_details[1] = target_idx
    else
      target_idx = ref_target_details[1]
      local increase_target_idx_by = idx_increase[target_idx]
      if increase_target_idx_by then
        target_idx = target_idx + increase_target_idx_by
        ref_target_details[1] = target_idx
      end
    end
    lines[target_idx] = buildtarget
    if #buildtarget > width then
      width = #buildtarget
    end
  end
  refresh[menu] = { items = lines, width = width, height = height }
end

function buildtargets.scan_project(project_root, bufnr)
  bufnr = bufnr or 0
  local ms = require('vim.lsp.protocol').Methods
  local method = ms.workspace_symbol

  local result = vim.lsp.buf_request_sync(bufnr, method, { query = "main" })
  if not result then
    return "nil result from Language Server"
  end

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
    if cache[project_root] then
      refresh_project_buildtargerts(cache[project_root], targets)
    end
    cache[project_root] = targets
  else
    return "no build targets found"
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
