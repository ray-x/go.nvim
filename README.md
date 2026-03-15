# go.nvim

A modern go neovim plugin based on treesitter, nvim-lsp, dap debugger and AI. It is written in Lua and async as much as
possible. PR & Suggestions are welcome.

The plugin covers most features required for a gopher.

**LSP & Navigation**

- gopls commands: fillstruct, organize imports, list modules/packages, gc_details, generate, change signature, etc.
- All GoToXxx (reference, implementation, definition, doc, peek code/doc, etc.) via gopls/lspconfig.
  Check [navigator.lua](https://github.com/ray-x/navigator.lua) for a floating UI experience
- Show interface implementations with virtual text
- Inlay hints (gopls 0.9+; enabled by default in 0.10+)
- CodeLens & CodeAction support

**Build, Test & Coverage**

- Async build/make/test with libuv job wrapper
- Test with `go test`, [gotestsum](https://github.com/gotestyourself/gotestsum), or [ginkgo](https://github.com/onsi/ginkgo) — including floaterm support
- Generate unit tests with [gotests](https://github.com/cweill/gotests) (table-driven, testify)
- Test coverage: run coverage, display signs, and show function metrics
- Smart build-tag detection for debug/test runs (e.g. `//go:build integration`)

**Code Generation & Refactoring**

- [`GoIfErr`](doc/usage.md#auto-fill), [`GoFillStruct`](doc/usage.md#auto-fill), [`GoFillSwitch`](doc/usage.md#auto-fill), [`GoFixPlurals`](doc/usage.md#auto-fill), [`GoGenReturn`](doc/usage.md#generate-return-value) — powered by treesitter/go AST
- [`GoImpl`](doc/usage.md#goimpl) — generate interface method stubs
- [`GoEnum`](doc/usage.md#goenum) — generate enum helpers
- [`GoJson2Struct`](doc/usage.md#jsonyaml-to-go-struct) — convert JSON/YAML to Go structs
- [`GoMockGen`](doc/usage.md#go-mock) — generate mocks with mockgen
- [`GoNew`](doc/usage.md#gonew) — create files/projects from templates (including `gonew`)
- Struct tag management with [`gomodifytags`](doc/usage.md#modifytags)

**Formatting & Linting**

- Format via LSP (gopls) or CLI (`gofumpt`, `goimports`, `golines`)
- Lint with golangci-lint (v2) — LSP diagnostics or async background checks

**Debugging**

- Dlv debug with [nvim-dap](https://github.com/mfussenegger/nvim-dap) and [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) — zero-config Go adapter included
- Load VSCode `launch.json` configurations

**AI-Powered**

- [`GoAI`](doc/usage.md#goai) — natural-language command dispatcher (translates natural-language into go.nvim commands via Copilot/OpenAI).
- [`GoCmtAI`](doc/usage.md#comments-and-doc) — generate doc comments with AI for the declaration at cursor
- [`GoDocAI`](doc/usage.md#ai-documentation) — AI-powered documentation: find symbols by vague name and generate rich docs from source
- [`GoCodeReview`](doc/usage.md#ai-code-review) — AI code review for files, selections, or diffs; results populate the quickfix list
- [`GoAIChat`](doc/usage.md#ai-chat) — ask questions about Go code with AI; auto-includes function context and LSP references

**Documentation & Navigation**

- [`GoDoc`](doc/usage.md#godoc) / [`GoDocBrowser`](doc/usage.md#godocbrowser) — view docs in a float or browser
- [`GoCheat`](doc/usage.md#gocheat) — cheat sheets from [cheat.sh](https://cheat.sh/)
- [`GoAlt`](doc/usage.md#switch-between-go-and-test-file) / [`GoAltV`](doc/usage.md#switch-between-go-and-test-file) / [`GoAltS`](doc/usage.md#switch-between-go-and-test-file) — switch between test and implementation files
- [`GoPkgOutline`](doc/usage.md#gopkgoutline) / [`GoPkgSymbols`](doc/usage.md#gopkgsymbols) — package-level symbol outlines

**Comments & Docs**

- Auto-generate doc comments for packages, functions, structs, and interfaces (suppresses golint warnings)

**Module & Workspace**

- [`GoModTidy`](doc/usage.md#gomod-commands), [`GoModVendor`](doc/usage.md#gomod-commands), [`GoGet`](doc/usage.md#build-and-test), [`GoWork`](doc/usage.md#build-and-test), etc.
- [`Gomvp`](doc/usage.md#rename-modules) — rename/move packages
- [`GoVulnCheck`](doc/usage.md#govulncheck) — run govulncheck for vulnerability scanning

**Syntax & Snippets**

- Treesitter-based syntax highlighting and textobjects
- Treesitter highlight injection for SQL, JSON, `go template`, and `gohtmltmpl`
- Feature-rich LuaSnip snippets included

**Project & Configuration**

- Per-project setup via `.gonvim/init.lua` or `launch.json`
- Async jobs with libuv throughout

## Installation

Use your favorite package manager to install. The dependency `treesitter` **main** branch (and optionally, treesitter-objects) should be
installed the first time you use it. Also Run `TSInstall go` to install the go parser if not installed yet. `sed` is
recommended to run this plugin.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "ray-x/go.nvim",
  dependencies = {  -- optional packages
    "ray-x/guihua.lua",
    "neovim/nvim-lspconfig",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = function()

    require("go").setup(opts)
    local format_sync_grp = vim.api.nvim_create_augroup("GoFormat", {})
    vim.api.nvim_create_autocmd("BufWritePre", {
      pattern = "*.go",
      callback = function()
      require('go.format').goimports()
      end,
      group = format_sync_grp,
    })
    return {
      -- lsp_keymaps = false,
      -- other options
    }
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

Add format in your vimrc (or lazy.nvim config function).

```lua
lua <<EOF
local format_sync_grp = vim.api.nvim_create_augroup("GoFormat", {})
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
   require('go.format').goimports()
  end,
  group = format_sync_grp,
})

EOF
```

To startup/setup the plugin

```lua
require('go').setup()
```

Refer to [advance-setup](doc/advanced-setup.md#installation) on more installation info.

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

## Usage & Demo

For detailed command usage, demos, screenshots, and examples, see the **[Usage Guide](doc/usage.md)**.

Quick links: [Code Format](doc/usage.md#code-format) | [Build & Test](doc/usage.md#build-and-test) |
[Debug](doc/usage.md#debug) | [AI Code Review](doc/usage.md#ai-code-review) |
[AI Chat](doc/usage.md#ai-chat) | [GoImpl](doc/usage.md#goimpl) |
[GoDoc](doc/usage.md#godoc) | [Tags](doc/usage.md#modifytags) |
[Mock](doc/usage.md#go-mock) | [All commands](doc/usage.md)

## Commands

Check [commands.lua](https://github.com/ray-x/go.nvim/blob/master/lua/go/commands.lua) on all the commands provided

## Gopls commands

Check [gopls.lua](https://github.com/ray-x/go.nvim/blob/master/lua/go/gopls.lua) on all the gopls commands provided,
some of them are not exposed to user, but you can still use it in your lua setup.

- list_imports
- add_import
- list_packages
- tidy
- change_signature
- ...

## Configuration

For the full default configuration with all options, see the
**[Default Configuration](https://github.com/ray-x/go.nvim/blob/master/doc/advanced-setup.md#default-configuration)**
in the Advanced Setup guide.

Minimal setup:

```lua
require('go').setup()
```

To enable AI features:

```lua
require('go').setup({
  ai = {
    enable = true,
    provider = 'copilot', -- or 'openai'
  },
})
```

To use gopls setup provided by go.nvim:

```lua
require('go').setup({
  lsp_cfg = true,
})
```

## Project setup

`go.nvim` allow you override your setup by a project file. Put `.gonvim/init.lua` in your root folder. It is a small lua
script and will be run durning go.setup(). The return value is used to override `go.nvim` setup. The sample project
setup. You can check the [youtube video here](https://www.youtube.com/watch?v=XrxSUp0E9Qw) on how to use this feature.

```lua
-- .gonvim/init.lua project config

return {
  go = "go", -- set to go1.18beta1 if necessary
  goimports = "gopls", -- if set to 'gopls' will use gopls format, also goimports
  gofmt = "gofumpt", -- if set to gopls will use gopls format
  null_ls_document_formatting_disable = true
}
```

This will override your global `go.nvim` setup

## Advanced Setup

For LSP/gopls configuration, text objects, LuaSnip snippets, mason-lspconfig integration, null-ls,
treesitter highlighting, and sample vimrc, see the **[Advanced Setup Guide](doc/advanced-setup.md)**.

## Other plugins that you may like

- [goplay](https://github.com/jeniasaigak/goplay.nvim)
- [a different way to highlight coverage results](https://github.com/rafaelsq/nvim-goc.lua)

## Running plugin test / github action locally

If you'd like to commit to this project, and would like to run unit tests, you can run the following command:

```bash
XDG_CONFIG_HOME=/tmp/nvim-test make localtestfile
```

this will run the following commands in headless mode

```bash
make setup # install plenary etc
nvim --headless --noplugin -u lua/tests/init.vim -c "PlenaryBustedFile lua/tests/go_fixplurals_spec.lua"
```

This runs test spec file `lua/tests/go_fixplurals_spec.lua` in headless mode.

Please check Makefile for more details

## Q & A

Q: What is `Toggle gc annotation details`

A: This is a codelens message, please run codelens `GoCodeLenAct` and get more info
