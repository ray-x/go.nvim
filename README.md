# go.nvim

A modern go neovim plugin based on treesitter, nvim-lsp and dap debugger. It is written in Lua and async as much as possible.
PR & Suggestions welcome.
The plugin covers most features required for a gopher.

- Async jobs with libuv
- Syntex highlight & Texobject: Native treesitter support is faster and more accurate. All you need is a theme support treesitter, try
  [aurora](https://github.com/ray-x/aurora). Also, there are quite a few listed in [awesome-neovim](https://github.com/rockerBOO/awesome-neovim)
- All the GoToXxx (E.g reference, implementation, definition, goto doc, peek code/doc etc) You need lspconfig setup. There are lots of posts on how to
  set it up. You can also check my [navigator](https://github.com/ray-x/navigator.lua) gopls setup [lspconfig.lua](https://github.com/ray-x/navigator.lua/blob/master/lua/navigator/lspclient/clients.lua)
- Runtime lint/vet/compile: Supported by lsp (once you setup up your lsp client), GoLint with golangci-lint also supported
- Build/Make/Test: Go.nvim provides supports for these by an async job wrapper.
- Test coverage: run test coverage and show coverage sign
- Dlv Debug: with Dap UI
- Unit test: Support [gotests](https://github.com/cweill/gotests)
- tag modify: Supports gomodifytags
- Code format: Supports LSP format and GoFmt
- CodeLens : gopls codelens and codelens action support
- Comments: Add autodocument for your package/function/struct/interface. This feature is unique and can help you suppress golint
  errors...
  Go to alternative go file (between test and source)

## install

make sure the `$GOPATH/bin` path is added to your `$PATH` environment variable. To check this you can run

```bash
echo $PATH | grep "$GOPATH/bin"
```

if nothing shows up, you can add the following to your shell config file

```bash
export PATH=$PATH:$GOPATH/bin
```

add 'ray-x/go.nvim' to your package manager, the dependency is `treesitter` (and optionally, treesitter-objects)
related binaries will be installed the first time you use it
Add format in your vimrc.

```vim
autocmd BufWritePre *.go :silent! lua require('go.format').gofmt()
```

To startup/setup the plugin

```lua
require('go').setup()
```

## Screenshots

### Add comments

![auto comments](https://github.com/ray-x/files/blob/master/img/go.nvim/comment.gif?raw=true)

### Add/Remove tags

![auto tag](https://github.com/ray-x/files/blob/master/img/go.nvim/tags.gif?raw=true)

## refactor gorename

gorename as an alternative to gopls rename as it supports rename across packages
Command: GoRename

## code format

nvim-lsp support goimport by default.

```vim
autocmd BufWritePre (InsertLeave?) <buffer> lua vim.lsp.buf.formatting_sync(nil,500)
```

The plugin provides code format, by default is goline + gofumpt (stricter version of gofmt)

Use following code to format go code

```lua
require("go.format").gofmt()  -- format only
require("go.format").goimport()  -- goimport + gofmt
```

To config format on save, in your init.lua:

```lua
-- Format on save
vim.api.nvim_exec([[ autocmd BufWritePre *.go :silent! lua require('go.format').gofmt() ]], false)

-- Import on save
vim.api.nvim_exec([[ autocmd BufWritePre *.go :silent! lua require('go.format').goimport() ]], false)


```

## Auto fill

Note: auto fill struct also supported by gopls lsp-action

| command      | Description                                                   |
| ------------ | ------------------------------------------------------------- |
| GoFillStruct | auto fill struct                                              |
| GoFillSwitch | fill switch                                                   |
| GoIfErr      | Add if err                                                    |
| GoFixPlurals | change func foo(b int, a int, r int) -> func foo(b, a, r int) |

```go
package foo

import "io"

func Foo() (io.Reader, error) { // the cursor on this line to add if err statement
}
```

![auto struct](https://github.com/ray-x/files/blob/master/img/go.nvim/fstruct.gif?raw=true)

## Textobject

Supported by treesitter. TS provided better parse result compared to regular expression.
Check [my treesitter config file](https://github.com/ray-x/dotfiles/blob/master/nvim/lua/modules/lang/treesitter.lua) on how to setup
textobjects. Also with treesitter-objects, you can move, swap the selected blocks of codes, which is fast and accurate.

## Build and test

| command         | Description                                                              |
| --------------- | ------------------------------------------------------------------------ |
| GoMake          | make                                                                     |
| GoBuild         |                                                                          |
| GoGenerate      |                                                                          |
| GoRun           | e.g. GoRun equal to `go run .`; or `GoRun ./cmd` equal to `go run ./cmd` |
| GoTest          | go test ./...                                                            |
| GoTest yourtags | go test ./... -tags=yourtags                                             |
| GoLint          | golangci-lint                                                            |
| GoCoverage      | go test -coverprofile                                                    |

Show test coverage:

<img width="479" alt="GoTestCoverage" src="https://user-images.githubusercontent.com/1681295/130821038-fa2545c6-16f6-4448-9a0c-91a1ab333750.png">

Provided wrapper for gobulild/test etc with async make
Also suggest to use [vim-test](https://github.com/vim-test/vim-test), which can run running tests on different
granularities.

## Unit test with [gotests](https://github.com/cweill/gotests) and testify

Support table based unit test auto generate, parse current function/method name using treesitter

| command            | Description                                             |
| ------------------ | ------------------------------------------------------- |
| GoTestFunc         | run test for current func                               |
| GoTestFunc yourtag | run test for current func with `-tags yourtag` option   |
| GoTestFile         | run test for current file folder                        |
| GoTestFile yourtag | run test for current folder with `-tags yourtag` option |
| GoAddTest          |                                                         |
| GoAddExpTest       | Add tests for exported funcs                            |
| GoAddAllTest       | Add tests for all funcs                                 |

## GoDoc

Show go doc for api in neovim floating window. e.g. `GoDoc fmt.Println`

![Godoc](https://user-images.githubusercontent.com/1681295/133886804-cc110fae-6fbf-4218-9c22-07fc9d6a64d2.jpg)

## Modifytags

Modify struct tags by [`gomodifytags`](https://github.com/fatih/gomodifytags) and treesitter

| command    | Description |
| ---------- | ----------- |
| GoAddTag   |             |
| GoRmTag    |             |
| GoClearTag |             |

## GoFmt

nvim-lsp support goimport by default. The plugin provided a new formatter, goline + gofumpt (stricter version of
gofmt)

| command  | Description                 |
| -------- | --------------------------- |
| GoFmt    | goline + gofumpt            |
| GoImport | goline + goimport + gofumpt |

## GoImpl

generate method stubs for implementing an interface

Usage:

```
:GoImpl {receiver} {interface}
```

e.g:

```
:GoImpl f *File io.Reader
```

## Debug

| command          | Description                                      |
| ---------------- | ------------------------------------------------ |
| GoDebug          | start debug session                              |
| GoDebug test     | start debug session for go test file             |
| GoDebug nearest  | start debug session for nearest go test function |
| GoBreakToggle    |                                                  |
| GoBreakCondition | conditional break                                |
| GoDbgStop        | Stop debug session                               |

## Swtich between go and test file

| command          | Description                                             |
| ---------------- | ------------------------------------------------------- |
| GoAlt / GoAlt!   | open alternative go file (use ! to create if not exist) |
| GoAltS / GoAltS! | open alternative go file in split                       |
| GoAltV / GoAltV! | open alternative go file in vertical split              |

## Comments and Doc

Auto doc (to suppress golang-lint warning), generate comments by treesitter parsing result

```go
type GoLintComplaining struct{}
```

And run

```lua
 lua.require('go.comment').gen() -- or your faviourite key binding and setup placeholder "no more complaint ;P"
```

The code will be:

```go
// GoLintComplaining struct no more complaint ;P
type GoLintComplaining struct{}
```

## LSP

LSP supported by nvim-lsp is good enough for a gopher. If you looking for a better GUI. You can install
[navigator](https://github.com/ray-x/navigator.lua), or lspsaga, and lsp-utils etc.

## LSP CodeLens

Gopls supports code lens. To run gopls code lens action `GoCodeLenAct`
Note: codelens need to be enabled in gopls, check default config in

## Lint

Supported by LSP, also GoLint command (by calling golangcl-lint) if you need background golangci-lint check, you can
configure it with ALE

## Debug with dlv

Setup for Debug provided. Need Dap and Dap UI plugin
![dap](https://user-images.githubusercontent.com/1681295/125160289-743ba080-e1bf-11eb-804f-6a6d227ec33b.jpg)
GDB style key mapping is used

### Keymaps

| key | Description                              |
| --- | ---------------------------------------- |
| c   | continue                                 |
| n   | next                                     |
| s   | step                                     |
| o   | stepout                                  |
| S   | cap S: stop debug                        |
| u   | up                                       |
| D   | cap D: down                              |
| C   | cap C: run to cursor                     |
| b   | toggle breakpoint                        |
| P   | cap P: pause                             |
| p   | print, hover value (also in visual mode) |

### Commands

| Command        | Description                                                                                 |
| -------------- | ------------------------------------------------------------------------------------------- |
| GoDebug        | Start debugger, to debug test, run `Debug test`, to add addition args run `Debug arg1 arg2` |
| GoBreakToggle  | toggle break point                                                                          |
| BreakCondition | conditional break point                                                                     |
| ReplRun        | dap repl run_last                                                                           |
| ReplToggle     | dap repl toggle                                                                             |

### Required DAP plugins

The plugin will setup debugger. But you need to install

- dap
  - 'mfussenegger/nvim-dap'
- dap ui (optional)

  - 'rcarriga/nvim-dap-ui'

- dap virtual text (optional)
  - 'theHamsta/nvim-dap-virtual-text'

Also you can check telescope dap extension : nvim-telescope/telescope-dap.nvim

Sample vimrc for DAP

```viml
 Plug 'mfussenegger/nvim-dap'
 Plug 'rcarriga/nvim-dap-ui'
 Plug 'theHamsta/nvim-dap-virtual-text'
 " Plug 'nvim-telescope/telescope-dap.nvim'

```

## Commands

Check [go.lua](https://github.com/ray-x/go.nvim/blob/master/lua/go.lua) on all the commands provided

## configuration

Configure from lua suggested, The default setup:

```lua
require('go').setup({
  goimport='gopls', -- goimport command, can be gopls[default] or goimport
  gofmt = 'gofumpt', --gofmt cmd,
  max_line_len = 120, -- max line length in goline format
  tag_transform = false, -- tag_transfer  check gomodifytags for details
  test_template = '', -- default to testify if not set; g:go_nvim_tests_template  check gotests for details
  test_template_dir = '', -- default to nil if not set; g:go_nvim_tests_template_dir  check gotests for details
  comment_placeholder = '' ,  -- comment_placeholder your cool placeholder e.g. ﳑ       
  icons = {breakpoint = '🧘', currentpos = '🏃'},
  verbose = false,  -- output loginf in messages
  lsp_cfg = false, -- true: apply go.nvim non-default gopls setup, if it is a list, will merge with gopls setup e.g.
                   -- lsp_cfg = {settings={gopls={matcher='CaseInsensitive', ['local'] = 'your_local_module_path', gofumpt = true }}}
  lsp_gofumpt = false, -- true: set default gofmt in gopls format to gofumpt
  lsp_on_attach = true, -- if a on_attach function provided:  attach on_attach function to gopls
                       -- true: will use go.nvim on_attach if true
                       -- nil/false do nothing
  lsp_codelens = true, -- set to false to disable codelens, true by default
  gopls_remote_auto = true, -- add -remote=auto to gopls
  gopls_cmd = nil, -- if you need to specify gopls path and cmd, e.g {"/home/user/lsp/gopls", "-logfile",
  fillstruct = 'gopls', -- can be nil (use fillstruct, slower) and gopls
  "/var/log/gopls.log" }
  lsp_diag_hdlr = true, -- hook lsp diag handler
  dap_debug = true, -- set to false to disable dap
  dap_debug_keymap = true, -- set keymaps for debugger
  dap_debug_gui = true, -- set to true to enable dap gui, highly recommand
  dap_debug_vt = true, -- set to true to enable dap virtual text
})
```

You will need to add keybind yourself:
e.g

```lua
  vim.cmd("autocmd FileType go nmap <Leader><Leader>l GoLint")
  vim.cmd("autocmd FileType go nmap <Leader>gc :lua require('go.comment').gen()")

```

## Nvim LSP setup

go.nvim provided a better non-default setup for gopls (includes debounce, staticcheck, diagnosticsDelay etc)

This gopls setup provided by go.nvim works perfectly fine for most of the cases. You can also install [navigator.lua](https://github.com/ray-x/navigator.lua) which can auto setup all lsp clients and provides a better GUI.

For diagnostic issue, you can use the default setup. There are also quite a few plugins that you can use to explore issues, e.g. [navigator.lua](https://github.com/ray-x/navigator.lua), [folke/lsp-trouble.nvim](https://github.com/folke/lsp-trouble.nvim). [Nvim-tree](https://github.com/kyazdani42/nvim-tree.lua) and [Bufferline](https://github.com/akinsho/nvim-bufferline.lua) also introduced lsp diagnostic hooks.

## Sample vimrc

The following vimrc will enable all features provided by go.nvim

```viml
set termguicolors
call plug#begin('~/.vim/plugged')
Plug 'neovim/nvim-lspconfig'
Plug 'nvim-treesitter/nvim-treesitter'

Plug 'mfussenegger/nvim-dap'
Plug 'rcarriga/nvim-dap-ui'
Plug 'theHamsta/nvim-dap-virtual-text'

Plug 'ray-x/go.nvim'

call plug#end()

lua <<EOF
require 'go'.setup({
  goimport = 'gopls', -- if set to 'gopls' will use golsp format
  gofmt = 'gopls', -- if set to gopls will use golsp format
  max_line_len = 120,
  tag_transform = false,
  test_dir = '',
  comment_placeholder = '   ',
  lsp_cfg = true, -- false: use your own lspconfig
  lsp_gofumpt = true, -- true: set default gofmt in gopls format to gofumpt
  lsp_on_attach = true, -- use on_attach from go.nvim
  dap_debug = true,
})

local protocol = require'vim.lsp.protocol'

EOF
```

This will setup gopls with non default configure provided by go.nvim (Includes lspconfig default keymaps)
