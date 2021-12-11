local util = require 'go.utils'
local plugins = util.load_plugin

local M = {}

function M.setup()
  if not plugins('treesitter') then
    return
  end

  local ts = require 'nvim-treesitter.configs'
  ts.setup {
    textobjects = {
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          ['af'] = { go = '@function.outer' },
          ['if'] = { go = '@function.inner' },
          ['ac'] = { go = '@comment.outer' },
        },
      },
      move = {
        enable = true,
        set_jumps = true,
        goto_next_start = {
          [']]'] = { go = '@function.outer' },
        },
        goto_previous_start = {
          ['[['] = { go = '@function.outer' },
        },
      },
    },
  }
end

return M
