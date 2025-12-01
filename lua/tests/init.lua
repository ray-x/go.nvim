-- Define the plugin directory variable (s:plugin_dir in VimScript)
local plugin_dir = vim.fn.expand('~/.local/share/nvim/site/pack/vendor/start')

-- set rtp+=.
vim.opt.rtp:append('.')

vim.opt.rtp:prepend(plugin_dir .. '/plenary.nvim')
vim.opt.rtp:prepend(plugin_dir .. '/nvim-treesitter')
vim.opt.rtp:prepend(plugin_dir .. '/nvim-lspconfig')

vim.cmd('runtime! plugin/plenary.vim')
vim.cmd('runtime! plugin/nvim-treesitter.vim')
vim.cmd('runtime! plugin/playground.vim')
vim.cmd('runtime! plugin/nvim-lspconfig.vim')

-- Option settings (set noswapfile, set nobackup, etc.)
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.autoindent = false
vim.opt.cindent = false
vim.opt.smartindent = false
vim.opt.indentexpr = ''
vim.opt.shada = 'NONE'

-- filetype indent off
vim.cmd('filetype indent off')

-- Lua configuration block
_G.test_rename = true
_G.test_close = true

-- require("plenary/busted")
require('plenary.busted')

-- require("go").setup({...})
require('go').setup({
  gofmt = 'gofumpt',
  goimports = 'goimports',
  verbose = true,
  log_path = vim.fn.expand('$HOME') .. '/.cache/nvim/gonvim.log',
  lsp_cfg = true,
})

vim.lsp.enable('gopls')

require('nvim-treesitter').setup({
  -- Directory to install parsers and queries to
  install_dir = vim.fn.stdpath('data') .. '/site',
})
vim.opt.rtp:append(vim.fn.stdpath('data') .. '/site')

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'go' },
  callback = function()
    vim.treesitter.start()
  end,
})
