local utils = require("go.utils")
local api = vim.api
local guihua_term = utils.load_plugin("guihua.lua", "guihua.floating")
if not guihua_term then
  utils.warn("guihua not installed, please install ray-x/guihua.lua for GUI functions")
end

local function close_float_terminal()
  local cur_buf = api.nvim_get_current_buf()
  local has_var, float_term_win = pcall(api.nvim_buf_get_var, cur_buf, "go_float_terminal_win")
  if not has_var then
    return
  end
  if float_term_win[1] ~= nil and api.nvim_buf_is_valid(float_term_win[1]) then
    api.nvim_buf_delete(float_term_win[1], { force = true })
  end
  if float_term_win[2] ~= nil and api.nvim_win_is_valid(float_term_win[2]) then
    api.nvim_win_close(float_term_win[2], true)
  end
end

local term = function(opts)
  close_float_terminal()

  local columns = api.nvim_get_option("columns")
  local lines = api.nvim_get_option("lines")

  local cur_buf = api.nvim_get_current_buf()
  local win_width, win_height
  if columns > 140 then
    -- split in right
    win_height = math.ceil(lines * 0.98)
    win_width = math.ceil(columns * 0.45)
    win_width = math.max(80, win_width)

    opts.y = win_height
    opts.x = columns - win_width
  else
    win_height = math.ceil(lines * 0.45)
    win_width = math.ceil(columns * 0.98)

    opts.y = opts.y or lines - win_height
    opts.x = opts.x or 1
  end
  opts.win_height = opts.win_height or win_height
  opts.win_width = opts.win_width or win_width
  opts.border = opts.border or "single"
  if opts.autoclose == nil then
    opts.autoclose = true
  end
  local buf, win, closer = guihua_term.floating_term(opts)
  api.nvim_command("setlocal nobuflisted")
  api.nvim_buf_set_var(cur_buf, "go_float_terminal_win", { buf, win })

  return buf, win, closer
end

-- term({cmd = 'echo abddeefsfsafd',  autoclose = false})
return { run = term, close = close_float_terminal }
