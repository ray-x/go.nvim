local get_project_root = require("project_nvim.project").get_project_root
local save_path = vim.fn.expand("$HOME/.go_build.json")
local popup = require("plenary.popup")

local M = {}
local cache = {}
local current_buildtarget = {}
local collisions = {}
local menu = 'menu'
local items = 'items'

function M.get_current_buildtarget()
  local project_root = get_project_root()
  local current_target = current_buildtarget[project_root]
  if current_target then
    if #cache[project_root][menu][items] > 1 then
      return current_target
    end
  end
  return nil
end

-- local flash_menu = function(project_root)
function flash_menu(project_root)
  vim.cmd("set modifiable")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
  vim.cmd('redraw')
  vim.wait(20)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, cache[project_root][menu][items])
  vim.cmd("set nomodifiable")
end

-- local menu_* vars are used to keep manage menu
local menu_visible_for_proj = nil
local menu_winnr = nil
local menu_coroutines = {}
-- local show_menu = function(co)
function show_menu(co)
  local project_root = get_project_root()

  -- if satement below needed for race condition
  if menu_visible_for_proj then
    -- menu is visible for current project
    if menu_visible_for_proj == project_root then
      table.insert(menu_coroutines, co)
      vim.api.nvim_set_current_win(menu_winnr)
      flash_menu(project_root)
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
  local menu_height = menu_opts.height
  local menu_width = menu_opts.width
  menu_winnr = popup.create(menu_opts.items, {
    title = {
      { pos = "N", text = "Select Build Target", },
      { pos = "S", text = "Press 'r' to Refresh" } },
    cursorline = true,
    line = math.floor(((vim.o.lines - menu_height) / 5.0) - 1),
    col = math.floor((vim.o.columns - menu_width) / 2),
    minwidth = 30,
    minheight = 13,
    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
    -- border = true,
    callback = function(_, sel)
      local selection = vim.api.nvim_get_current_line()
      user_selection = cache[project_root][selection][2]
      update_buildtarget_map(project_root, selection)
      require('lualine').refresh()
    end
  })

  local bufnr = vim.api.nvim_win_get_buf(menu_winnr)

  -- disable insert mode
  vim.cmd("set nomodifiable")
  -- disable the cursor; https://github.com/goolord/alpha-nvim/discussions/75
  local hl = vim.api.nvim_get_hl_by_name('Cursor', true)
  hl.blend = 100
  vim.api.nvim_set_hl(0, 'Cursor', hl)
  vim.opt.guicursor:append('a:Cursor/lCursor')

  -- set Ecs to close menu
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", ":q<CR>", { silent = false })

  local err

  -- refresh menu
  vim.keymap.set("n", "r", function()
    vim.cmd("set modifiable")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Refreshing..." })
    vim.cmd('redraw')
    err = M.scan_project(project_root, bufnr_called_from)
    if err then
      vim.api.nvim_win_close(menu_winnr, true)
      vim.notify("error refreshing build targets: " .. err, vim.log.levels.ERROR)
      return
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, cache[project_root][menu][items])
    vim.cmd("set nomodifiable")
  end, { buffer = bufnr, silent = true })

  -- leave menu window
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      vim.cmd("set modifiable")
      hl.blend = 0
      vim.api.nvim_set_hl(0, 'Cursor', hl)
      -- if you leave the menu buffer, then close menu window
      vim.schedule(function()
        if menu_visible_for_proj then
          vim.api.nvim_win_close(menu_winnr, true)
        end
      end)
    end,
  })

  -- close menu window
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(menu_winnr),
    callback = function()
      for _, cr in ipairs(menu_coroutines) do
        coroutine.resume(cr, user_selection, err)
      end
      menu_coroutines = {}
      menu_visible_for_proj = nil
    end,
  })
end

function M.get_current_buildtarget_location()
  local project_root = get_project_root()
  local current_target = current_buildtarget[project_root]
  if current_target then
    local buildtarget_location = cache[project_root][current_target][2]
    return buildtarget_location
  end
  return nil
end

function M.select_buildtarget(co)
  -- TODO check being called from *.go file
  local project_root = get_project_root()
  if not cache[project_root] then
    -- project_root hasn't been scanned yet
    local err = M.scan_project(project_root)
    if err then
      vim.notify("error finding build targets: " .. err, vim.log.levels.ERROR)
      return nil, err
    end
  end

  local targets = cache[project_root][menu][items]
  -- if only one build target, send build target location
  if #targets == 1 then
    local target_name = targets[1]
    current_buildtarget[project_root] = target_name
    local target_location = cache[project_root][target_name][2]
    if co then
      vim.schedule(function()
        coroutine.resume(co, target_location, nil)
      end)
    else
      vim.notify("only one build target available: " .. target_name, vim.log.levels.INFO)
    end
    return
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

  local menu_items = {}
  local menu_width = #selection
  local menu_height = 1

  for target, target_details in pairs(cache[project_root]) do
    local target_idx = target_details[1]
    if target_idx < selection_idx or target_idx == 2 then
      target_idx = target_idx + 1
      target_details[1] = target_idx
    end
    menu_items[target_idx] = target
    menu_height = menu_height + 1
    if #target > menu_width then
      menu_width = #target
    end
  end
  cache[project_root][selection] = selection_backup
  menu_items[1] = selection

  cache[project_root][menu] = { items = menu_items, width = menu_width, height = menu_height }
