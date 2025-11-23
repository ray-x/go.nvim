vim.opt.rtp:append('.')
vim.opt.rtp:append('../plenary.nvim/')
vim.opt.rtp:append('../nvim-treesitter')
vim.opt.rtp:append('../nvim-lspconfig/')
vim.opt.rtp:append('../guihua.lua/')

-- Add the treesitter parser install directory to runtimepath BEFORE loading plugins
local parser_install_dir = vim.fn.stdpath('data') .. '/site'
vim.opt.rtp:prepend(parser_install_dir)

vim.cmd([[
  runtime! plugin/plenary.vim
  runtime! plugin/nvim-treesitter.vim
  runtime! plugin/playground.vim
  runtime! plugin/nvim-lspconfig.vim
  runtime! plugin/guihua.lua
]])

vim.opt.swapfile = false -- no swapfile
vim.opt.backup = false -- no backup
vim.opt.writebackup = false -- no writebackup

vim.cmd('filetype indent off')
vim.opt.autoindent = false
vim.opt.cindent = false
vim.opt.smartindent = false
vim.opt.indentexpr = '' -- clear any indentexpr

require('plenary.busted')

require('go').setup({
  debug = true,
  verbose = true,
  gofmt = 'gofumpt',
  goimports = 'goimports',
  log_path = vim.fn.expand('$HOME') .. '/.cache/nvim/gonvim.log',
  lsp_cfg = true,
})

require('nvim-treesitter').setup({
  -- Directory to install parsers and queries to
  install_dir = parser_install_dir,
})

vim.o.swapfile = false
vim.bo.swapfile = false

-- Disable automatic treesitter start for now
vim.g.ts_highlight_disable = true

vim.cmd([[set completeopt+=menuone,noselect,popup]])
vim.lsp.enable('gopls')
