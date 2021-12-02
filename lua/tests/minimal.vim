set rtp +=.
set rtp +=../plenary.nvim/
set rtp +=../nvim-treesitter
set rtp +=../nvim-lspconfig/

runtime! plugin/plenary.vim

lua vim.fn.setenv("DEBUG_PLENARY", true)
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


lua << EOF
_G.test_rename = true
_G.test_close = true
require("plenary/busted")
require("go").setup({
  gofmt = 'gofumpt',
  goimport = "goimports",
  log_path = vim.fn.expand("$HOME") .. "/gonvim.log",
  lsp_cfg = true,
})
EOF
