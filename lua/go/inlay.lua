--part of code was from rust-tools inlay_hints.lua
-- I was so jealous of rust-tools which provides inlay_hints until today gopls provides this feature
local M = {}
local vim = vim
local api = vim.api
local utils = require("go.utils")
local log = utils.log
local config

-- Update inlay hints when opening a new buffer and when writing a buffer to a
-- file
-- opts is a string representation of the table of options
function M.setup()
  local events = { "BufEnter", "BufWinEnter", "TabEnter", "BufWritePost" }
  config = _GO_NVIM_CFG.lsp_inlay_hints
  if config.only_current_line then
    local user_events = vim.split(config.only_current_line_autocmd, ",")
    events = vim.tbl_extend("keep", events, user_events)
  end

  local cmd_group = api.nvim_create_augroup("gopls_inlay", {})
  api.nvim_create_autocmd(events, {
    group = cmd_group,
    pattern = { "*.go", "*.mod" },
    callback = function()
      require("go.inlay").set_inlay_hints()
    end,
  })

  api.nvim_create_user_command("GoToggleInlay", function(_)
    require("go.inlay").toggle_inlay_hints()
  end, { desc = "toggle gopls inlay hints" })
  vim.defer_fn(function()
      require("go.inlay").set_inlay_hints()
  end, 1000)
end

local function get_params()
  local params = vim.lsp.util.make_given_range_params()
  params["range"]["start"]["line"] = 0
  params["range"]["end"]["line"] = vim.api.nvim_buf_line_count(0) - 1
  log(params)
  return params
end

local namespace = vim.api.nvim_create_namespace("experimental/inlayHints")
-- whether the hints are enabled or not
local enabled = nil

-- parses the result into a easily parsable format
-- input
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

local function parseHints(result)
  local map = {}
  local only_current_line = config.only_current_line

  if type(result) ~= "table" then
    return {}
  end
  for _, value in pairs(result) do
    local range = value.position
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
      if line == tostring(current_line - 1) then
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

local function handler(err, result, ctx)
  log(result, ctx)
  if err then
    return
  end
  local bufnr = ctx.bufnr

  if vim.api.nvim_get_current_buf() ~= bufnr then
    return
  end

local function unpack_label(label)
    local labels = ""
    for _, value in pairs(label) do
       labels = labels .. " " .. value.value
    end
    return labels
end

  -- clean it up at first
  M.disable_inlay_hints()

  local parsed = parseHints(result)
  log(parsed)

  for key, value in pairs(parsed) do
    local virt_text = ""
    local line = tonumber(key)

    local current_line = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]

    if current_line then
      local current_line_len = string.len(current_line)

      local param_hints = {}
      local other_hints = {}

      -- segregate paramter hints and other hints
      for _, value_inner in ipairs(value) do
        log(value_inner)
        if value_inner.kind == 2 then
          table.insert(param_hints, unpack_label(value_inner.label))
        end

        if value_inner.kind == 1 then
          table.insert(other_hints, value_inner)
        end
      end
      log(config, param_hints)

      -- show parameter hints inside brackets with commas and a thin arrow
      if not vim.tbl_isempty(param_hints) and config.show_parameter_hints then
        virt_text = virt_text .. config.parameter_hints_prefix .. "("
        for i, value_inner_inner in ipairs(param_hints) do
          virt_text = virt_text .. value_inner_inner:sub(1, -2)
          if i ~= #param_hints then
            virt_text = virt_text .. ", "
          end
        end
        virt_text = virt_text .. ") "
        log(virt_text)
      end

      -- show other hints with commas and a thicc arrow
      if not vim.tbl_isempty(other_hints) then
        virt_text = virt_text .. config.other_hints_prefix
        for i, value_inner_inner in ipairs(other_hints) do
          if value_inner_inner.kind == 2 and config.show_variable_name then
            local char_start = value_inner_inner.range.start.character
            local char_end = value_inner_inner.range["end"].character
            log(current_line, char_start, char_end)
            local variable_name = string.sub(current_line, char_start + 1, char_end)
            virt_text = virt_text .. variable_name .. ": " .. value_inner_inner.label
          else
            log(value_inner_inner.label)
            local label = unpack_label(value_inner_inner.label)
            if string.sub(label, 1, 2) == ": " then
              virt_text = virt_text .. label:sub(3)
            else
              virt_text = virt_text .. label
            end
          end
          if i ~= #other_hints then
            virt_text = virt_text .. ", "
          end
        end
      end

      if config.right_align then
        virt_text = virt_text .. string.rep(" ", config.right_align_padding)
      end

      if config.max_len_align then
        local max_len = get_max_len(bufnr, parsed)
        virt_text = string.rep(" ", max_len - current_line_len + config.max_len_align_padding) .. virt_text
      end

      -- set the virtual text if it is not empty
      if virt_text ~= "" then
        vim.api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
          virt_text_pos = config.right_align and "right_align" or "eol",
          virt_text = {
            { virt_text, config.highlight },
          },
          hl_mode = "combine",
        })
      end

      -- update state
      enabled = true
    end
  end
end

function M.toggle_inlay_hints()
  if enabled then
    M.disable_inlay_hints()
  else
    M.set_inlay_hints()
  end
  enabled = not enabled
end

function M.disable_inlay_hints()
  -- clear namespace which clears the virtual text as well
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
end

-- Sends the request to gopls to get the inlay hints and handle them
function M.set_inlay_hints()
  -- check if lsp is ready
  local found = false
  for _, lsp in pairs(vim.lsp.buf_get_clients()) do
    if lsp.name == "gopls" then
      found = true
      break
    end
  end
  if not found then
    return
  end
  vim.lsp.buf_request(0, "textDocument/inlayHint", get_params(), handler)
end

return M
