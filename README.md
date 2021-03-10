# [WIP] go.nvim

A modern golang neovim plugin based on treesitter and nvim-lsp. It is written in Lua and async as much as possible.
PR & Suggestions welcome.

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

You will need to add keybind yourself:
e.g

```lua
  vim.cmd("autocmd FileType go nmap <Leader><Leader>l GoLint")
  vim.cmd("autocmd FileType go nmap <Leader>gc :lua require('go.comment').gen()")

```

## Nvim LSP setup

for golang: [LSP config](https://github.com/ray-x/dotfiles/blob/c45c1a79962e6cce444b1375082df03a88fa6054/nvim/lua/modules/completion/lspconfig.lua#L252)

```lua
lspconfig.gopls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  init_options = {
    usePlaceholders=true,
    completeUnimported=true,
  },

  message_level = vim.lsp.protocol.MessageType.Error;
  cmd = {
      "gopls",

      -- share the gopls instance if there is one already
      -- "-remote=auto",

      --[[ debug options ]]--
      --"-logfile=auto",
      --"-debug=:0",
      --"-remote.debug=:0",
      --"-rpc.trace",
  },
    settings = {
      gopls = {
        gofumpt = true,
        analyses = {
          unusedparams = true,
          unreachable = false,
        },
        codelenses = {
          generate = true, -- show the `go generate` lens.
          gc_details = true, --  // Show a code lens toggling the display of gc's choices.
        },
        usePlaceholders    = true,
        completeUnimported = true,
        staticcheck = true,
        matcher            = "fuzzy",
        symbolMatcher      = "fuzzy",
        gofumpt            = true,
        buildFlags = {"-tags", "integration"},
        -- buildFlags = {"-tags", "functional"}
      },
    },
    root_dir = function(fname)
      local util = require('lspconfig').util
      return util.root_pattern("go.mod", ".git")(fname) or util.path.dirname(fname)
    end;
}
```

And also lsp diagnostic, to put all diag error/warning in quickfix

```lua
  -- hdlr alternatively, use lua vim.lsp.diagnostic.set_loclist({open_loclist = false})  -- true to open loclist
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
