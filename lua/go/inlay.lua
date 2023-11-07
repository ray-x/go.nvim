--part of code was from rust-tools inlay_hints.lua
-- I was so jealous of rust-tools which provides inlay_hints until today gopls provides this feature
local M = {}
local vim = vim
local api = vim.api
local fn = vim.fn
local utils = require('go.utils')
local log = utils.log
-- local trace = utils.trace
trace = log
local config
local inlay_display = vim.fn.has('nvim-0.10') == 1 and _GO_NVIM_CFG.lsp_inlay_hints.style == 'inlay'
-- local inlay_display = true
-- whether the hints are enabled or not
local enabled = nil
-- Update inlay hints when opening a new buffer and when writing a buffer to a
-- file
-- opts is a string representation of the table of options
local should_update = {}
function M.setup()
  local events = { 'BufWritePost', 'BufEnter', 'InsertLeave', 'FocusGained', 'CursorHold' }
  config = _GO_NVIM_CFG.lsp_inlay_hints
  if not config or config.enable == false then -- diabled
    return
  end
  enabled = config.enable
  if config.only_current_line then
    local user_events = vim.split(config.only_current_line_autocmd, ',')
    events = vim.tbl_extend('keep', events, user_events)
  end

  local cmd_group = api.nvim_create_augroup('gopls_inlay', {})
  api.nvim_create_autocmd({ 'BufEnter', 'InsertLeave', 'FocusGained', 'CursorHold' }, {
    group = cmd_group,
    pattern = { '*.go', '*.mod' },
    callback = function()
      if not vim.wo.diff and enabled then
        require('go.inlay').set_inlay_hints()
      end
    end,
  })
  api.nvim_create_autocmd({ 'BufWritePost' }, {
    group = cmd_group,
    pattern = { '*.go', '*.mod' },
    callback = function()
      if not vim.wo.diff then
        local inlay = require('go.inlay')
        inlay.disable_inlay_hints(true)
        if enabled then
          inlay.set_inlay_hints()
        end
      end
    end,
  })

  api.nvim_create_user_command('GoToggleInlay', function(_)
    require('go.inlay').toggle_inlay_hints()
  end, { desc = 'toggle gopls inlay hints' })
  vim.defer_fn(function()
    require('go.inlay').set_inlay_hints()
  end, 1000)
end

local function get_params()
  local start_pos = api.nvim_buf_get_mark(0, '<')
  local end_pos = api.nvim_buf_get_mark(0, '>')
  local params =
    { range = { start = { character = 0, line = 0 }, ['end'] = { character = 0, line = 0 } } }
  local len = vim.api.nvim_buf_line_count(0)
  if end_pos[1] <= len then
    params = vim.lsp.util.make_given_range_params()
  end

  params['range']['start']['line'] = 0
  params['range']['end']['line'] = vim.api.nvim_buf_line_count(0) - 1
  trace(params)
  return params
end

local namespace = vim.api.nvim_create_namespace('experimental/inlayHints')

-- parses the result into a easily parsable format see comments EOF
local function parseHints(result)
  trace(result)
  local map = {}
  local only_current_line = config.only_current_line

  if type(result) ~= 'table' then
    return {}
  end
  for _, value in pairs(result) do
    local range = value.position
    -- range.character = range.character
    local line = value.position.line
    local label = value.label
    local kind = value.kind
    local current_line = vim.api.nvim_win_get_cursor(0)[1]

    local function add_line()
      if map[line] ~= nil then
        table.insert(map[line], { label = label, kind = kind, range = range })
      else
        map[line] = { { label = label, kind = kind, range = range } }
      end
    end

    if only_current_line then
      if line == current_line - 1 then
        add_line()
      end
    else
      add_line()
    end
  end
  return map
end

local function get_max_len(bufnr, parsed_data)
  local max_len = -1

  for key, _ in pairs(parsed_data) do
    local line = tonumber(key)
    local current_line = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]
    if current_line then
      local current_line_len = string.len(current_line)
      max_len = math.max(max_len, current_line_len)
    end
  end

  return max_len
end

-- -- inlay hints are supported natively in 0.10 nightly
-- local function nvim10_inline_hints(bufnr, vtext, hint, cfg)
--   cfg = cfg or config
--   if hint and hint.kind == 1 then
--     vtext = ' ' .. vtext
--   end
--   pcall(function()
--     vim.api.nvim_buf_set_extmark(bufnr, namespace, hint.range.line, hint.range.character, {
--       virt_text_pos = 'inline',
--       virt_text = {
--         { vtext, config.highlight },
--       },
--       strict = false,
--       hl_mode = 'combine',
--     })
--   end)
-- end

