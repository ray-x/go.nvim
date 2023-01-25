local utils = require('go.utils')
local api = vim.api
local log = utils.log
local guihua_term = utils.load_plugin('guihua.lua', 'guihua.floating')
if not guihua_term then
  utils.warn('guihua not installed, please install ray-x/guihua.lua for GUI functions')
end

local function close_float_terminal()
  local cur_buf = api.nvim_get_current_buf()
  local has_var, float_term_win = pcall(api.nvim_buf_get_var, cur_buf, 'go_float_terminal_win')
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

  local columns = api.nvim_get_option('columns')
  local lines = api.nvim_get_option('lines')

  local cur_buf = api.nvim_get_current_buf()
  local win_width, win_height
  local wratio = _GO_NVIM_CFG.floaterm.width
  local hratio = _GO_NVIM_CFG.floaterm.height
  local position = _GO_NVIM_CFG.floaterm.posititon
  local l = 0.98

  if position == 'center' then -- center
    log('center')
    opts.x = (columns - math.ceil(columns * wratio)) / 2
    opts.y = (lines - math.ceil(lines * hratio)) / 2
    win_height = math.ceil(lines * hratio)
    win_width = math.ceil(columns * wratio)
    log(opts, win_height, win_width)
  elseif position == 'top' then
    opts.x = 1
    opts.y = 1
    win_height = math.ceil(lines * hratio)
    win_width = math.ceil(columns * l)
  elseif position == 'bottom' then
    opts.x = 1
    opts.y = lines - math.ceil(lines * hratio)
    win_height = math.ceil(lines * hratio)
    win_width = math.ceil(columns * l)
  elseif position == 'left' then
    opts.x = 1
    opts.y = 1
    win_height = math.ceil(lines * l)
    win_width = math.ceil(columns * wratio)
  elseif position == 'right' then
    opts.x = columns - math.ceil(columns * wratio)
    opts.y = 1
    win_height = math.ceil(lines * l)
    win_width = math.ceil(columns * wratio)
  else -- default to auto
    if columns > 120 then
      -- split in right
      wratio = wratio
      win_height = math.ceil(lines * l)
      win_width = math.ceil(columns * wratio)
      win_width = math.max(80, win_width)

      opts.y = win_height
      opts.x = columns - win_width
    elseif lines > 40 then -- bottom
      win_height = math.ceil(lines * wratio)
      win_width = math.ceil(columns * l)

      opts.y = lines - win_height
      opts.x = 1
    else
      win_height = math.ceil(lines * l)
      win_width = math.ceil(columns * l)

      opts.y = 1
      opts.x = 1
    end
  end

  opts.win_height = opts.win_height or win_height
  opts.win_width = opts.win_width or win_width
  opts.border = opts.border or 'single'
  if opts.autoclose == nil then
    opts.autoclose = true
  end
  -- run in neovim shell
  if type(opts.cmd) == 'table' then
    opts.cmd = table.concat(opts.cmd, ' ')
  end

  utils.log(opts)
  local buf, win, closer = guihua_term.floating_term(opts)
  api.nvim_command('setlocal nobuflisted')
  api.nvim_buf_set_var(cur_buf, 'go_float_terminal_win', { buf, win })
  api.nvim_buf_set_var(cur_buf, 'shellcmdflag', 'shell-unquoting')
  return buf, win, closer
end

-- term({ cmd = 'echo abddeefsfsafd', autoclose = false })
return { run = term, close = close_float_terminal }
