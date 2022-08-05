-- some of commands extracted from gopher.vim
local go = {}
local vfn = vim.fn

-- Keep this in sync with README.md
-- Keep this in sync with doc/go.txt
_GO_NVIM_CFG = {
  disable_defaults = false, -- either true when true disable all default settings
  go = "go", -- set to go1.18beta1 if necessary
  goimport = "gopls", -- if set to 'gopls' will use gopls format, also goimport
  fillstruct = "gopls",
  gofmt = "gofumpt", -- if set to gopls will use gopls format
  max_line_len = 128,
  tag_transform = false,

  gotests_template = "", -- sets gotests -template parameter (check gotests for details)
  gotests_template_dir = "", -- sets gotests -template_dir parameter (check gotests for details)

  comment_placeholder = "   ",
  icons = { breakpoint = "🧘", currentpos = "🏃" }, -- set to false to disable icons setup
  sign_priority = 7,  -- set priority of signs used by go.nevim 
  verbose = false,
  log_path = vfn.expand("$HOME") .. "/tmp/gonvim.log",
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
  -- if enable gopls to format the code and you also instlled and enabled null-ls, you may
  -- want to disable null-ls by setting this to true
  -- it can be a nulls source name e.g. `golines` or a nulls query table
  lsp_keymaps = true, -- true: use default keymaps defined in go/lsp.lua
  lsp_codelens = true,
  lsp_diag_hdlr = true, -- hook lsp diag handler
  -- virtual text setup
  lsp_diag_virtual_text = { space = 0, prefix = "" },
  lsp_diag_signs = true,
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
    -- default: "=>"
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
  lsp_diag_update_in_insert = false,
  lsp_fmt_async = false, -- async lsp.buf.format
  go_boilplater_url = "https://github.com/thockin/go-build-template.git",
  gopls_cmd = nil, --- you can provide gopls path and cmd if it not in PATH, e.g. cmd = {  "/home/ray/.local/nvim/data/lspinstall/go/gopls" }
  gopls_remote_auto = true,
  gocoverage_sign = "█",
  gocoverage_sign_priority = 7,
  launch_json = nil, -- the launch.json file path, default to .vscode/launch.json
  -- launch_json = vfn.getcwd() .. "/.vscode/launch.json",
  dap_debug = true,
  dap_debug_gui = true,
  dap_debug_keymap = true, -- true: use keymap for debugger defined in go/dap.lua
  -- false: do not use keymap in go/dap.lua.  you must define your own.
  dap_vt = true, -- false, true and 'all frames'
  dap_port = 38697, -- can be set to a number or `-1` so go.nvim will pickup a random port
  build_tags = "", --- you can provide extra build tags for tests or debugger
  textobjects = true, -- treesitter binding for text objects
  test_runner = "go", -- one of {`go`, `richgo`, `dlv`, `ginkgo`}
  verbose_tests = true, -- set to add verbose flag to tests
  run_in_floaterm = false, -- set to true to run in float window.
  trouble = false, -- true: use trouble to open quickfix
  test_efm = false, -- errorfomat for quickfix, default mix mode, set to true will be efm only

  luasnip = false, -- enable included luasnip
  username = "",
  useremail = "",
  disable_per_project_cfg = false, -- set to true to disable load script from .gonvim/init.lua
}

-- TODO: nvim_{add,del}_user_command  https://github.com/neovim/neovim/pull/16752

function go.setup(cfg)
  cfg = cfg or {}
  if cfg.max_len then
    vim.notify("go.nvim max_len renamed to max_line_len", vim.lsp.log_levels.WARN)
  end
  if cfg.disable_defaults then
    for k, _ in pairs(_GO_NVIM_CFG) do
      if type(cfg[k]) == "boolean" then
        cfg[k] = false
      end
      if type(_GO_NVIM_CFG[k]) == "table" then
        _GO_NVIM_CFG[k] = {}
      end
    end
  end
  _GO_NVIM_CFG = vim.tbl_deep_extend("force", _GO_NVIM_CFG, cfg)

  require("go.commands").add_cmds()
  require("go.project").load_project()

  if _GO_NVIM_CFG.run_in_floaterm then
    vim.cmd([[command! -nargs=* GoTermClose lua require("go.term").close()]])
  end

  require("go.utils").set_nulls()

  if _GO_NVIM_CFG.lsp_cfg then
    require("go.lsp").setup()
    if _GO_NVIM_CFG.lsp_diag_hdlr then
      require("go.lsp_diag")
    end
  elseif not _GO_NVIM_CFG.lsp_cfg and _GO_NVIM_CFG.lsp_on_attach then
    vim.notify("lsp_on_attach ignored, because lsp_cfg is false", vim.lsp.log_levels.WARN)
  end
  require("go.coverage").highlight()
  if _GO_NVIM_CFG.lsp_codelens then
    require("go.codelens").setup()
  end

  if _GO_NVIM_CFG.textobjects then
    require("go.ts.textobjects").setup()
  end

  require("go.env").setup()

  if _GO_NVIM_CFG.luasnip then
    local ls = require("go.utils").load_plugin("LuaSnip", "luasnip")
    if ls then
      require("snips.go")
      require("snips.all")
    end
  end
  if _GO_NVIM_CFG.lsp_inlay_hints.enable then
    require("go.inlay").setup()
  end
  go.doc_complete = require("go.godoc").doc_complete
  go.package_complete = require("go.package").complete
  go.dbg_complete = require("go.complete").dbg_complete
  go.tools_complete = require("go.complete").tools_complete
  go.impl_complete = require("go.complete").impl_complete
  go.modify_tags_complete = require("go.complete").modify_tags_complete
  go.add_tags_complete = require("go.complete").add_tags_complete
end

go.set_test_runner = function(runner)
  --  richgo, go test, richgo, dlv, ginkgo
  local runners = { "richgo", "go", "richgo", "ginkgo" } --  dlv
  for _, v in pairs(runners) do
    if v == runner then
      _GO_NVIM_CFG.test_runner = runner
      return
    end
  end
  vim.notify("runner not supported " .. runner, vim.lsp.log_levels.ERROR)
end

return go