local function handler(err, result, ctx)
  trace(result, ctx)
  if err then
    return
  end
  local bufnr = ctx.bufnr

  if vim.api.nvim_get_current_buf() ~= bufnr then
    return
  end

  local function unpack_label(label)
    local labels = ''
    for _, value in pairs(label) do
      labels = labels .. ' ' .. value.value
    end
    return labels
  end

  -- clean it up at first
  M.disable_inlay_hints()

  local parsed = parseHints(result)
  trace(parsed)

  for key, value in pairs(parsed) do
    local virt_text = ''
    local line = tonumber(key)

    local current_line = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]

    if current_line then
      local current_line_len = string.len(current_line)

      local param_hints = {}
      local other_hints = {}

      -- segregate paramter hints and other hints
      for _, value_inner in ipairs(value) do
        trace(value_inner)
        if value_inner.kind == 2 then
          table.insert(param_hints, unpack_label(value_inner.label))
        end

        if value_inner.kind == 1 then
          table.insert(other_hints, value_inner)
        end
      end
      trace(config, param_hints)

      -- show parameter hints inside brackets with commas and a thin arrow
      if not vim.tbl_isempty(param_hints) and config.show_parameter_hints then
        virt_text = virt_text .. config.parameter_hints_prefix .. '('
        for i, value_inner_inner in ipairs(param_hints) do
          virt_text = virt_text .. value_inner_inner:sub(2, -2)
          if i ~= #param_hints then
            virt_text = virt_text .. ', '
          end
        end
        virt_text = virt_text .. ') '
        trace(virt_text)
      end

      -- show other hints with commas and a thicc arrow
      if not vim.tbl_isempty(other_hints) then
        virt_text = virt_text .. config.other_hints_prefix
        for i, value_inner_inner in ipairs(other_hints) do
          if value_inner_inner.kind == 2 and config.show_variable_name then
            local char_start = value_inner_inner.range.start.character
            local char_end = value_inner_inner.range['end'].character
            trace(current_line, char_start, char_end)
            local variable_name = string.sub(current_line, char_start + 1, char_end)
            virt_text = virt_text .. variable_name .. ': ' .. value_inner_inner.label
          else
            trace(value_inner_inner.label)
            local label = unpack_label(value_inner_inner.label)
            if string.sub(label, 1, 2) == ': ' then
              virt_text = virt_text .. label:sub(3)
            else
              virt_text = virt_text .. label
            end
          end
          if i ~= #other_hints then
            virt_text = virt_text .. ', '
          end
        end
      end

      if config.right_align then
        virt_text = virt_text .. string.rep(' ', config.right_align_padding)
      end

      if config.max_len_align then
        local max_len = get_max_len(bufnr, parsed)
        virt_text = string.rep(' ', max_len - current_line_len + config.max_len_align_padding)
          .. virt_text
      end

      -- set the virtual text if it is not empty
      if virt_text ~= '' then
        vim.api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
          virt_text_pos = config.right_align and 'right_align' or 'eol',
          virt_text = {
            { virt_text, config.highlight },
          },
          hl_mode = 'combine',
        })
      end

      -- update state
      enabled = true
    end
  end
end

function M.toggle_inlay_hints()
  if inlay_display then
    vim.lsp.inlay_hint(vim.api.nvim_get_current_buf())
  elseif enabled then
    M.disable_inlay_hints(true)
  else
    M.set_inlay_hints()
  end
  enabled = not enabled
end

function M.disable_inlay_hints(update)
  if inlay_display then
    local bufnr = vim.api.nvim_get_current_buf()
    vim.lsp.inlay_hint(bufnr, false)
    return
  end
  -- clear namespace which clears the virtual text as well
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)

  if update then
    local fname = fn.expand('%:p')
    should_update[fname] = nil
  end
end

local found = false
-- Sends the request to gopls to get the inlay hints and handle them
function M.set_inlay_hints()
  local bufnr = vim.api.nvim_get_current_buf()
  -- check if lsp is ready
  if not found then
    for _, lsp in pairs(vim.lsp.get_active_clients({ bufnr = bufnr })) do
      if lsp.name == 'gopls' then
        found = true
        break
      end
    end
  end
  if not found then
    log('gopls not found')
    return
  end
  local fname = fn.expand('%:p')
  local filetime = fn.getftime(fname)
  if inlay_display then
    local wrap = utils.throttle(function()
      vim.lsp.inlay_hint(bufnr, enabled)
      should_update[fname] = filetime
    end, 300)
    return wrap()
  end
  trace('old style inlay')
  local fname = fn.expand('%:p')
  local filetime = fn.getftime(fname)
  if should_update[fname] == filetime then
    trace('already updated')
    return
  end
  local h = handler
  local wrap = utils.throttle(function()
    trace('inlay hints buf req', bufnr)
    vim.lsp.buf_request(bufnr, 'textDocument/inlayHint', get_params(), h)
    should_update[fname] = filetime
  end, 300)
  wrap()
end

return M

--[[
{
  kind = 1,
  label = { {
      value = "error"  -- this is return value
    } },
  range = {
    character = 8,
    line = 78
  }
}

{
  kind = 2,
  label = { {
      value = "path:"
    } },
  range = {
    character = 30,
    line = 78
  }
}
]]
--

-- input
-- kind=1: return ; kind = 2: param
-- { {
--     kind = 1,
--     label = { {
--         value = "[]int"
--       } },
--     paddingLeft = true,
--     position = {
--       character = 7,
--       line = 8
--     }
--   }, {
--     kind = 2,
--     label = { {
--         value = "stack:"
--       } },
--     paddingRight = true,
--     position = {
--       character = 29,
--       line = 8
--     }
--   },

-- example:
-- {
--  ["12"] = { {
--      kind = "TypeHint",
--      label = "String"
--    } },
-- }

-- local function handler_inline(err, result, ctx)
--   trace(result, ctx)
--
--   if err or result == nil then
--     return
--   end
--   local bufnr = ctx.bufnr
--
--   if vim.api.nvim_get_current_buf() ~= bufnr then
--     return
--   end
--
--   local function unpack_label(label)
--     local labels = ''
--     for _, value in pairs(label) do
--       labels = labels .. ' ' .. value.value
--     end
--
--     return utils.trim(labels)
--   end
--
--   -- clean it up at first
--   M.disable_inlay_hints()
--
--   local parsed = parseHints(result)
--   trace(parsed)
--   -- parsed is a map of line numbers to hints,
--   -- hint includes label, range, and kind
--   -- I only plan to deal gopls response
--
--   for key, value in pairs(parsed) do
--     trace(key, value)
--     for _, hint in pairs(value) do
--       trace(hint)
--       local label = unpack_label(hint.label)
--       trace(bufnr, namespace, label, hint, config)
--       nvim10_inline_hints(bufnr, label, hint, config)
--     end
--   end
-- end