end

function match_location(original_dir, refresh_dir)
  local original_loc = original_dir:match('^(.*)/.*$')
  local refresh_loc = refresh_dir:match('^(.*)/.*$')
  if original_loc == refresh_loc then
    return true
  end
  return false
end

local refresh_project_buildtargerts = function(original, refresh, project_root)
  local new_current_buildtarget
  local previous_current_target_location
  local current_target = current_buildtarget[project_root]
  if current_target then
    previous_current_target_location = cache[project_root][current_target][2]:match('^(.*)/.*$')
  end

  local idxs = {}
  local backup_menu_items = original[menu][items]
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

  local idx_target_change = {}
  for i = 1, (#idxs) do
    local idx = idxs[i]
    idx_target_change[idx] = i
  end

  local menu_height = #idxs
  local menu_items = {}
  local menu_width = 0
  for buildtarget, ref_target_details in pairs(refresh) do
    local new_target_idx
    local ref_target_idx = ref_target_details[1]
    if not ref_target_idx then
      menu_height = menu_height + 1
      new_target_idx = menu_height
    else
      new_target_idx = idx_target_change[ref_target_idx]
      if current_target then
        -- TODO UT this
        local target_location = ref_target_details[2]:match('^(.*)/.*$')
        if previous_current_target_location == target_location then
          new_current_buildtarget = buildtarget
          current_target = nil
        end
      end
    end
    ref_target_details[1] = new_target_idx
    menu_items[new_target_idx] = buildtarget
    if #buildtarget > menu_width then
      menu_width = #buildtarget
    end
  end

  current_buildtarget[project_root] = new_current_buildtarget
  refresh[menu] = { items = menu_items, width = menu_width, height = menu_height }

  -- TODO think about this...
  if vim.deep_equal(backup_menu_items, refresh[menu][items]) then
    writebuildsfile()
  end
end

function get_target_resolution_string(target_location, project_location)
  local new_target_resolution_string = string.sub(target_location, #project_location + 1, #target_location)
  local truncate = 3 -- '.go postfix'
  local ends_in_main = string.sub(new_target_resolution_string, #new_target_resolution_string - 7,
    #new_target_resolution_string)
  if ends_in_main == '/main.go' then
    truncate = truncate + 5 -- '/main'
  end
  new_target_resolution_string = string.sub(new_target_resolution_string, 1, #new_target_resolution_string - truncate)
  return new_target_resolution_string
end

local expand_target_name = function(target_resolution_details)
  local regex_start                         = '^.*/('
  local regex_end                           = ')$'
  target_resolution_details.capture_pattern = target_resolution_details.capture_pattern .. '/.*'
  local regex                               = regex_start ..
      target_resolution_details.capture_pattern .. regex_end
  target_name                               = target_resolution_details.resolution_string:match(regex)
  target_resolution_details.target_name     = target_name
end

local resolve_collisions = function(target, target_details, project_root)
  local collisions                    = collisions[project_root]
  local project_location              = collisions.project_location
  local new_target_resolution_string  = get_target_resolution_string(target_details[2], project_location)

  local new_target_resolution_details = {
    target_name = target,
    target_details = target_details,
    resolution_string =
        new_target_resolution_string,
    capture_pattern = '.*'
  }
  local new_target_name               = new_target_resolution_details.target_name

  for _, target_resolution_details in ipairs(collisions[target]) do
    local target_name = target_resolution_details.target_name
    local resolved = false

    while resolved == false do
      local extend_target_name = false
      local extend_new_target_name = false

      if #target_name == #new_target_name then
        if target_name == new_target_name then
          -- vim.notify(vim.inspect({ "1", target_resolution_details }))
          extend_target_name = true
          extend_new_target_name = true
        else
          resolved = true
        end
      elseif #target_name > #new_target_name then
        -- vim.notify(vim.inspect({ "2", target_resolution_details }))
        if vim.endswith(target_name, new_target_name) then
          extend_new_target_name = true
        else
          resolved = true
        end
      else
        -- vim.notify(vim.inspect({ "3" }))
        if vim.endswith(new_target_name, target_name) then
          extend_target_name = true
        else
          resolved = true
        end
      end

      if extend_target_name then
        expand_target_name(target_resolution_details)
        target_name = target_resolution_details.target_name
      end
      if extend_new_target_name then
        expand_target_name(new_target_resolution_details)
        new_target_name = new_target_resolution_details.target_name
      end
    end
  end
end

local add_collisions = function(project_root)
end

local add_target_to_cache = function(target, target_details, project_root)
  if not cache[project_root][target] then
    cache[project_root][target] = target_details
    return
  end

  if not collisions[project_root] then
    collisions[project_root] = {}
    local project_location = project_root:match('^(.*)/.+/*$')
    collisions[project_root]['project_location'] = project_location
    collisions[project_root][target] = {}
    local target_location = cache[project_root][target][2]
    local target_details = cache[project_root][target]
    local resolution_string = get_target_resolution_string(target_location, project_location)
    table.insert(collisions[project_root][target],
      {
        target_name = target,
        target_details = target_details,
        resolution_string = resolution_string,
        capture_pattern = '.*'
      })
  end

  resolve_collisions(target, target_details, project_root)
end

function M.scan_project(project_root, bufnr)
  bufnr = bufnr or 0
  local ms = require('vim.lsp.protocol').Methods
  local method = ms.workspace_symbol

  local result = vim.lsp.buf_request_sync(bufnr, method, { query = "main" }, 5000)
  if not result then
    return "nil result from Language Server"
  end

  local menu_items = {}
  local menu_width = 0
  local menu_height = 0
  local targets = {}
  if result then
    for _, resss in pairs(result) do
      for _, ress in pairs(resss) do
        for _, res in pairs(ress) do
          if res.name == "main" then
            -- filter functions only (vlaue 12)
            if res.kind == 12 then
              local filelocation = vim.uri_to_fname(res.location.uri)

              if not vim.startswith(filelocation, project_root) then
                goto continue
              end

              local close_buffer = false
              local bufnr = vim.fn.bufnr(filelocation)
              if bufnr == -1 then
                vim.api.nvim_command('badd ' .. filelocation)
                bufnr = vim.fn.bufnr(filelocation)
                close_buffer = true
              end

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

              if close_buffer then
                vim.api.nvim_buf_delete(bufnr, { force = true })
              end

              if ts_query_match == 3 then
                menu_height = menu_height + 1
                local target_name = get_buildtarget_name(filelocation)
                targets[target_name] = { menu_height, filelocation }
                if #target_name > menu_width then
                  menu_width = #target_name
                end
                menu_items[menu_height] = target_name
              end
            end
          end
          ::continue::
        end
      end
    end
  end
  if menu_height > 0 then
    targets[menu] = { items = menu_items, width = menu_width, height = menu_height }
    if cache[project_root] then
      -- this is a refresh
      refresh_project_buildtargerts(cache[project_root], targets, project_root)
    end
    -- vim.notify(vim.inspect({ "targets", targets = targets }))
    cache[project_root] = targets
  else
    cache[project_root] = nil
    current_buildtarget[project_root] = nil
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

local uv = vim.loop
local write_file = function(path, content)
  uv.fs_open(path, "w", 438, function(open_err, fd)
    assert(not open_err, open_err)
    uv.fs_write(fd, content, -1, function(write_err)
      assert(not write_err, write_err)
      uv.fs_close(fd, function(close_err)
        assert(not close_err, close_err)
      end)
    end)
  end)
end

local read_file = function(path, callback)
  uv.fs_open(path, "r", 438, function(err, fd)
    assert(not err, err)
    uv.fs_fstat(fd, function(err, stat)
      assert(not err, err)
      uv.fs_read(fd, stat.size, 0, function(err, data)
        assert(not err, err)
        uv.fs_close(fd, function(err)
          assert(not err, err)
          callback(data)
        end)
      end)
    end)
  end)
end

function path_exists(file)
  return uv.fs_stat(file) and true or false
end

function readbuildsfile()
  local bufnr = vim.api.nvim_get_current_buf()
  if path_exists(save_path) then
    read_file(save_path, function(data)
      local data = vim.json.decode(data)
      cache, current_buildtarget = unpack(data)
      vim.notify(vim.inspect({ "reading", cache = cache, current_buildtarget = current_buildtarget }))
      vim.schedule(function()
        require('lualine').refresh()
      end)
    end)
  end
end

function writebuildsfile()
  local data = {
    cache, current_buildtarget
  }
  local data = vim.json.encode(data)
  write_file(save_path, data)
  vim.notify(vim.inspect({ "writing", cache = cache, current_buildtarget = current_buildtarget }))
end

M.writebuildsfile = writebuildsfile
M.readbuildsfile = readbuildsfile

M._set_cache = function(cahce_)
  cache = cahce_
end

M._refresh_project_buildtargerts = refresh_project_buildtargerts
M._add_target_to_cache = add_target_to_cache

return M
