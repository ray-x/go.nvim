# go.nvim

A modern go neovim plugin based on treesitter, nvim-lsp and dap debugger. It is written in Lua and async as much as possible.
PR & Suggestions welcome.
The plugin covers most features required for a gopher.
- Perproject setup. Allows you setup plugin behavior per project based on project files(launch.json, .gonvim)
- Async jobs with libuv
- Syntax highlight & Texobject: Native treesitter support is faster and more accurate. All you need is a theme support treesitter, try
  [aurora](https://github.com/ray-x/aurora), [starry.nvim](https://github.com/ray-x/starry.nvim). Also, there are quite a few listed in [awesome-neovim](https://github.com/rockerBOO/awesome-neovim)
- All the GoToXxx (E.g reference, implementation, definition, goto doc, peek code/doc etc) You need lspconfig setup. There are lots of posts on how to
  set it up. You can also check my [navigator](https://github.com/ray-x/navigator.lua) gopls setup [lspconfig.lua](https://github.com/ray-x/navigator.lua/blob/master/lua/navigator/lspclient/clients.lua)
- Runtime lint/vet/compile: Supported by lsp (once you setup up your lsp client), GoLint with golangci-lint also supported
- Build/Make/Test: Go.nvim provides supports for these by an async job wrapper.
- Test coverage: run test coverage and show coverage sign and function metrics
- Dlv Debug: with [nvim-dap](https://github.com/mfussenegger/nvim-dap) and [Dap UI](https://github.com/rcarriga/nvim-dap-ui).
- Load vscode launch configuration
- Unit test: generate unit test framework with [gotests](https://github.com/cweill/gotests). Run test with
  richgo/ginkgo/gotestsum/go test
- Add and remove tag for struct with tag modify(gomodifytags)
- Code format: Supports LSP format and GoFmt(with golines)
- CodeLens : gopls codelens and codelens action support
- Comments: Add autodocument for your package/function/struct/interface. This feature is unique and can help you suppress golint
  errors...
- Go to alternative go file (between test and source)
- Test with ginkgo, richgo inside floaterm (to enable floaterm, guihua.lua has to be installed)
- Go 1.18 support, configure your go to `go1.18` in config
- Code refactor made easy: GoFixPlural, FixStruct, FixSwitch, Add comment, IfErr, ModTidy, GoGet, extract function/block with codeactions... Most of the tools are built on top of
  treesitter AST or go AST. It is fast and accurate.
- GoCheat get go cheatsheet from [cheat.sh](https://cheat.sh/).
- Smart build tag detection when debug/run tests (e.g. `//go:build integration`)
- Generate mocks with mockgen
- Inlay hints: gopls (version 0.9.x or greater) inlay hints
- luasnip: you might use friendly-snippets already, you still need to try pure lua snippets with go.nvim out,
checkout [LuaSnip Tutorial](https://www.youtube.com/watch?v=ub0REXjhpmk) and [TJ's Introduction to LuaSnip](https://www.youtube.com/watch?v=Dn800rlPIho)

## Installation

Use your favorite package manager to install. The dependency `treesitter` (and optionally, treesitter-objects)
should be installed the first time you use it.
Also Run `TSInstall go` to install the go parser if not installed yet.
`sed` is recommand to run this plugin.

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'ray-x/go.nvim'
Plug 'ray-x/guihua.lua' ; recommanded if need floating window support
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use 'ray-x/go.nvim'
use 'ray-x/guihua.lua' -- recommanded if need floating window support
```


Make sure the `$GOPATH/bin` path is added to your `$PATH` environment variable. To check this you can run

```bash
echo $PATH | grep "$GOPATH/bin"
```

If nothing shows up, you can add the following to your shell config file:

```bash
export PATH=$PATH:$GOPATH/bin
```

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

### GoTest in floating term

![gotest](https://user-images.githubusercontent.com/1681295/143160335-b8046ffa-82cd-4d84-af3e-3b0dbb4c609e.png)

Use:
```vim
:GoTermClose
```
To close the floating term.

## refactor gorename

gorename as an alternative to gopls rename as it supports rename across packages
Note: use with care
Command: GoRename

## code format

nvim-lsp support goimport by default.

```vim
autocmd BufWritePre (InsertLeave?) <buffer> lua vim.lsp.buf.formatting_sync(nil,500)
```

The plugin provides code format, by default is goline + gofumpt (stricter version of gofmt)

Use following code to format go code

```lua
require("go.format").gofmt()  -- gofmt only
require("go.format").goimport()  -- goimport + gofmt
```

### Format on save

To config format on save, add one of the following to your init.lua:

#### Run gofmt on save

```lua
-- Run gofmt on save
vim.api.nvim_exec([[ autocmd BufWritePre *.go :silent! lua require('go.format').gofmt() ]], false)

```

#### Run gofmt + goimport on save

```lua
-- Run gofmt + goimport on save
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

[GoFixPlurals Youtube video](https://www.youtube.com/watch?v=IP67Gkb5-qA)


```go
package foo

import "io"

func Foo() (io.Reader, error) { // the cursor on this line to add if err statement
}
```

![auto struct](https://github.com/ray-x/files/blob/master/img/go.nvim/fstruct.gif?raw=true)

## Textobject

Supported by treesitter. TS provided better parse result compared to regular expression.
See the example [treesitter config file](https://github.com/ray-x/go.nvim#text-object) on how to setup
textobjects. Also with treesitter-objects, you can move, swap the selected blocks of codes, which is fast and accurate.
`go.nvim` will load textobject with treesiteter, with default keybindings, if you what to set it up yourself, you can
set `textobject` to false.

## Go binaries install and update

The following go binaries are used in `go.nvim` (depends on your setup):

- gofumpt
- golines
- goimports
- gorename
- gomodifytags
- gotests
- iferr
- impl
- fillstruct
- fillswitch
- dlv
- ginkgo
- richgo

Normally if you run `GoFmt` and the configured binary (e.g. golines) was not installed, the plugin will install it for you. But the
first run of `GoFmt` may fail. It is recommended to run `GoInstallBinaries` to install all binaries before using the plugin.

| command                        | Description                                                                                                         |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| GoInstallBinary go_binary_name | use `go install go_binary_url@latest` to install tool, if installed will skip                                       |
| GoUpdateBinary go_binary_name  | use `go install go_binary_url@latest` Will force re-install if already installed, otherwise same as GoInstallBinary |
| GoInstallBinaries              | use `go install` to install all tools, skip the ones installed                                                      |
| GoUpdateBinaries               | use `go install` to update all tools to the latest version                                                          |

## Build and test

| command                                       | Description                                                              |
| --------------------------------------------- | ------------------------------------------------------------------------ |
| GoMake                                        | async make, use with other commands                                                                   |
| GoBuild                                       |                                                                          |
| GoGenerate                                    |                                                                          |
| GoRun  {args}                                       | e.g. GoRun equal to `go run .`; or `GoRun ./cmd` equal to `go run ./cmd, Additional args: -F run in floaterm`  |
| GoStop {job_id}                               | `stop the job started with GoRun`                                        |
| GoTest                                        | go test ./...                                                            |
| GoTest -c                                     | go test -c current_file_path                                             |
| GoTest -n                                     | test nearest, see GoTestFunc                                             |
| GoTest -f                                     | test current file, see GoTestFile                                        |
| GoTest -n 1                                   | -count=1 flag                                                            |
| GoTest -p                                     | test current package, see GoTestPkg                                      |
| GoTest -t yourtags                            | go test ./... -tags=yourtags, see notes                                  |
| GoTest package_path -t yourtags               | go test packagepath -tags=yourtags                                       |
| GoTest package_path -t yourtags other_args    | go test packagepath -tags=yourtags other_args                            |
| GoLint                                        | golangci-lint                                                            |
| GoGet {package_url}                           | go get package_url and restart gopls. Note1                              |
| GoVet                                         | go vet                                                                   |
| GoCoverage                                    | go test -coverprofile                                                    |
| GoCoverage -f coverage_file_name              | load coverage file                                                       |
| GoCoverage {flags}                            | -t : toggle, -r: remove signs, -R remove sings from all files, -m show metrics|
| GoTermClose                                   | `closes the floating term`                                               |

Note:
1. if package_url not provided, will check current line is a valid package url or not, if it is valid, will
fetch current url
2. tags: if ``//+build tags`` exist it will be added automatically

Show test coverage:

<img width="479" alt="GoTestCoverage" src="https://user-images.githubusercontent.com/1681295/130821038-fa2545c6-16f6-4448-9a0c-91a1ab333750.png">

Provided wrapper for gobulild/test etc with async make
Also suggest to use [vim-test](https://github.com/vim-test/vim-test), which can run running tests on different
granularities.

## Unit test with [gotests](https://github.com/cweill/gotests) and testify

Support table based unit test auto generate, parse current function/method name using treesitter

| command                  | Description                                             |
| ------------------------ | ------------------------------------------------------- |
| GoTestFunc               | run test for current func                               |
| GoTestFunc -s            | select the test function you want to run                |
| GoTestFunc -tags=yourtag | run test for current func with `-tags yourtag` option   |
| GoTestFile               | run test for current file                               |
| GoTestFile -tags=yourtag | run test for current folder with `-tags yourtag` option |
| GoTestPkg                | run test for current package/folder                     |
| GoTestPkg -tags=yourtag  | run test for current folder with `-tags yourtag` option |
| GoAddTest [-parallel]    | Add test for current func                               |
| GoAddExpTest [-parallel] | Add tests for exported funcs                            |
| GoAddAllTest [-parallel] | Add tests for all funcs                                 |

GoTestXXX Arguments

| arguments                  | Description                                           |
| ------------------------ | ------------------------------------------------------- |
| -v               | verbose mode                      |
| -c               | compile                           |
| -t               | tags                              |
| -b               | bench                             |
| -F               | floaterm mode                     |

Note: For GoTestXXX
You can add available arguments e.g. `GoTest -tags=integration ./internal/web -bench=. -count=1 -`

## GoCheat

Show cheat.sh for api in neovim new buffer. e.g. `GoCheat `sort

## GoDoc

Show go doc for api in neovim floating window. e.g. `GoDoc fmt.Println`

![Godoc](https://user-images.githubusercontent.com/1681295/133886804-cc110fae-6fbf-4218-9c22-07fc9d6a64d2.jpg)

If no argument provided, fallback to lsp.hover()

## GoPkgOutline

A symbole outline for all symbols (var, const, func, struct, interface etc) inside a package
You can still use navigator or sidebar plugins (e.g. vista, symbols-outline) to check outline within a file. But it
is more useful for go to check the symbols in a package, as those symbols are visuals inside package, also the
method can be defined in different source file.

Command format:
GoPkgOutline {options}
options:
-f: show in floatwing window (default side panel, both require quihua.lua)
-p package_name: the package you want to list. e.g. GoPkgOutline -p json; default package is current file's package
If guihua not installed fallback to loclist

<img width="902" alt="image" src="https://user-images.githubusercontent.com/1681295/175231905-82df4e4b-a508-4bb8-b878-9f0029643005.png">


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

| command               | Description                 |
| --------------------- | --------------------------- |
| GoFmt {opts}          | default: gofumpt            |
| GoImport              | default: goimport  |
| GoImport package_path | gopls add_import package    |

{opts} : ``-a`` format all buffers

## GoImpl

generate method stubs for implementing an interface

Usage:

````
:GoImpl {receiver} {interface}

Also you can put cursor on struct and run

```vim
:GoImpl {interface}
````

e.g:

```
:GoImpl f *File io.Reader
```
or simply put your cursor in a struct and do
```
:GoImpl io.Reader
```
or simply your cursor on a interface and specify a receiver type
```
:GoImpl MyType
```



## Debug

| command          | Description                                      |
| ---------------- | ------------------------------------------------ |
| GoDebug          | start debug session, Note 1                      |
| GoDebug -h       | show helps info                                  |
| GoDebug -c       | compile only                                     |
| GoDebug -t       | start debug session for go test file, Note 2     |
| GoDebug -R       | restart debug session                            |
| GoDebug -n       | start debug session for nearest go test function |
| GoDebug -p       | launch package test and start debug              |
| GoDebug -a       | attach to remote process                         |
| GoDebug -s       | stop debug session and unmap debug keymap        |
| GoDbgKeys        | show debug keymaps in a floating window (guihua) |
| GoBreakToggle    | GoDebug -b                                       |
| GoDbgStop        | Same as GoDebug -s                               |
| GoDbgContinue    | Continue debug session                           |
| BreakCondition   | conditional break                                |

Notes:
  1. Without any argument, will check if launch.json existed or not, if existed, using launch.json and popup input.
    If launch.json not existed, will start debug session for current file, if current file is package main will run
    main(), else will start debug package test
  2. with -t option, if current file is not test file, will switch to test file and run test for current function

## Switch between go and test file

| command          | Description                                             |
| ---------------- | ------------------------------------------------------- |
| GoAlt / GoAlt!   | open alternative go file (use ! to create if not exist) |
| GoAltS / GoAltS! | open alternative go file in split                       |
| GoAltV / GoAltV! | open alternative go file in vertical split              |

## Go Mock

go mock with mockgen is supported
| command          | Description                                           |
| ---------------- | ------------------------------------------------------- |
| GoMockGen   | default: generate mocks for current file |
 options:
   -s source mode(default)
   -i interface mode, provide interface name or put cursor on interface
   -p package name default: mocks
   -d destination directory, default: ./mocks


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
| command          | Description                                             |
| ---------------- | ------------------------------------------------------- |
| GoCmt            | Add comment                                             |

## GoModTidy

| command          | Description                                             |
| ---------------- | ------------------------------------------------------- |
| GoModInit   | run `go mod init` and restart gopls     |
| GoModTidy   | run `go mod tidy` and restart gopls     |
| GoModVendor | run `go mod vendor` and restart gopls   |

run `go mod tidy` and restart gopls

## LSP

Nvim-lsp is good enough for a gopher. If you looking for a better GUI. You can install
[navigator](https://github.com/ray-x/navigator.lua), or lspsaga, and lsp-utils etc.
The goal of go.nvim is more provide unique functions releated to gopls instead of a general lsp gui client.
The lsp config in go.nvim has a none default setup and contains some improvement and I would suggest you to use.

## LSP cmp support

The latest version enabled lsp snippets (and other setups) by default. In case you need flowing the setup from cmp
README.md, please use flowing command:

```lua
local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
require('go').setup({
  -- other setups ....
  lsp_cfg = {
    capabilities = capabilities,
    -- other setups
  },
})

```

## LSP CodeLens

Gopls supports code lens. To run gopls code lens action `GoCodeLenAct`
Note: codelens need to be enabled in gopls, check default config in

## LSP CodeActions

You can use native code action provided by lspconfig. If you installed guihua, you can also use a GUI version of
code action `GoCodeAction`

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

### Moving from vscode-go debug

Please check [Vscode Launch configurations](https://code.visualstudio.com/docs/editor/debugging#_launch-configurations)
for more info
go.nvim support launch debuger from vscode-go .vscode/launch.json configurations
If launch.json is valid, run `GoDebug` will launch from the launch.json configuration.

### Inlay hints

<img width="808" alt="image" src="https://user-images.githubusercontent.com/1681295/179863119-b7463072-015f-404c-b082-7bf6a01e3ab6.png">

### Command

* GoToggleInlay

#### Note:

Please use jsonls/null-ls check your launch.json is valid json file. Following syntax is not supported

- Trailing comma
- Comment

Here is a sample [launch.json](https://github.com/ray-x/go.nvim/blob/master/playground/sampleApp/.vscode/launch.json)

### Commands

| Command        | Description                                                                                     |
| -------------- | ----------------------------------------------------------------------------------------------- |
| GoDebug        | Start debugger, to debug test, run `GoDebug test`, to add addition args run `GoDebug arg1 arg2` |
| GoDebugConfig  | Open launch.json file                                                                           |
| GoBreakSave  | save all breakpoints to project file                                                              |
| GoBreakLoad  | load all breakpoints from project file                                                            |
| GoBreakToggle  | toggle break point                                                                              |
| BreakCondition | conditional break point                                                                         |
| ReplRun        | dap repl run_last                                                                               |
| ReplToggle     | dap repl toggle                                                                                 |

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
  go='go', -- go command, can be go[default] or go1.18beta1
  goimport='gopls', -- goimport command, can be gopls[default] or goimport
  fillstruct = 'gopls', -- can be nil (use fillstruct, slower) and gopls
  gofmt = 'gofumpt', --gofmt cmd,
  max_line_len = 128, -- max line length in golines format, Target maximum line length for golines
  tag_transform = false, -- can be transform option("snakecase", "camelcase", etc) check gomodifytags for details and more options
  gotests_template = "", -- sets gotests -template parameter (check gotests for details)
  gotests_template_dir = "", -- sets gotests -template_dir parameter (check gotests for details)
  comment_placeholder = '' ,  -- comment_placeholder your cool placeholder e.g. ﳑ       
  icons = {breakpoint = '🧘', currentpos = '🏃'},  -- setup to `false` to disable icons setup
  verbose = false,  -- output loginf in messages
  lsp_cfg = false, -- true: use non-default gopls setup specified in go/lsp.lua
                   -- false: do nothing
                   -- if lsp_cfg is a table, merge table with with non-default gopls setup in go/lsp.lua, e.g.
                   --   lsp_cfg = {settings={gopls={matcher='CaseInsensitive', ['local'] = 'your_local_module_path', gofumpt = true }}}
  lsp_gofumpt = false, -- true: set default gofmt in gopls format to gofumpt
  lsp_on_attach = nil, -- nil: use on_attach function defined in go/lsp.lua,
                       --      when lsp_cfg is true
                       -- if lsp_on_attach is a function: use this function as on_attach function for gopls
  lsp_keymaps = true, -- set to false to disable gopls/lsp keymap
  lsp_codelens = true, -- set to false to disable codelens, true by default, you can use a function
  -- function(bufnr)
  --    vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>F", "<cmd>lua vim.lsp.buf.formatting()<CR>", {noremap=true, silent=true})
  -- end
  -- to setup a table of codelens
  lsp_diag_hdlr = true, -- hook lsp diag handler
  -- virtual text setup
  lsp_diag_virtual_text = { space = 0, prefix = "" },
  lsp_diag_signs = true,
  lsp_diag_update_in_insert = false,
  lsp_document_formatting = true,
  -- set to true: use gopls to format
  -- false if you want to use other formatter tool(e.g. efm, nulls)
 lsp_inlay_hints = {
    enable = true,
    -- Only show inlay hints for the current line
    only_current_line = false,
    -- Event which triggers a refersh of the inlay hints.
    -- You can make this "CursorMoved" or "CursorMoved,CursorMovedI" but
    -- not that this may cause higher CPU usage.
    -- This option is only respected when only_current_line and
    -- autoSetHints both are true.
    only_current_line_autocmd = "CursorHold",
    -- whether to show variable name before type hints with the inlay hints or not
    -- default: false
    show_variable_name = true,
    -- prefix for parameter hints
    parameter_hints_prefix = " ",
    show_parameter_hints = true,
    -- prefix for all the other hints (type, chaining)
    other_hints_prefix = "=> ",
    -- whether to align to the lenght of the longest line in the file
    max_len_align = false,
    -- padding from the left if max_len_align is true
    max_len_align_padding = 1,
    -- whether to align to the extreme right or not
    right_align = false,
    -- padding from the right if right_align is true
    right_align_padding = 6,
    -- The color of the hints
    highlight = "Comment",
  },
  gopls_cmd = nil, -- if you need to specify gopls path and cmd, e.g {"/home/user/lsp/gopls", "-logfile","/var/log/gopls.log" }
  gopls_remote_auto = true, -- add -remote=auto to gopls
  dap_debug = true, -- set to false to disable dap
  dap_debug_keymap = true, -- true: use keymap for debugger defined in go/dap.lua
                           -- false: do not use keymap in go/dap.lua.  you must define your own.
                           -- windows: use visual studio keymap
  dap_debug_gui = true, -- set to true to enable dap gui, highly recommand
  dap_debug_vt = true, -- set to true to enable dap virtual text
  build_tags = "tag1,tag2", -- set default build tags
  textobjects = true, -- enable default text jobects through treesittter-text-objects
  test_runner = 'go', -- one of {`go`, `richgo`, `dlv`, `ginkgo`}
  verbose_tests = true, -- set to add verbose flag to tests
  run_in_floaterm = false, -- set to true to run in float window. :GoTermClose closes the floatterm
                           -- float term recommand if you use richgo/ginkgo with terminal color

  test_efm = false, -- errorfomat for quickfix, default mix mode, set to true will be efm only
  luasnip = false, -- enable included luasnip snippets. you can also disable while add lua/snips folder to luasnip load
  --  Do not enable this if you already added the path, that will duplicate the entries
})
```

You will need to add keybind yourself:
e.g

```lua
  vim.cmd("autocmd FileType go nmap <Leader><Leader>l GoLint")
  vim.cmd("autocmd FileType go nmap <Leader>gc :lua require('go.comment').gen()")

```

## Project setup

`go.nvim` allow you override your setup by a project file. Put `.gonvim/init.lua` in your root folder. It is a small lua
script and will be run durning go.setup(). The return value is used to override `go.nvim` setup. The sample project
setup. You can check the [youtube video here](https://www.youtube.com/watch?v=XrxSUp0E9Qw) on how to use this feature.

```lua
-- .gonvim/init.lua project config
vim.g.null_ls_disable = true

return {
  go = "go", -- set to go1.18beta1 if necessary
  goimport = "gopls", -- if set to 'gopls' will use gopls format, also goimport
  fillstruct = "gopls",
  gofmt = "gofumpt", -- if set to gopls will use gopls format
  max_line_len = 120
  null_ls_document_formatting_disable = true
}
```
This will override your global `go.nvim` setup


## Text object

I did not provide textobject support in the plugin. Please use treesitter textobject plugin.
My treesitter config:

```lua
  require "nvim-treesitter.configs".setup {
    incremental_selection = {
      enable = enable,
      keymaps = {
        -- mappings for incremental selection (visual mappings)
        init_selection = "gnn", -- maps in normal mode to init the node/scope selection
        node_incremental = "grn", -- increment to the upper named parent
        scope_incremental = "grc", -- increment to the upper scope (as defined in locals.scm)
        node_decremental = "grm" -- decrement to the previous node
      }
    },

    textobjects = {
      -- syntax-aware textobjects
      enable = enable,
      lsp_interop = {
        enable = enable,
        peek_definition_code = {
          ["DF"] = "@function.outer",
          ["DF"] = "@class.outer"
        }
      },
      keymaps = {
        ["iL"] = {
          -- you can define your own textobjects directly here
          go = "(function_definition) @function",
        },
        -- or you use the queries from supported languages with textobjects.scm
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["aC"] = "@class.outer",
        ["iC"] = "@class.inner",
        ["ac"] = "@conditional.outer",
        ["ic"] = "@conditional.inner",
        ["ae"] = "@block.outer",
        ["ie"] = "@block.inner",
        ["al"] = "@loop.outer",
        ["il"] = "@loop.inner",
        ["is"] = "@statement.inner",
        ["as"] = "@statement.outer",
        ["ad"] = "@comment.outer",
        ["am"] = "@call.outer",
        ["im"] = "@call.inner"
      },
      move = {
        enable = enable,
        set_jumps = true, -- whether to set jumps in the jumplist
        goto_next_start = {
          ["]m"] = "@function.outer",
          ["]]"] = "@class.outer"
        },
        goto_next_end = {
          ["]M"] = "@function.outer",
          ["]["] = "@class.outer"
        },
        goto_previous_start = {
          ["[m"] = "@function.outer",
          ["[["] = "@class.outer"
        },
        goto_previous_end = {
          ["[M"] = "@function.outer",
          ["[]"] = "@class.outer"
        }
      },
      select = {
        enable = enable,
        keymaps = {
          -- You can use the capture groups defined in textobjects.scm
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
          ["ac"] = "@class.outer",
          ["ic"] = "@class.inner",
          -- Or you can define your own textobjects like this
          ["iF"] = {
            python = "(function_definition) @function",
            cpp = "(function_definition) @function",
            c = "(function_definition) @function",
            java = "(method_declaration) @function",
            go = "(method_declaration) @function"
          }
        }
      },
      swap = {
        enable = enable,
        swap_next = {
          ["<leader>a"] = "@parameter.inner"
        },
        swap_previous = {
          ["<leader>A"] = "@parameter.inner"
        }
      }
    }
  }
```

## Nvim LSP setup

go.nvim provided a better non-default setup for gopls (includes debounce, staticcheck, diagnosticsDelay etc)

This gopls setup provided by go.nvim works perfectly fine for most of the cases. You can also install [navigator.lua](https://github.com/ray-x/navigator.lua) which can auto setup all lsp clients and provides a better GUI.

For diagnostic issue, you can use the default setup. There are also quite a few plugins that you can use to explore issues, e.g. [navigator.lua](https://github.com/ray-x/navigator.lua), [folke/lsp-trouble.nvim](https://github.com/folke/lsp-trouble.nvim). [Nvim-tree](https://github.com/kyazdani42/nvim-tree.lua) and [Bufferline](https://github.com/akinsho/nvim-bufferline.lua) also introduced lsp diagnostic hooks.

## Integrate with nvim-lsp-installer

(suggested by @mattbailey)

```lua
local path = require 'nvim-lsp-installer.core.path'
local install_root_dir = path.concat {vim.fn.stdpath 'data', 'lsp_servers'}

require('go').setup({
  gopls_cmd = {install_root_dir .. '/go/gopls'},
  fillstruct = 'gopls',
  dap_debug = true,
  dap_debug_gui = true
})
```

If you want to use gopls setup provided by go.nvim

```lua

-- setup your go.nvim
-- make sure lsp_cfg is disabled
require('go').setup{...}

local lsp_installer_servers = require'nvim-lsp-installer.servers'

local server_available, requested_server = lsp_installer_servers.get_server("gopls")
if server_available then
    requested_server:on_ready(function ()
        local opts = require'go.lsp'.config() -- config() return the go.nvim gopls setup
        requested_server:setup(opts)
    end)
    if not requested_server:is_installed() then
        -- Queue the server to be installed
        requested_server:install()
    end
end


```

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
Plug 'ray-x/guihua.lua' " float term, codeaction and codelens gui support

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

## Q & A:

Q: What is `Toggle gc annotation details`

A: This is a codelens message, please run codelens `GoCodeLenAct` and get more info
