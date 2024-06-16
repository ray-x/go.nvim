-- some of commands extracted from gopher.vim
local go = {}
local vfn = vim.fn

-- Keep this in sync with README.md
-- Keep this in sync with doc/go.txt
_GO_NVIM_CFG = {
  disable_defaults = false, -- true|false when true disable all default settings, user need to set all settings
  go = 'go', -- set to go1.18beta1 if necessary
  goimports = 'gopls', -- if set to 'gopls' will use gopls format, also goimports
  fillstruct = 'gopls',
  gofmt = 'gopls', -- if set to gopls will use gopls format
  max_line_len = 0,
  tag_transform = false,
  tag_options = 'json=omitempty',

  gotests_template = '', -- sets gotests -template parameter (check gotests for details)
  gotests_template_dir = '', -- sets gotests -template_dir parameter (check gotests for details)

  comment_placeholder = '   ',
  icons = { breakpoint = '🧘', currentpos = '🏃' }, -- set to false to disable icons setup
  sign_priority = 7, -- set priority of signs used by go.nevim
  verbose = false,
  log_path = vfn.expand('$HOME') .. '/tmp/gonvim.log',
  lsp_cfg = false, -- false: do nothing
  -- true: apply non-default gopls setup defined in go/lsp.lua
  -- if lsp_cfg is a table, merge table with with non-default gopls setup in go/lsp.lua, e.g.
  lsp_gofumpt = false, -- true: set default gofmt in gopls format to gofumpt
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
  null_ls = {
    golangci_lint = {
      -- disable = {'errcheck', 'staticcheck'}, -- linters to disable empty by default
      -- enable = {'govet', 'ineffassign','revive', 'gosimple'}, -- linters to enable; empty by default
    },
  },
  diagnostic = { -- set diagnostic to false to disable diagnostic
    hdlr = false, -- hook diagnostic handler and send error to quickfix
    underline = true,
    -- virtual text setup
    virtual_text = { spacing = 0, prefix = '■' },
    update_in_insert = false,
    signs = true, -- use a table to configure the signs
  },
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
  -- deprecated setups
  lsp_inlay_hints = {
    enable = true,
    style = 'inlay', -- 'default: inlay', 'eol': show at end of line, 'inlay': show in the middle of the line

    -- Note: following setup only for for style == 'eol'
    -- Only show inlay hints for the current line
    only_current_line = false,

    -- Event which triggers a refresh of the inlay hints.
    -- You can make this "CursorMoved" or "CursorMoved,CursorMovedI" but
    -- not that this may cause higher CPU usage.
    -- This option is only respected when only_current_line and
    -- autoSetHints both are true.
    only_current_line_autocmd = 'CursorHold',

    -- whether to show variable name before type hints with the inlay hints or not
    -- default: false
    show_variable_name = true,

    -- prefix for parameter hints
    parameter_hints_prefix = '󰊕 ',
    show_parameter_hints = true,

    -- prefix for all the other hints (type, chaining)
    -- default: "=>"
    other_hints_prefix = '=> ',

    -- whether to align to the length of the longest line in the file
    max_len_align = false,

    -- padding from the left if max_len_align is true
    max_len_align_padding = 1,

    -- whether to align to the extreme right or not
    right_align = false,

    -- padding from the right if right_align is true
    right_align_padding = 6,

    -- The color of the hints
    highlight = 'Comment',
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
  dap_debug_vt = { enabled_commands = true, all_frames = true }, -- bool|table put your dap-virtual-text setup here set to false to disable
  dap_port = 38697, -- can be set to a number or -1 so go.nvim will pickup a random port
  dap_timeout = 15, --  see dap option initialize_timeout_sec = 15,
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
  if vim.fn.has('nvim-0.9') == 0 then
    vim.notify('go.nvim master branch requires nvim 0.9', vim.log.levels.WARN)
  end
  cfg = cfg or {}
  if cfg.lsp_diag_hdlr ~= nil then
    vim.notify('go.nvim lsp_diag_hdlr deprecated, use diagnostic.hdlr', vim.log.levels.WARN)
  end
  if cfg.lsp_diag_underline ~= nil then
    vim.notify(
      'go.nvim lsp_diag_underline deprecated, use diagnostic.underline',
      vim.log.levels.WARN
    )
  end
  if cfg.goimport ~= nil then
    vim.notify('go.nvim goimport deprecated, use goimports', vim.log.levels.WARN)
    cfg.goimports = cfg.goimport
  end
  if cfg.lsp_diag_virtual_text ~= nil then
    vim.notify(
      'go.nvim lsp_diag_virtual_text deprecated, use diagnostic.virtual_text',
      vim.log.levels.WARN
    )
  end
  if cfg.lsp_diag_signs ~= nil then
    vim.notify('go.nvim lsp_diag_signs deprecated, use diagnostic.signs', vim.log.levels.WARN)
  end
  if cfg.disable_defaults then
    reset_tbl(_GO_NVIM_CFG)
    _GO_NVIM_CFG.disable_defaults = true
    _GO_NVIM_CFG.diagnostic = false
  end
  _GO_NVIM_CFG = vim.tbl_deep_extend('force', _GO_NVIM_CFG, cfg)

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

  if _GO_NVIM_CFG.diagnostic then
    local dcfg = vim.tbl_extend('force', {}, _GO_NVIM_CFG.diagnostic)
    dcfg.hdlr = nil
    vim.diagnostic.config(dcfg)

    require('go.lsp_diag').setup()
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
    if _GO_NVIM_CFG.lsp_inlay_hints.enable then
      require('go.inlay').setup()
    end
  end, 2)

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
