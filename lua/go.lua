-- some of commands extracted from gopher.vim
local go = {}
local vfn = vim.fn

-- Keep this in sync with README.md
-- Keep this in sync with doc/go.txt
_GO_NVIM_CFG = {
  treesitter_main = false,
  disable_defaults = false, -- true|false when true disable all default settings, user need to set all settings
  remap_commands = {}, -- Vim commands to remap or disable, e.g. `{ GoFmt = "GoFormat", GoDoc = false }`
  go = 'go', -- set to go1.18beta1 if necessary
  goimports = 'gopls', -- if set to 'gopls' will use gopls format, also goimports
  fillstruct = 'gopls',
  gofmt = 'gopls', -- if set to gopls will use gopls format
  max_line_len = 0,
  tag_transform = false, -- gomodifytags: set to e.g. 'snakecase' to transform to snake_case
  tag_options = 'json=omitempty', -- gomodifytags: set to e.g. 'json=omitempty' to add tag options

  gotests_template = '', -- sets gotests -template parameter (check gotests for details)
  gotests_template_dir = '', -- sets gotests -template_dir parameter (check gotests for details)
  gotest_case_exact_match = true, -- default to true, if set to false will match any part of the test name

  comment_placeholder = '   ',
  icons = { breakpoint = '🧘', currentpos = '🏃' }, -- set to false to disable icons setup
  sign_priority = 7, -- set priority of signs used by go.nevim
  verbose = false,
  log_path = vfn.expand('$HOME') .. '/tmp/gonvim.log',
  lsp_cfg = false, -- false: do nothing
  -- true: apply non-default gopls setup defined in go/gopls.lua
  -- if lsp_cfg is a table, merge table with with non-default gopls setup in go/gopls.lua, e.g.
  lsp_gofumpt = false, -- true: set default gofmt in gopls format to gofumpt
  lsp_semantic_highlights = false, -- use highlights from gopls
  lsp_impl = {
    enable = false,
    prefix = '  ',
    separator = ', ',
    highlight = 'Constant',
  },
  lsp_on_attach = nil, -- nil: use on_attach function defined in go/lsp.lua for gopls,
  --      when lsp_cfg is true
  -- if lsp_on_attach is a function: use this function as on_attach function for gopls,
  --                                 when lsp_cfg is true
  lsp_on_client_start = nil, -- it is a function with same signature as on_attach, will be called at end of
  -- on_attach and allows you override some setup
  lsp_document_formatting = true,
  -- set to true: use gopls to format
  -- false if you want to use other formatter tool(e.g. efm, nulls)

  null_ls_document_formatting_disable = false, -- true: disable null-ls formatting
  -- if enable gopls to format the code and you also installed and enabled null-ls, you may
  -- want to disable null-ls by setting this to true
  -- it can be a nulls source name e.g. `golines` or a nulls query table
  lsp_keymaps = true, -- true: use default keymaps defined in go/lsp.lua
  lsp_codelens = true,
  golangci_lint = {
    default = 'standard', -- set to one of { 'standard', 'fast', 'all', 'none' }
    config = nil, -- set to a config file path, default to .golangci.yml
    -- Note: golangci-lint will use the config file in the current directory if no config is provided
    -- null-ls need json output, so set to true to use json format
    -- Goling require text output, so set to false to use text format
    no_config = false, -- golangci-lint --no-config
    -- disable = {'errcheck', 'staticcheck'}, -- linters to disable empty by default
    -- enable = {'govet', 'ineffassign','revive', 'gosimple'}, -- linters to enable; empty by default
    -- enable_only = {},
    severity = vim.diagnostic.severity.INFO, -- severity level of the diagnostics
  },
  null_ls = {
    -- additional setup for golangci_lint source
    golangci_lint = {
      method = { 'NULL_LS_DIAGNOSTICS_ON_SAVE', 'NULL_LS_DIAGNOSTICS_ON_OPEN' }, -- when it should run
      severity = vim.diagnostic.severity.INFO, -- severity level of the diagnostics
    },
    gotest = {
      method = { 'NULL_LS_DIAGNOSTICS_ON_SAVE' }, -- when it should run
      severity = vim.diagnostic.severity.WARN, -- severity level of the diagnostics
    },
  },
  diagnostic = false, -- set to false to disable diagnostic setup from go.nvim
  --[[
  diagnostic = { -- set diagnostic to false to disable diagnostic
    hdlr = false, -- hook diagnostic handler and send error to quickfix
    underline = true,
    -- virtual text setup
    virtual_text = { spacing = 0, prefix = '■' },
    update_in_insert = false,
    signs = true, -- use a table to configure the signs
    -- signs = {
    --   text = { '🚑', '🔧', '🪛', '🧹' },
    -- },
  }, --]]
  go_input = function()
    if require('go.utils').load_plugin('guihua.lua', 'guihua.gui') then
      return require('guihua.input').input
    end
    return vim.ui.input
  end,
  go_select = function()
    if require('go.utils').load_plugin('guihua.lua', 'guihua.gui') then
      return require('guihua.gui').select
    end
    return vim.ui.select
  end,
  preludes = { -- experimental feature, set to empty to disable; set to function to enable
    default = function()
      return {}
    end, -- one for all commands
    GoRun = function() -- the commands to run before GoRun, this override default
      return {} -- e.g. return {'watchexe', '--restart', '-v', '-e', 'go'}
      -- so you will run `watchexe --restart -v -e go go run `
    end,
  },
  lsp_inlay_hints = {
    enable = true,
  },
  lsp_diag_update_in_insert = false,
  lsp_fmt_async = false, -- async lsp.buf.format
  go_boilplater_url = 'https://github.com/thockin/go-build-template.git',
  gopls_cmd = nil, --- you can provide gopls path and cmd if it not in PATH, e.g. cmd = {  "/home/ray/.local/nvim/data/lspinstall/go/gopls" }
  gopls_remote_auto = true,
  gocoverage_sign = '█',
  gocoverage_skip_covered = false,
  sign_covered_hl = 'String', --- highlight group for test covered sign
  sign_partial_hl = 'WarningMsg', --- highlight group for test partially covered sign
  sign_uncovered_hl = 'Error', -- highlight group for uncovered code
  launch_json = nil, -- the launch.json file path, default to .vscode/launch.json
  -- launch_json = vfn.getcwd() .. "/.vscode/launch.json",
  dap_debug = true,
  dap_debug_gui = {}, -- bool|table put your dap-ui setup here set to false to disable
  dap_debug_keymap = true, -- true: use keymap for debugger defined in go/dap.lua
  -- false: do not use keymap in go/dap.lua.  you must define your own.
  dap_debug_vt = { enabled = true, enabled_commands = true, all_frames = true }, -- bool|table put your dap-virtual-text setup here set to false to disable
  dap_port = 38697, -- can be set to a number or -1 so go.nvim will pickup a random port
  dap_timeout = 15, --  see dap option initialize_timeout_sec = 15,
  dap_enrich_config = nil, -- see dap option enrich_config
  dap_retries = 20, -- see dap option max_retries
  build_tags = '', --- you can provide extra build tags for tests or debugger
  textobjects = true, -- treesitter binding for text objects
  test_runner = 'go', -- one of {`go`, `richgo`, `dlv`, `ginkgo`, `gotestsum`}
  verbose_tests = false, -- set to add verbose flag to tests deprecated see '-v'
  run_in_floaterm = false, -- set to true to run in float window.
  floaterm = {
    posititon = 'auto', -- one of {`top`, `bottom`, `left`, `right`, `center`, `auto`}
    width = 0.45, -- width of float window if not auto
    height = 0.98, -- height of float window if not auto
    title_colors = 'nord', -- table of colors for title, or a color scheme name
  },
  trouble = false, -- true: use trouble to open quickfix
  test_efm = false, -- errorfomat for quickfix, default mix mode, set to true will be efm only

  luasnip = false, -- enable included luasnip
  username = '',
  useremail = '',
  disable_per_project_cfg = false, -- set to true to disable load script from .gonvim/init.lua
  on_jobstart = function(cmd)
    _ = cmd
  end, -- callback for stdout
  on_stdout = function(err, data)
    _, _ = err, data
  end, -- callback when job started
  on_stderr = function(err, data)
    _, _ = err, data
  end, -- callback for stderr
  on_exit = function(code, signal, output)
    _, _, _ = code, signal, output
  end, -- callback for jobexit, output : string
  iferr_vertical_shift = 4, -- defines where the cursor will end up vertically from the begining of if err statement after GoIfErr command
  iferr_less_highlight = false, -- set to true to make 'if err != nil' statements less highlighted (grayed out)
}

