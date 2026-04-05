# go.nvim Advanced Setup

Advanced configuration guides for LSP, text objects, snippets, and integrations.
For installation and basic configuration, see the main [README](../README.md).
For command usage and demos, see the [Usage Guide](usage.md).

---

## Table of Contents
- [Installation](#installation)
- [Default Configuration](#default-configuration)
- [Project Setup](#project-setup)
- [Text Object](#text-object)
- [LuaSnip Supports](#luasnip-supports)
- [Nvim LSP Setup](#nvim-lsp-setup)
- [Gopls Setup](#gopls-setup)
- [Integrate with mason-lspconfig](#integrate-with-mason-lspconfig)
- [Highlighting for gomod, gosum, gohtmltmpl, gotmpl](#highlighting-for-gomod-gosum-gohtmltmpl-gotmpl)
- [Integrate null-ls](#integrate-null-ls)
- [Sample vimrc](#sample-vimrc)

---

## Installation

Use your favorite package manager to install. The dependency treesitter main branch (and optionally, treesitter-objects) should be installed the first time you use it. Also Run TSInstall go to install the go parser if not installed yet. sed is recommended to run this plugin.

### vim-plug
```viml
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'neovim/nvim-lspconfig'
Plug 'ray-x/go.nvim'
Plug 'ray-x/guihua.lua' ; required if you using treesitter main branch
```

### packer.nvim/pckr.nvim
```lua
use 'ray-x/go.nvim'
use 'ray-x/guihua.lua' -- required if using treesitter main branch
use 'neovim/nvim-lspconfig'
use 'nvim-treesitter/nvim-treesitter'
```
## Default Configuration

Configure from lua suggested, The default setup:

```lua
require('go').setup({

  disable_defaults = false, -- true|false when true set false to all boolean settings and replace all tables
  remap_commands = {}, -- Vim commands to remap or disable, e.g. `{ GoFmt = "GoFormat", GoDoc = false }`
  -- settings with {}; string will be set to ''. user need to setup ALL the settings
  -- It is import to set ALL values in your own config if set value to true otherwise the plugin may not work
  go='go', -- go command, can be go[default] or e.g. go1.18beta1
  goimports ='gopls', -- goimports command, can be gopls[default]
  gofmt = 'gopls', -- gofmt through gopls: alternative is gofumpt, goimports, gofmt, etc
  fillstruct = 'gopls',  -- set to fillstruct if gopls fails to fill struct
  max_line_len = 0, -- max line length, Target maximum line length
  tag_transform = false, -- can be transform option("snakecase", "camelcase", etc) check gomodifytags for details and more options
  tag_options = 'json=omitempty', -- sets options sent to gomodifytags, i.e., json=omitempty
  gotests_template = "", -- sets gotests -template parameter (check gotests for details)
  gotests_template_dir = "", -- sets gotests -template_dir parameter (check gotests for details)
  gotest_case_exact_match = true, -- true: run test with ^Testname$, false: run test with TestName
  comment_placeholder = '' ,  -- comment_placeholder your cool placeholder e.g. 󰟓       
  icons = {breakpoint = '🧘', currentpos = '🏃'},  -- setup to `false` to disable icons setup
  verbose = false,  -- output loginf in messages
  lsp_semantic_highlights = false, -- use highlights from gopls, disable by default as gopls/nvim not compatible
  lsp_cfg = false, -- true: use non-default gopls setup specified in go/lsp.lua
                   -- false: do nothing
                   -- if lsp_cfg is a table, merge table with with non-default gopls setup in go/lsp.lua, e.g.
                   -- lsp_cfg = {settings={gopls={matcher='CaseInsensitive', ['local'] = 'your_local_module_path', gofumpt = true }}}
  lsp_gofumpt = true, -- true: set default gofmt in gopls format to gofumpt
                      -- false: do not set default gofmt in gopls format to gofumpt
  lsp_on_attach = nil, -- nil: use on_attach function defined in go/lsp.lua,
                       --      when lsp_cfg is true
                       -- if lsp_on_attach is a function: use this function as on_attach function for gopls
  lsp_keymaps = true,  -- set to false to disable gopls/lsp keymap
  lsp_codelens = true,  -- set to false to disable codelens, true by default, you can use a function
                        -- function(bufnr)
                        --    vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>F", "<cmd>lua vim.lsp.buf.format()<CR>", {noremap=true, silent=true})
                        -- end
                        -- to setup a table of codelens

  golangci_lint = {
    default = 'standard', -- set to one of { 'standard', 'fast', 'all', 'none' }
    -- disable = {'errcheck', 'staticcheck'}, -- linters to disable empty by default
    -- enable = {'govet', 'ineffassign','revive', 'gosimple'}, -- linters to enable; empty by default
    config = nil,        -- set to a config file path
    no_config = false,   -- true: golangci-lint --no-config
    -- disable = {},     -- linters to disable empty by default, e.g. {'errcheck', 'staticcheck'}
    -- enable = {},      -- linters to enable; empty by default, set to e.g. {'govet', 'ineffassign','revive', 'gosimple'}
    -- enable_only = {}, -- linters to enable only; empty by default, set to e.g. {'govet', 'ineffassign','revive', 'gosimple'}
    severity = vim.diagnostic.severity.INFO, -- severity level of the diagnostics
  },
  null_ls = {    -- check null-ls integration in readme
    golangci_lint = {
      method = {"NULL_LS_DIAGNOSTICS_ON_SAVE", "NULL_LS_DIAGNOSTICS_ON_OPEN"}, -- when it should run
      severity = vim.diagnostic.severity.INFO, -- severity level of the diagnostics
    },
    gotest = {
      method = {"NULL_LS_DIAGNOSTICS_ON_SAVE"}, -- when it should run
      severity = vim.diagnostic.severity.WARN, -- severity level of the diagnostics
    },
  },
  diagnostic = false, -- set to table to customize vim.diagnostic.config setup
  -- example setup:
  -- diagnostic = {  -- set diagnostic to false to disable vim.diagnostic.config setup,
                  -- true: default nvim setup
    -- hdlr = false, -- hook lsp diag handler and send diag to quickfix
    -- underline = true,
    -- virtual_text = { spacing = 2, prefix = '' }, -- virtual text setup
    -- signs = {'', '', '', ''},  -- set to true to use default signs, an array of 4 to specify custom signs
    -- update_in_insert = false,
  -- },
  -- set to false/nil: disable config gopls diagnostic

  -- if you need to setup your ui for input and select, you can do it here
  -- go_input = require('guihua.input').input -- set to vim.ui.input to disable guihua input
  -- go_select = require('guihua.select').select -- vim.ui.select to disable guihua select
  lsp_document_formatting = true,
  -- set to true: use gopls to format
  -- false if you want to use other formatter tool(e.g. efm, nulls)
  lsp_inlay_hints = {
    enable = true, -- this is the only field apply to neovim > 0.10
  },
  gopls_cmd = nil, -- if you need to specify gopls path and cmd, e.g {"/home/user/lsp/gopls", "-logfile","/var/log/gopls.log" }
  gopls_remote_auto = true, -- add -remote=auto to gopls
  gocoverage_sign = "█",
  sign_priority = 5, -- change to a higher number to override other signs
  dap_debug = true, -- set to false to disable dap
  dap_debug_keymap = true, -- true: use keymap for debugger defined in go/dap.lua
                           -- false: do not use keymap in go/dap.lua.  you must define your own.
                           -- Windows: Use Visual Studio keymap
  dap_debug_gui = {}, -- bool|table put your dap-ui setup here set to false to disable
  dap_debug_vt = { enabled = true, enabled_commands = true, all_frames = true }, -- bool|table put your dap-virtual-text setup here set to false to disable

  dap_port = 38697, -- can be set to a number, if set to -1 go.nvim will pick up a random port
  dap_timeout = 15, --  see dap option initialize_timeout_sec = 15,
  dap_retries = 20, -- see dap option max_retries
  dap_enrich_config = nil, -- see dap option enrich_config
  build_tags = "tag1,tag2", -- set default build tags
  textobjects = true, -- enable default text objects through treesittter-text-objects
  test_runner = 'go', -- one of {`go`,  `dlv`, `ginkgo`, `gotestsum`}
  verbose_tests = true, -- set to add verbose flag to tests deprecated, see '-v' option
  run_in_floaterm = false, -- set to true to run in a float window. :GoTermClose closes the floatterm
                           -- float term recommend if you use gotestsum ginkgo with terminal color

  floaterm = {   -- position
    posititon = 'auto', -- one of {`top`, `bottom`, `left`, `right`, `center`, `auto`}
    width = 0.45, -- width of float window if not auto
    height = 0.98, -- height of float window if not auto
    title_colors = 'nord', -- default to nord, one of {'nord', 'tokyo', 'dracula', 'rainbow', 'solarized ', 'monokai'}
                              -- can also set to a list of colors to define colors to choose from
                              -- e.g {'#D8DEE9', '#5E81AC', '#88C0D0', '#EBCB8B', '#A3BE8C', '#B48EAD'}
  },
  ai = {
    enable = false, -- set to true to enable AI features (GoAI, GoCmtAI)
    provider = 'copilot', -- 'copilot' or 'openai' (any OpenAI-compatible endpoint)
    model = nil, -- model name, default: 'gpt-4o' for copilot, 'gpt-4o-mini' for openai
    api_key_env = 'OPENAI_API_KEY', -- env var name that holds the API key, env only! DO NOT put your key here.
    base_url = nil, -- for openai-compatible APIs, e.g.: 'https://api.openai.com/v1'
    confirm = true, -- confirm before executing the translated command
  },
  trouble = false, -- true: use trouble to open quickfix
  test_efm = false, -- errorfomat for quickfix, default mix mode, set to true will be efm only
  luasnip = false, -- enable included luasnip snippets. you can also disable while add lua/snips folder to luasnip load
  --  Do not enable this if you already added the path, that will duplicate the entries
  on_jobstart = function(cmd) _=cmd end, -- callback for stdout
  on_stdout = function(err, data) _, _ = err, data end, -- callback when job started
  on_stderr = function(err, data)  _, _ = err, data  end, -- callback for stderr
  on_exit = function(code, signal, output)  _, _, _ = code, signal, output  end, -- callback for jobexit, output : string
  iferr_vertical_shift = 4, -- defines where the cursor will end up vertically from the begining of if err statement
  iferr_less_highlight = false, -- set to true to make 'if err != nil' statements less highlighted (grayed out)
})
```

You will need to add keybind yourself: e.g

```lua
vim.cmd("autocmd FileType go nmap <Leader><Leader>l GoLint")
vim.cmd("autocmd FileType go nmap <Leader>gc :lua require('go.comment').gen()")
```

## Project Setup

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

## Text Object

I did not provide textobject support in the plugin. Please use treesitter textobject plugin. My treesitter config:

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

</details>

## LuaSnip Supports

go.nvim provides a better snippet support for go. Please check
[snippets for all languages](https://github.com/ray-x/go.nvim/blob/master/lua/snips/all.lua) and
[snippets for go](https://github.com/ray-x/go.nvim/blob/master/lua/snips/go.lua)

For a video demo, please check this: [go.nvim new features work through](https://www.youtube.com/watch?v=tsLnEfYTgcM)

If you are not familiar with luasnip, please checkout [LuaSnip Tutorial](https://www.youtube.com/watch?v=ub0REXjhpmk)
and [TJ's Introduction to LuaSnip](https://www.youtube.com/watch?v=Dn800rlPIho)

## Nvim LSP Setup

go.nvim provided a non-default setup for gopls (includes debounce, staticcheck, diagnosticsDelay etc)

The gopls setup provided by go.nvim works perfectly fine for most of the cases. You can also install
[navigator.lua](https://github.com/ray-x/navigator.lua) which can auto setup all lsp clients and provides a better GUI.

To display diagnostic info, there are a few plugins that you can use to explore issues, e.g.
[navigator.lua](https://github.com/ray-x/navigator.lua),
[folke/lsp-trouble.nvim](https://github.com/folke/lsp-trouble.nvim).
[Nvim-tree](https://github.com/kyazdani42/nvim-tree.lua) and
[Bufferline](https://github.com/akinsho/nvim-bufferline.lua) also introduced lsp diagnostic hooks.

> [!IMPORTANT] I will integrate more gopls functions into go.nvim, please make sure you have the latest version
> installed Also, enable gopls experimental features if it is configure somewhere other than go.nvim Otherwise, set
> `lsp_cfg` to `true` in your go.nvim setup to enable gopls setup in go.nvim

<details>
  <summary>Gopls default settings in go.nvim</summary>

```lua
gopls = {
    capabilities = {
      textDocument = {
        completion = {
          completionItem = {
            commitCharactersSupport = true,
            deprecatedSupport = true,
            documentationFormat = { 'markdown', 'plaintext' },
            preselectSupport = true,
            insertReplaceSupport = true,
            labelDetailsSupport = true,
            snippetSupport = true,
            resolveSupport = {
              properties = {
                'documentation',
                'details',
                'additionalTextEdits',
              },
            },
          },
          contextSupport = true,
          dynamicRegistration = true,
        },
      },
    },
    filetypes = { 'go', 'gomod', 'gosum', 'gotmpl', 'gohtmltmpl', 'gotexttmpl' },
    message_level = vim.lsp.protocol.MessageType.Error,
    cmd = {
      'gopls', -- share the gopls instance if there is one already
      '-remote.debug=:0',
    },
    root_dir = function(fname)
      local has_lsp, lspconfig = pcall(require, 'lspconfig')
      if has_lsp then
        local util = lspconfig.util
        return util.root_pattern('go.work', 'go.mod')(fname)
          or util.root_pattern('.git')(fname)
          or util.path.dirname(fname)
      end
    end,
    flags = { allow_incremental_sync = true, debounce_text_changes = 500 },
    settings = {
      gopls = {
        -- more settings: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
        -- not supported
        analyses = {
          unreachable = true,
          nilness = true,
          unusedparams = true,
          useany = true,
          unusedwrite = true,
          ST1003 = true,
          undeclaredname = true,
          fillreturns = true,
          nonewvars = true,
          fieldalignment = false,
          shadow = true,
        },
        codelenses = {
          generate = true, -- show the `go generate` lens.
          gc_details = true, -- Show a code lens toggling the display of gc's choices.
          test = true,
          tidy = true,
          vendor = true,
          regenerate_cgo = true,
          upgrade_dependency = true,
        },
        hints = {
          assignVariableTypes = true,
          compositeLiteralFields = true,
          compositeLiteralTypes = true,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
        usePlaceholders = true,
        completeUnimported = true,
        staticcheck = true,
        matcher = 'Fuzzy',
        diagnosticsDelay = '500ms',
        symbolMatcher = 'fuzzy',
        semanticTokens = false,  -- either enable semantic tokens or use treesitter
        noSemanticTokens = true, -- disable semantic string tokens so we can use treesitter highlight injection

        ['local'] = get_current_gomod(),
        gofumpt = _GO_NVIM_CFG.lsp_gofumpt or false, -- true|false, -- turn on for new repos, gofmpt is good but also create code turmoils
        buildFlags = { '-tags', 'integration' },
      },
    },
    -- NOTE: it is important to add handler to formatting handlers
    -- the async formatter will call these handlers when gopls responed
    -- without these handlers, the file will not be saved
    handlers = {
      [range_format] = function(...)
        vim.lsp.handlers[range_format](...)
        if vfn.getbufinfo('%')[1].changed == 1 then
          vim.cmd('noautocmd write')
        end
      end,
      [formatting] = function(...)
        vim.lsp.handlers[formatting](...)
        if vfn.getbufinfo('%')[1].changed == 1 then
          vim.cmd('noautocmd write')
        end
      end,
    },
  }
```

</details>

## Gopls Setup

By default the lsp_cfg is set to false. You can set it to true to use the default gopls setup provided by go.nvim and
enable the gopls. If you want to use your own gopls setup, you can set it to false and do the following:

> [!Note] Neovim 0.11 and above If you are using neovim 0.11 and above, you can use the new `vim.lsp.config` setup.

```lua
-- in your init.lua
-- lazy spec
{
  'ray-x/go.nvim',
  dependencies = {
    'ray-x/guihua.lua', -- optional
    'nvim-treesitter/nvim-treesitter',
    'neovim/nvim-lspconfig',
  },
  opts = {}  -- by default lsp_cfg = false
  -- opts = { lsp_cfg = true } -- use go.nvim will setup gopls
  config = function(lp, opts)
    require("go").setup(opts)
    --
    -- format config here
    --
    local gopls_cfg = require('go.lsp').config()
    -- gopls_cfg.filetypes = { 'go', 'gomod'}, -- override settings
    vim.lsp.config.gopls = gopls_cfg
    vim.lsp.enable('gopls')
  end
}
```

## Integrate with mason-lspconfig

```lua
require("mason").setup()
require("mason-lspconfig").setup()
require('lspconfig').gopls.setup({
   -- your gopls setup
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

## Highlighting for gomod, gosum, gohtmltmpl, gotmpl

You can install tree-sitter parsers for gomod, gosum and gotmpl

```vim
:TSInstall gomod gosum gotmpl
```

The plugin injects the tmpl to html syntax so you should see this:

![image](https://github.com/ray-x/go.nvim/assets/1681295/7d11eb96-4803-418b-b056-336163ed492b)

To get highlighting for other templated languages check out the docs of
[tree-sitter-go-template](https://github.com/ngalaiko/tree-sitter-go-template).

## Integrate null-ls

### The plugin provides

- `gotest` LSP diagnostic source for null-ls
- `golangci_lint` A async version of golangci-lint(v2) null-ls lint
- `gotest_action` LSP test code action for null-ls

Gotest allow you run `go test <package>` when you save your go file and add diagnostics to nvim

```lua
local null_ls = require("null-ls")
local sources = {
  null_ls.builtins.diagnostics.revive,
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
  goimports = 'gopls', -- if set to 'gopls' will use golsp format
  gofmt = 'gopls', -- if set to gopls will use golsp format
  tag_transform = false,
  test_dir = '',
  comment_placeholder = '   ',
  lsp_cfg = true, -- false: use your own lspconfig
  lsp_gofumpt = true, -- true: set default gofmt in gopls format to gofumpt
  lsp_on_attach = true, -- use on_attach from go.nvim
  dap_debug = true,
})

local protocol = require'vim.lsp.protocol'

EOF
```

This will setup gopls with non default configure provided by go.nvim (Includes lspconfig default keymaps)
