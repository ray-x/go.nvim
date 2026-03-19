-- Shared UI helpers for go.nvim AI features
local M = {}

local utils = require('go.utils')

--- Show markdown text in a guihua TextView float.
--- @param md_text string  Markdown text to display
--- @param title string|nil  Optional window title (default: " GoCodeReview ")
function M.show_markdown_float(md_text, title)
  local md_lines = vim.split(vim.trim(md_text), '\n', { plain = true })
  if #md_lines == 0 or (#md_lines == 1 and md_lines[1] == '') then
    return
  end
  local TextView = utils.load_plugin('guihua.lua', 'guihua.textview')
  if not TextView then
    return
  end
  local width = math.min(math.max(60, vim.o.columns - 10), 120)
  local height = math.min(#md_lines + 4, math.floor(vim.o.lines * 0.7))
  local win = TextView:new({
    loc = 'top_center',
    rect = { height = height, width = width, pos_x = 0, pos_y = 4 },
    allow_edit = false,
    enter = true,
    ft = 'markdown',
    title = title or ' GoCodeReview ',
    title_pos = 'center',
    data = md_lines,
  })
  if win and win.buf then
    for _, key in ipairs({ 'q', '<Esc>' }) do
      vim.keymap.set('n', key, function()
        win:close()
      end, { buffer = win.buf, nowait = true, silent = true })
    end
  end
end

--- Render a response in a floating scratch window (used by GoAIChat)
--- @param response string
--- @param title string|nil
function M.open_chat_float(response, title)
  local lines = vim.split(response, '\n', { plain = true })

  -- Add a blank leading line for padding
  table.insert(lines, 1, '')
  table.insert(lines, '')

  local width = math.min(math.max(60, vim.o.columns - 20), 120)
  local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.7))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf })

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. (title or 'GoAIChat') .. ' ',
    title_pos = 'center',
  })
  vim.api.nvim_set_option_value('wrap', true, { win = win })
  vim.api.nvim_set_option_value('linebreak', true, { win = win })

  -- Close keymaps
  for _, key in ipairs({ 'q', '<Esc>', '<CR>' }) do
    vim.keymap.set('n', key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, silent = true })
  end
end

return M
