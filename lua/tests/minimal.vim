set rtp +=.
set rtp +=../plenary.nvim/
set rtp +=../nvim-treesitter
set rtp +=../nvim-lspconfig/

runtime! plugin/plenary.vim
runtime! plugin/nvim-treesitter.vim
runtime! plugin/playground.vim
runtime! plugin/nvim-lspconfig.vim
runtime! plugin/guihua.lua

set noswapfile
set nobackup

filetype indent off
set nowritebackup
set noautoindent
set nocindent
set nosmartindent
set indentexpr=
set shada="NONE"

lua << EOF
_G.test_rename = true
_G.test_close = true
require("plenary/busted")
require("go").setup({
  debug = true,
  verbose = true,
  gofmt = 'gofumpt',
  goimports = "goimports",
  log_path = vim.fn.expand("$HOME") .. "/tmp/gonvim.log",
  lsp_cfg = true,
})
EOF