-- TODO: nvim_{add,del}_user_command  https://github.com/neovim/neovim/pull/16752

local function reset_tbl(tbl)
  for k, _ in pairs(tbl) do
    if type(tbl[k]) == 'table' then
      if (vim.islist or vim.tbl_islist)(tbl[k]) then
        tbl[k] = {}
      else
        reset_tbl(tbl[k])
      end
    elseif type(tbl[k]) == 'string' then
      tbl[k] = ''
    elseif type(tbl[k]) == 'number' then
      tbl[k] = 0
    elseif type(tbl[k]) == 'boolean' then
      tbl[k] = false
    elseif type(tbl[k]) == 'function' then
      tbl[k] = function(...) end
    else
      tbl[k] = nil
    end
  end
  return tbl
end

function go.setup(cfg)
  if vim.fn.has('nvim-0.10') == 0 then
    vim.notify('go.nvim master branch requires nvim 0.10', vim.log.levels.WARN)
    return
  end
  cfg = cfg or {}
  if cfg.disable_defaults then
    reset_tbl(_GO_NVIM_CFG)
    _GO_NVIM_CFG.disable_defaults = true
    _GO_NVIM_CFG.diagnostic = false
    _GO_NVIM_CFG.preludes = { -- experimental feature, set to empty to disable; set to function to enable
      default = function()
        return {}
      end, -- one for all commands
      GoRun = function() -- the commands to run before GoRun, this override default
        return {} -- e.g. return {'watchexe', '--restart', '-v', '-e', 'go'}
        -- so you will run `watchexe --restart -v -e go go run `
      end,
    }
  end

  -- ts master branch use nvim-treesitter.configs
  -- ts main branch use nvim-treesitter.config
  local has_ts_main = pcall(require, 'nvim-treesitter.config')
  _GO_NVIM_CFG.treesitter_main = has_ts_main
  -- legacy options
  if type(cfg.null_ls) == 'boolean' then
    vim.notify('go.nvim config: null_ls=boolean deprecated, refer to README for more info', vim.log.levels.WARN)
    _GO_NVIM_CFG.null_ls = {}
  end

  if type(cfg.null_ls) == 'table' then
    if type(cfg.null_ls.golangci_lint) == 'table' then
      for k, _ in pairs(cfg.null_ls.golangci_lint) do
        -- the key has to be one of 'method', 'severity'
        if not vim.tbl_contains({ 'method', 'severity' }, k) then
          vim.notify(
            'go.nvim config: null_ls.golangci_lint.' .. k .. ' deprecated, use golangci_lint.' .. k,
            vim.log.levels.WARN
          )
        end
      end
    end
  end

  _GO_NVIM_CFG = vim.tbl_deep_extend('force', _GO_NVIM_CFG, cfg)

  -- Set up iferr highlighting early, before treesitter loads
  require('go.iferr_highlight').setup(_GO_NVIM_CFG)

  if vim.fn.empty(_GO_NVIM_CFG.go) == 1 then
    vim.notify('go.nvim go binary is not setup', vim.log.levels.ERROR)
  end

  if _GO_NVIM_CFG.max_line_len > 0 and _GO_NVIM_CFG.gofmt ~= 'golines' then
    vim.notify('go.nvim max_line_len only effective when gofmt is golines', vim.log.levels.WARN)
  end

  require('go.commands').add_cmds()
  vim.defer_fn(function()
    require('go.project').load_project()
    require('go.utils').set_nulls()
  end, 1)

  if _GO_NVIM_CFG.run_in_floaterm then
    vim.cmd([[command! -nargs=* GoTermClose lua require("go.term").close()]])
  end

  if _GO_NVIM_CFG.lsp_cfg then
    require('go.lsp').setup()
  elseif not _GO_NVIM_CFG.lsp_cfg and _GO_NVIM_CFG.lsp_on_attach then
    vim.notify('lsp_on_attach ignored, because lsp_cfg is false', vim.log.levels.WARN)
  end

  if type(_GO_NVIM_CFG.diagnostic) == 'boolean' then
    if _GO_NVIM_CFG.diagnostic then
      vim.diagnostic.config()
      -- enabled with default
      _GO_NVIM_CFG.diagnostic = {
        hdlr = false,
        underline = true,
        virtual_text = { spacing = 0, prefix = '■' },
        update_in_insert = false,
        signs = true,
      }
      vim.diagnostic.config(_GO_NVIM_CFG.diagnostic)
    else
      -- we do not setup diagnostic from go.nvim
      -- use whatever user has setup
      _GO_NVIM_CFG.diagnostic = nil
    end
  else
    -- vim.notify('go.nvim diagnostic setup deprecated, use vim.diagnostic instead', vim.log.levels.DEBUG)
    local dcfg = vim.tbl_extend('force', {}, _GO_NVIM_CFG.diagnostic)
    vim.diagnostic.config(dcfg)
  end
  vim.defer_fn(function()
    require('go.coverage').setup()
    if _GO_NVIM_CFG.lsp_codelens then
      require('go.codelens').setup()
    end

    if _GO_NVIM_CFG.textobjects then
      require('go.ts.textobjects').setup()
    end

    require('go.env').setup()
  end, 1)

  vim.defer_fn(function()
    if _GO_NVIM_CFG.luasnip then
      local ls = require('go.utils').load_plugin('LuaSnip', 'luasnip')
      if ls then
        require('snips.go')
        require('snips.all')
      end
    end
  end, 2)

  if _GO_NVIM_CFG.lsp_impl and _GO_NVIM_CFG.lsp_impl.enable then
    require('go.gopls_impl').setup(_GO_NVIM_CFG.lsp_impl)
  end
  if _GO_NVIM_CFG.lsp_inlay_hints.enable then
    vim.lsp.inlay_hint.enable(true)
  end

  go.doc_complete = require('go.godoc').doc_complete
  go.package_complete = require('go.package').complete
  go.dbg_complete = require('go.complete').dbg_complete
  go.tools_complete = require('go.complete').tools_complete
  go.impl_complete = require('go.complete').impl_complete
  go.modify_tags_complete = require('go.complete').modify_tags_complete
  go.add_tags_complete = require('go.complete').add_tags_complete
  require('go.mod').setup()
end

go.set_test_runner = function(runner)
  --  richgo, go test, richgo, dlv, ginkgo
  local runners = { 'richgo', 'go', 'richgo', 'ginkgo' } --  dlv
  if runner == 'richgo' then
    vim.notify('richgo is deprecated, use gotestsum', vim.log.levels.WARN)
    runner = 'gotestsum'
  end
  if vim.tbl_contains(runners, runner) then
    _GO_NVIM_CFG.test_runner = runner
    return
  end
  vim.notify('runner not supported ' .. runner, vim.log.levels.ERROR)
end

return go
