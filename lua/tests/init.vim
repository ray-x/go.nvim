set rtp +=.
set rtp +=../../plugins/plenary.nvim/
set rtp +=../../plugins/nvim-treesitter
set rtp +=../../plugins/nvim-lspconfig/

runtime! plugin/plenary.vim
runtime! plugin/nvim-treesitter.vim
runtime! plugin/playground.vim
runtime! plugin/nvim-lspconfig.vim

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
  gofmt = 'gofumpt',
  goimports = "goimports",
  verbose = true,
  log_path = vim.fn.expand("$HOME") .. "/tmp/gonvim.log",
  lsp_cfg = true,
})
EOF
