# go.nvim

A modern go neovim plugin based on treesitter and nvim-lsp. It is written in Lua and async as much as possible.
PR & Suggestions welcome.
The plugin covers most features required for a gopher.

- Async jobs
- Syntex highlight & Texobject: Native treesitter support is faster and more accurate. All you need is a theme support treesitter, try
  [aurora](https://github.com/ray-x/aurora). Also, there are quite a few listed in [awesome-neovim](https://github.com/rockerBOO/awesome-neovim)
- All the GoToXxx (E.g reference, implementation, definition, goto doc, peek code/doc etc) You need lspconfig setup. There are lots of posts on how to
  set it up. You can also check my [navigator](https://github.com/ray-x/navigator.lua) gopls setup [lspconfig.lua](https://github.com/ray-x/navigator.lua/blob/master/lua/navigator/lspclient/clients.lua)
- Runtime lint/vet/compile: Supported by lsp (once you setup up your lsp client), GoLint with golangci-lint also supported
- Build/Make/Test: Go.nvim provides supports for these by an async job wrapper.
- Dlv Debug: with Dap UI
- Unit test: Support [gotests](https://github.com/cweill/gotests)
- tag modify: Supports gomodifytags
- Code format: Supports LSP format and GoFmt
- Comments: Add autodocument for your package/function/struct/interface. This feature is unique and can help you suppress golint
  errors...

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

## Auto fill struct
Note: auto fill struct also supported by gopls lsp-action

![auto struct](https://github.com/ray-x/files/blob/master/img/go.nvim/fstruct.gif?raw=true)

## Textobject

Supported by treesitter. TS provided better parse result compared to regular expression.
Check [my treesitter config file](https://github.com/ray-x/dotfiles/blob/master/nvim/lua/modules/lang/treesitter.lua) on how to setup
textobjects. Also with treesitter-objects, you can move, swap the selected blocks of codes, which is fast and accurate.

## Build and test

Provided wrapper for gobulild/test etc with async make
Also suggest to use [vim-test](https://github.com/vim-test/vim-test), which can run running tests on different
granularities.

## Unit test with [gotests](https://github.com/cweill/gotests) and testify

Support table based unit test auto generate, parse current function/method name using treesitter

## Modifytags

Modify struct tags by [`gomodifytags`](https://github.com/fatih/gomodifytags) and treesitter

## GoFmt

nvim-lsp support goimport by default. The plugin provided a new formatter, goline + gofumports (stricter version of
goimport)

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

## Lint

Supported by LSP, also GoLint command (by calling golangcl-lint) if you need background golangci-lint check, you can
configure it with ALE

## Debug with dlv
Setup for Debug provided. Need Dap and Dap UI plugin
![dap](https://user-images.githubusercontent.com/1681295/125160289-743ba080-e1bf-11eb-804f-6a6d227ec33b.jpg)
GDB style key mapping is used
### Keymaps
| Command      | Description |
| ----------- | ----------- |
| c     | continue |
| n     | next |
| s     | step |
| o     | stepout |
| S     | cap S: stop debug |
| u     | up |
| D     | cap D: down |
| C     | cap C: run to cursor |
| b     | toggle breakpoint |
| P     | cap P: pause |
| p     | print, hover value (also in visual mode) |

### Commands
| Command      | Description |
| ----------- | ----------- |
| Debug      | Start debugger, to debug test, run `Debug test`, to add addition args run `Debug arg1 arg2`       |
| BreakToggle  | toggle break point        |
| BreakCondition  | conditional break point        |
| ReplRun  | dap repl run_last |
| ReplToggle  | dap repl toggle |


### Required DAP plugins
The plugin will setup debugger. But you need to install

* dap
    * 'mfussenegger/nvim-dap'
* dap ui (optional)
    * 'rcarriga/nvim-dap-ui'

* dap virtual text (optional)
    * 'theHamsta/nvim-dap-virtual-text'

Also you can check telescope dap extension : nvim-telescope/telescope-dap.nvim

Sample vimrc
```viml
 Plug 'mfussenegger/nvim-dap'
 Plug 'rcarriga/nvim-dap-ui'
 Plug 'theHamsta/nvim-dap-virtual-text'
 " Plug 'nvim-telescope/telescope-dap.nvim'

```


## Commands
Check [go.lua](https://github.com/ray-x/go.nvim/blob/master/lua/go.lua) on all the commands provided

## configuration

Configure from lua suggested:

```lua
require('go').setup(cfg = {
  goimport='gofumports', -- goimport command
  gofmt = 'gofumpt', --gofmt cmd,
  max_line_len = 120, -- max line length in goline format
  tag_transform = false, -- tag_transfer  check gomodifytags for details
  test_template = '', -- default to testify if not set; g:go_nvim_tests_template  check gotests for details
  test_template_dir = '', -- default to nil if not set; g:go_nvim_tests_template_dir  check gotests for details
  comment_placeholder = '' ,  -- comment_placeholder your cool placeholder e.g. ﳑ       
  verbose = false,  -- output loginf in messages
  dap_debug = false, -- set to true to enable dap
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

For golang, the default gopls setup works perfectly fine, or you can install [navigator.lua](https://github.com/ray-x/navigator.lua) which can auto setup all lsp clients.

For diagnostic issue, you can use the default setup.  There are also quite a few plugins that you can use to explore issues, e.g. [navigator.lua](https://github.com/ray-x/navigator.lua), [folke/lsp-trouble.nvim](https://github.com/folke/lsp-trouble.nvim). [Nvim-tree](https://github.com/kyazdani42/nvim-tree.lua) and [Bufferline](https://github.com/akinsho/nvim-bufferline.lua) also introduced lsp diagnostic hooks.

Also, you can do this: put **all** diag error/warning of your project in quickfix.

```lua
  -- hdlr alternatively, use lua vim.lsp.diagnostic.set_loclist({open_loclist = false})
  -- true to open loclist
  local diag_hdlr =  function(err, method, result, client_id, bufnr, config)
    -- vim.lsp.diagnostic.clear(vim.fn.bufnr(), client.id, nil, nil)
    vim.lsp.diagnostic.on_publish_diagnostics(err, method, result, client_id, bufnr, config)
    if result and result.diagnostics then
        local item_list = {}
        local s = result.uri
        local fname = s
        for _, v in ipairs(result.diagnostics) do
            i, j = string.find(s, "file://")
            if j then
              fname = string.sub(s, j + 1)
            end
            table.insert(item_list, { filename = fname, lnum = v.range.start.line + 1, col = v.range.start.character + 1; text = v.message; })
        end
        local old_items = vim.fn.getqflist()
        for _, old_item in ipairs(old_items) do
            local bufnr = vim.uri_to_bufnr(result.uri)
            if vim.uri_from_bufnr(old_item.bufnr) ~= result.uri then
                    table.insert(item_list, old_item)
            end
        end
        vim.fn.setqflist({}, ' ', { title = 'LSP'; items = item_list; })
      end
    end


  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    diag_hdlr,
    {
      -- Enable underline, use default values
      underline = true,
      -- Enable virtual text, override spacing to 0
      virtual_text = {
        spacing = 0,
        prefix = '', --'',  
      },
      -- Use a function to dynamically turn signs off
      -- and on, using buffer local variables
      signs = true,
      -- Disable a feature
      update_in_insert = false,
    }
  )
```
