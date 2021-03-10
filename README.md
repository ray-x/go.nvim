# [WIP] go.nvim

A modern golang neovim plugin based on treesitter and nvim-lsp. Written in Lua. Async as much as possible.
PR & Suggestions welcome

## install

add 'ray-x/go.nvim' to your package manager
related binaries will be installed the first time you using it
Add lsp format in your vimrc. You can check my dotfiles for details

```lua
require('go').setup()
```

## code format

nvim-lsp support goimport by default.
```vim
autocmd BufWritePre (InsertLeave?) <buffer> lua vim.lsp.buf.formatting_sync(nil,500)
```

The plugin provides code format, by default is goline + gofumports (stricter version of goimport)

The format tool is a asyn format tool in format.lua

```lua
require("go.format").gofmt()
require("go.format").goimport()
```

## Textobject

Supported by treesitter. TS provided better parse result compared to regular expression.

## Build and test

Provided wrapper for gobulild/test etc

## unit test with gotests

Support table based unit test auto generate, parse current function/method name using treesitter

## Modifytags

modifytags by `modifytags` and treesitter

## GoFmt

nvim-lsp support goimport by default. The plugin provided a new formatter, goline + gofumports (stricter version of
goimport)

## Comments and Doc

Auto doc (to suppress golang-lint warning), generate comments by treesitter parsing result

```go
type GoLintComplaining struct{}
```
```lua
 lua.require('go.comment').add_comment() -- or your faviourite key binding and setup placeholder "no more complaint ;P"
```
The code will be:
```go
// GoLintComplaining struct no more complaint ;P
type GoLintComplaining struct{}
```

## LSP

LSP supported by nvim-lsp is good enough for a gopher. If you looking for a better GUI. lspsaga and lsp-utils are
what you are looking for.

## Lint

Supported by LSP, if you need golangci-lint better with ALE

## configuration

lua suggested:
```lua
require('go').setup(cfg = {
  goimport='gofumports', -- g:go_nvim_goimport
  gofmt = 'gofumpt', --g:go_nvim_gofmt,
  max_len = 100, -- g:go_nvim_max_len
  transform = false, -- vim.g.go_nvim_tag_transfer  check gomodifytags for details
  test_template = '', -- default to testify if not set; g:go_nvim_tests_template  check gotests for details
  test_template_dir = '', -- default to nil if not set; g:go_nvim_tests_template_dir  check gotests for details
  comment_placeholder = '' ,  -- vim.g.go_nvim_comment_placeholder your cool placeholder e.g. ﳑ       
  verbose = false,  -- output loginf in messages
})
```
