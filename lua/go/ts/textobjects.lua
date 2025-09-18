local util = require("go.utils")
local plugins = util.load_plugin

local M = {}

function M.setup()
  if not plugins("nvim-treesitter") then
    util.log("treesitter not avalible")
    return
  end

  local ok, configs = pcall(require, 'nvim-treesitter.configs')
  if not ok then
    configs = require('nvim-treesitter')
  end

  configs.setup({
    textobjects = {
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          -- You can use the capture groups defined in textobjects.scm
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
          ["ac"] = "@class.outer",
          ["ic"] = "@class.inner",
        },
      },
      move = {
        enable = true,
        set_jumps = true, -- whether to set jumps in the jumplist
        goto_next_start = {
          ["]]"] = "@function.outer",
        },
        goto_next_end = {
          ["]["] = "@function.outer",
        },
        goto_previous_start = {
          ["[["] = "@function.outer",
        },
        goto_previous_end = {
          ["[]"] = "@function.outer",
        },
      },
    },
  })
end

return M
