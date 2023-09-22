#a go.nvim

A modern go neovim plugin based on treesitter, nvim-lsp and dap debugger. It is written in Lua and async as much as possible.
PR & Suggestions welcome.
The plugin covers most features required for a gopher.

- Perproject setup. Allows you setup plugin behavior per project based on project files(launch.json, .gonvim)
- Async jobs with libuv
- Syntax highlight & Texobject: Native treesitter support is faster and more accurate. All you need is a theme support treesitter, try
  [aurora](https://github.com/ray-x/aurora), [starry.nvim](https://github.com/ray-x/starry.nvim). Also, there are quite a few listed in [awesome-neovim](https://github.com/rockerBOO/awesome-neovim)
- All the GoToXxx (E.g reference, implementation, definition, goto doc, peek code/doc etc) You need lspconfig setup. There are lots of posts on how to
  set it up. You can also check my [navigator](https://github.com/ray-x/navigator.lua) gopls setup [lspconfig.lua](https://github.com/ray-x/navigator.lua/blob/master/lua/navigator/lspclient/clients.lua)
- gopls commands: e.g. fillstruct, organize imports, list modules, list packages, gc_details, generate etc.
- Runtime lint/vet/compile: Supported by lsp (once you setup up your lsp client), GoLint with golangci-lint also supported
- Build/Make/Test: Go.nvim provides supports for these by an async job wrapper.
- Test coverage: run test coverage and show coverage sign and function metrics
- Dlv Debug: with [nvim-dap](https://github.com/mfussenegger/nvim-dap) and [Dap UI](https://github.com/rcarriga/nvim-dap-ui). Go adapter included, zero config for your debug setup.
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
- Code refactor made easy: GoFixPlural, FixStruct, FixSwitch, Add comment, IfErr, ModTidy, GoGet, extract function/block with codeactions... Most of the tools are built on top of
  treesitter AST or go AST. Fast and accurate.
- GoCheat get go cheatsheet from [cheat.sh](https://cheat.sh/).
- Smart build tag detection when debug/run tests (e.g. `//go:build integration`)
- Generate mocks with mockgen
- Inlay hints: gopls (version 0.9.x or greater) inlay hints; version 0.10.x inlay hints are enabled by default.
- luasnip: go.nvim included a feature rich luasnips you definitally need to try.
- Treesitter highlight injection: go.nvim included a treesitter highlight injection for SQL and json.

## Installation

Use your favorite package manager to install. The dependency `treesitter` (and optionally, treesitter-objects)
should be installed the first time you use it.
Also Run `TSInstall go` to install the go parser if not installed yet.
`sed` is recommend to run this plugin.

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'neovim/nvim-lspconfig'
Plug 'ray-x/go.nvim'
Plug 'ray-x/guihua.lua' ; recommended if need floating window support
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use 'ray-x/go.nvim'
use 'ray-x/guihua.lua' -- recommended if need floating window support
use 'neovim/nvim-lspconfig'
use 'nvim-treesitter/nvim-treesitter'
```

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "ray-x/go.nvim",
  dependencies = {  -- optional packages
    "ray-x/guihua.lua",
    "neovim/nvim-lspconfig",
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require("go").setup()
  end,
  event = {"CmdlineEnter"},
  ft = {"go", 'gomod'},
  build = ':lua require("go.install").update_all_sync()' -- if you need to install/update all binaries
}

```

The go.nvim load speed is fast and you can enable it by default
<img width="479" alt="image" src="https://user-images.githubusercontent.com/1681295/218074895-5182c791-8649-46ad-b18e-8eb1af8c0ffa.png">

Make sure the `$GOPATH/bin` path is added to your `$PATH` environment variable. To check this you can run

```bash
echo $PATH | grep "$GOPATH/bin"
```

If nothing shows up, you can add the following to your shell config file:

```bash
export PATH=$PATH:$GOPATH/bin
```

Add format in your vimrc.

```lua
lua <<EOF
local format_sync_grp = vim.api.nvim_create_augroup("GoFormat", {})
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
   require('go.format').goimport()
  end,
  group = format_sync_grp,
})

EOF
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

### SQL/JSON Highlight injection

<img width="718" alt="image" src="https://user-images.githubusercontent.com/1681295/227125827-538c5f3f-298d-4ae1-8762-42dfb92e79f3.png">

### Inlay hints

<img width="491" alt="image" src="https://user-images.githubusercontent.com/1681295/240350775-a1d92c06-66d2-4e4b-9225-538cf1a201b2.png">

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

local format_sync_grp = vim.api.nvim_create_augroup("GoFormat", {})
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
   require('go.format').gofmt()
  end,
  group = format_sync_grp,
})


```

#### Run gofmt + goimport on save

```lua
-- Run gofmt + goimport on save

local format_sync_grp = vim.api.nvim_create_augroup("GoImport", {})
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
   require('go.format').goimport()
  end,
  group = format_sync_grp,
})


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
- gotestsum
- govulncheck
- goenum

If you run `GoFmt` and the configured binary (e.g. golines) was not installed, the plugin will install it for you. But the
first run of `GoFmt` may fail. Recommended to run `GoInstallBinaries` to install all binaries before using the plugin.

| command                        | Description                                                                                                                |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| GoInstallBinary go_binary_name | use `go install go_binary_url@latest` to install tool, if installed will skip                                              |
| GoUpdateBinary go_binary_name  | use `go install go_binary_url@latest` Will force re-install/update if already installed, otherwise same as GoInstallBinary |
| GoInstallBinaries              | use `go install` to install all tools, skip the ones installed                                                             |
| GoUpdateBinaries               | use `go install` to update all tools to the latest version                                                                 |

## Build and test

| command                                    | Description                                                                                                   |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| GoMake                                     | async make, use with other commands                                                                           |
| GoBuild args                               | go build args (-g: enable debug, %: expand to current file, %:h expand to current package)                    |
| GoGenerate                                 |                                                                                                               |
| GoRun {args}                               | e.g. GoRun equal to `go run .`; or `GoRun ./cmd` equal to `go run ./cmd, Additional args: -F run in floaterm` |
| GoStop {job_id}                            | `stop the job started with GoRun`                                                                             |
| GoTest                                     | go test ./...                                                                                                 |
| GoTestSum {pkgname} {gotestsum arguments}  | run gotestsum and show result in side panel                                                                   |
| GoTestSum -w                               | run gotestsum in watch mode                                                                                   |
| GoTest -v                                  | go test -v current_file_path                                                                                  |
| GoTest -c                                  | go test -c current_file_path                                                                                  |
| GoTest -n                                  | test nearest, see GoTestFunc                                                                                  |
| GoTest -f                                  | test current file, see GoTestFile                                                                             |
| GoTest -n 1                                | -count=1 flag                                                                                                 |
| GoTest -p                                  | test current package, see GoTestPkg                                                                           |
| GoTest -t yourtags                         | go test ./... -tags=yourtags, see notes                                                                       |
| GoTest -a your_args                        | go test ./... -args=yourargs, see notes                                                                       |
| GoTest package_path -t yourtags            | go test packagepath -tags=yourtags                                                                            |
| GoTest package_path -t yourtags other_args | go test packagepath -tags=yourtags other_args                                                                 |
| GoLint                                     | golangci-lint                                                                                                 |
| GoGet {package_url}                        | go get package_url and restart gopls. Note1                                                                   |
| GoVet                                      | go vet                                                                                                        |
| GoCoverage                                 | go test -coverprofile                                                                                         |
| GoCoverage -p                              | go test -coverprofile (only tests package for current buffer)                                                 |
| GoCoverage -f coverage_file_name           | load coverage file                                                                                            |
| GoCoverage {flags}                         | -t : toggle, -r: remove signs, -R remove sings from all files, -m show metrics                                |
| GoCoverage {flags} {go test flags}         | e.g: GoCoverage -p -coverpkg 'yourpackagename'                                                                |
| GoTermClose                                | `closes the floating term`                                                                                    |

Note:

1. if package_url not provided, will check current line is a valid package url or not, if it is valid, will
   fetch current url
2. tags: if `//+build tags` exist it will be added automatically
3. args: if multiple args is provided, you need toconcatenate it with '\ ', e.g. GoTest -args yourtags\ other_args
4. % will expand to current file path, e.g. GoBuild %

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

| arguments | Description   |
| --------- | ------------- |
| -v        | verbose mode  |
| -c        | compile       |
| -C        | coverprofile  |
| -n        | count         |
| -t        | tags          |
| -f        | fuzz          |
| -b        | bench         |
| -m        | metric        |
| -s        | select        |
| -p        | package       |
| -F        | floaterm mode |
| -a        | args          |

Note: For GoTestXXX

You can add available arguments with long name or character flag e.g. `GoTest -tags=integration ./internal/web -b=. -count=1 -`

You can also add other unmapped arguments after the `-a` or `-args` flag `GoTest -a mock=true`

## GoCheat

Show [cheat.sh](https://github.com/chubin/cheat.sh) for api in neovim new buffer. e.g. `GoCheat sort`

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

Options:
-transform/-t: transform the tag
-add-options/-a: add options to the tag

## GoFmt

nvim-lsp support goimport by default. The plugin provided a new formatter, goline + gofumpt (stricter version of
gofmt)

| command               | Description              |
| --------------------- | ------------------------ |
| GoFmt {opts}          | default: gofumpt         |
| GoImport              | default: goimport        |
| GoImport package_path | gopls add_import package |

{opts} : `-a` format all buffers

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

| command            | Description                                      |
| ------------------ | ------------------------------------------------ |
| GoDebug            | start debug session, Note 1                      |
| GoDebug -h         | show helps info                                  |
| GoDebug -c         | compile only                                     |
| GoDebug -t         | start debug session for go test file, Note 2     |
| GoDebug -R         | restart debug session                            |
| GoDebug -n         | start debug session for nearest go test function |
| GoDebug -p         | launch package test and start debug              |
| GoDebug -e program | dap exec program                                 |
| GoDebug -a         | attach to remote process                         |
| GoDebug -s         | stop debug session and unmap debug keymap        |
| GoDebug -A args    | debug session with args                          |
| GoDbgKeys          | show debug keymaps in a floating window (guihua) |
| GoBreakToggle      | GoDebug -b                                       |
| GoDbgStop          | Same as GoDebug -s                               |
| GoDbgContinue      | Continue debug session                           |
| BreakCondition     | conditional break                                |

Notes:

1. Without any argument, will check if launch.json existed or not, if existed, using launch.json and popup input.
   If launch.json not existed, will start debug session for current file, if current file is package main will run
   main(), else will start debug package test
2. with -t option, if current file is not test file, will switch to test file and run test for current function
3. If cursor inside scope of a test function, will debug current test function, if cursor inside a test file, will debug
   current test file

## Switch between go and test file

| command          | Description                                             |
| ---------------- | ------------------------------------------------------- |
| GoAlt / GoAlt!   | open alternative go file (use ! to create if not exist) |
| GoAltS / GoAltS! | open alternative go file in split                       |
| GoAltV / GoAltV! | open alternative go file in vertical split              |

## Go Mock

go mock with mockgen is supported
| command | Description |
| ---------------- | ------------------------------------------------------- |
| GoMockGen | default: generate mocks for current file |
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

| command | Description |
| ------- | ----------- |
| GoCmt   | Add comment |

## GoModTidy

| command     | Description                           |
| ----------- | ------------------------------------- |
| GoModInit   | run `go mod init` and restart gopls   |
| GoModTidy   | run `go mod tidy` and restart gopls   |
| GoModVendor | run `go mod vendor` and restart gopls |

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
local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())
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

Setup(adapter) for go included. Need Dap and Dap UI plugin
[nvim-dap](https://github.com/mfussenegger/nvim-dap)
[nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui)
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

- GoToggleInlay

#### Note:

Please use jsonls/null-ls check your launch.json is valid json file. Following syntax is not supported

- Trailing comma
- Comment

Here is a sample [launch.json](https://github.com/ray-x/go.nvim/blob/master/playground/sampleApp/.vscode/launch.json)

### Json to Go struct

- ["x]GoJson2Struct!
  Visual select the json and run `GoJson2Struct youStructName`
  -bang will put result to register `a`
  if ["x] specified, will put get json from clipboard

### Load Env file

- GoEnv {filename}
  By default load .env file in current directory, if you want to load other file, use {filename} option

### Generate return value

- GoGenReturn

create return value for current function
e.g. if we have

```go
func Foo() (int, error) {
  return 1, nil
}
```

and in your code you cursor on Foo

```go
Foo()
```

will generate

```go
i, err := Foo()
if err != nil {
  return
}
```

### Rename modules

- Gomvp
  Rename module name in under cursor
  e.g.
  Gomvp
  Gomvp old_mod_name
  Gomvp old_mod_name new_mod_name

### govulncheck

- GoVulnCheck {arguments}
  Run govulncheck on current project

### goenum

- Goenum {arguments}
  Run goenum on current project

### gonew

- GoNew {filename}
  Create new go file. It will use template file. e.g. `GoNew ./pkg/string.go` will create string.go with template file

### ginkgo

- Ginkgo {args}

| Arg       | Description |
| --------- | ----------- |
| run       |             |
| watch     |             |
| build     |             |
| bootstrap |             |
| labels    |             |
| outline   |             |

### Debug Commands

| Command        | Description                                                                                     |
| -------------- | ----------------------------------------------------------------------------------------------- |
| GoDebug        | Start debugger, to debug test, run `GoDebug test`, to add addition args run `GoDebug arg1 arg2` |
| GoDebugConfig  | Open launch.json file                                                                           |
| GoBreakSave    | save all breakpoints to project file                                                            |
| GoBreakLoad    | load all breakpoints from project file                                                          |
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

Check [commands.lua](https://github.com/ray-x/go.nvim/blob/master/lua/go/commands.lua) on all the commands provided

## configuration

Configure from lua suggested, The default setup:

```lua
require('go').setup({

  disable_defaults = false, -- true|false when true set false to all boolean settings and replace all table
  -- settings with {}
  go='go', -- go command, can be go[default] or go1.18beta1
  goimport='gopls', -- goimport command, can be gopls[default] or goimport
  fillstruct = 'gopls', -- can be nil (use fillstruct, slower) and gopls
  gofmt = 'gofumpt', --gofmt cmd,
  max_line_len = 128, -- max line length in golines format, Target maximum line length for golines
  tag_transform = false, -- can be transform option("snakecase", "camelcase", etc) check gomodifytags for details and more options
  tag_options = 'json=omitempty', -- sets options sent to gomodifytags, i.e., json=omitempty
  gotests_template = "", -- sets gotests -template parameter (check gotests for details)
  gotests_template_dir = "", -- sets gotests -template_dir parameter (check gotests for details)
  comment_placeholder = '' ,  -- comment_placeholder your cool placeholder e.g. 󰟓       
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
  diagnostic = {  -- set diagnostic to false to disable vim.diagnostic setup
    hdlr = true, -- hook lsp diag handler
    underline = true,
    -- virtual text setup
    virtual_text = { space = 0, prefix = '■' },
    signs = true,
    update_in_insert = false,
  },
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
    parameter_hints_prefix = "󰊕 ",
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
  gocoverage_sign = "█",
  sign_priority = 5, -- change to a higher number to override other signs
  dap_debug = true, -- set to false to disable dap
  dap_debug_keymap = true, -- true: use keymap for debugger defined in go/dap.lua
                           -- false: do not use keymap in go/dap.lua.  you must define your own.
                           -- windows: use visual studio keymap
  dap_debug_gui = {}, -- bool|table put your dap-ui setup here set to false to disable
  dap_debug_vt = { enabled_commands = true, all_frames = true }, -- bool|table put your dap-virtual-text setup here set to false to disable

  dap_port = 38697, -- can be set to a number, if set to -1 go.nvim will pickup a random port
  dap_timeout = 15, --  see dap option initialize_timeout_sec = 15,
  dap_retries = 20, -- see dap option max_retries
  build_tags = "tag1,tag2", -- set default build tags
  textobjects = true, -- enable default text jobects through treesittter-text-objects
  test_runner = 'go', -- one of {`go`, `richgo`, `dlv`, `ginkgo`, `gotestsum`}
  verbose_tests = true, -- set to add verbose flag to tests deprecated, see '-v' option
  run_in_floaterm = false, -- set to true to run in float window. :GoTermClose closes the floatterm
                           -- float term recommend if you use richgo/ginkgo with terminal color

  floaterm = {   -- position
    posititon = 'auto', -- one of {`top`, `bottom`, `left`, `right`, `center`, `auto`}
    width = 0.45, -- width of float window if not auto
    height = 0.98, -- height of float window if not auto
  },
  trouble = false, -- true: use trouble to open quickfix
  test_efm = false, -- errorfomat for quickfix, default mix mode, set to true will be efm only
  luasnip = false, -- enable included luasnip snippets. you can also disable while add lua/snips folder to luasnip load
  --  Do not enable this if you already added the path, that will duplicate the entries
  on_jobstart = function(cmd) _=cmd end, -- callback for stdout
  on_stdout = function(err, data) _, _ = err, data end, -- callback when job started
  on_stderr = function(err, data)  _, _ = err, data  end, -- callback for stderr
  on_exit = function(code, signal, output)  _, _, _ = code, signal, output  end, -- callback for jobexit, output : string
  iferr_vertical_shift = 4 -- defines where the cursor will end up vertically from the begining of if err statement 
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

## LuaSnip supports

go.nvim provides a better snippet support for go.
Please check [snippets for all languages](https://github.com/ray-x/go.nvim/blob/master/lua/snips/all.lua)
and [snippets for go](https://github.com/ray-x/go.nvim/blob/master/lua/snips/go.lua)

For a video demo, please check this:
[go.nvim new features work through](https://www.youtube.com/watch?v=tsLnEfYTgcM)

If you are not familiar with luasnip, please checkout [LuaSnip Tutorial](https://www.youtube.com/watch?v=ub0REXjhpmk) and [TJ's Introduction to LuaSnip](https://www.youtube.com/watch?v=Dn800rlPIho)

## Nvim LSP setup

go.nvim provided a better non-default setup for gopls (includes debounce, staticcheck, diagnosticsDelay etc)

This gopls setup provided by go.nvim works perfectly fine for most of the cases. You can also install [navigator.lua](https://github.com/ray-x/navigator.lua) which can auto setup all lsp clients and provides a better GUI.

For diagnostic issue, you can use the default setup. There are also quite a few plugins that you can use to explore issues, e.g. [navigator.lua](https://github.com/ray-x/navigator.lua), [folke/lsp-trouble.nvim](https://github.com/folke/lsp-trouble.nvim). [Nvim-tree](https://github.com/kyazdani42/nvim-tree.lua) and [Bufferline](https://github.com/akinsho/nvim-bufferline.lua) also introduced lsp diagnostic hooks.

## Integrate with mason-lspconfig

```lua
require("mason").setup()
require("mason-lspconfig").setup()
require('lspconfig').gopls.setup({
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
require("mason").setup()
require("mason-lspconfig").setup()
require('go').setup{
  lsp_cfg = false
  -- other setups...
}
local cfg = require'go.lsp'.config() -- config() return the go.nvim gopls setup

require('lspconfig').gopls.setup(cfg)

```

## Integrate null-ls

### The plugin provides:

- `gotest` LSP diagnostic source for null-ls
- `golangci_lint` A async version of golangci-lint null-ls lint
- `gotest_action` LSP test code action for null-ls

Gotest allow you run `go test <package>` when you save your go file and add diagnostics to nvim

```lua
local null_ls = require("null-ls")
local sources = {
  null_ls.builtins.diagnostics.revive,
  null_ls.builtins.formatting.golines.with({
    extra_args = {
      "--max-len=180",
      "--base-formatter=gofumpt",
    },
  })
}
-- for go.nvim
local gotest = require("go.null_ls").gotest()
local gotest_codeaction = require("go.null_ls").gotest_action()
local golangci_lint = require("go.null_ls").golangci_lint()
table.insert(sources, gotest)
table.insert(sources, golangci_lint)
table.insert(sources, gotest_codeaction)
null_ls.setup({ sources = sources, debounce = 1000, default_timeout = 5000 })

-- alternatively
null_ls.register(gotest)

```

You will see the failed tests flagged
![null-ls
go.nvim](https://user-images.githubusercontent.com/1681295/212526174-4fa98a63-c90a-4a54-9340-27de98ecf17c.jpg)

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

## Other plugins that you may like

- [goplay](https://github.com/jeniasaigak/goplay.nvim)
- [a different way to highlight coverage results](https://github.com/rafaelsq/nvim-goc.lua)

## Q & A:

Q: What is `Toggle gc annotation details`

A: This is a codelens message, please run codelens `GoCodeLenAct` and get more info
