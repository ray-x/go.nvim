-- some of commands extracted from gopher.vim
local go = {}
_GO_NVIM_CFG = {
  goimport = 'gopls', -- if set to 'gopls' will use gopls format, also goimport
  fillstruct = 'gopls',
  gofmt = 'gofumpt', -- if set to gopls will use gopls format
  max_line_len = 120,
  tag_transform = false,
  test_dir = '',
  comment_placeholder = '   ',
  icons = {breakpoint = '🧘', currentpos = '🏃'},
  verbose = false,
  log_path = vim.fn.expand("$HOME") .. "/tmp/gonvim.log",
  lsp_cfg = false, -- true: apply go.nvim non-default gopls setup
  lsp_gofumpt = false, -- true: set default gofmt in gopls format to gofumpt
  lsp_on_attach = nil, -- provides a on_attach function to gopls, will use go.nvim on_attach if nil
  lsp_diag_hdlr = true, -- hook lsp diag handler
  lsp_codelens = true,
  gopls_remote_auto = true,
  gocoverage_sign = '█',
  gocoverage_sign_priority = 5,
  dap_debug = true,
  dap_debug_gui = true,
  dap_vt = true, -- false, true and 'all frames'
  gopls_cmd = nil, --- you can provide gopls path and cmd if it not in PATH, e.g. cmd = {  "/home/ray/.local/nvim/data/lspinstall/go/gopls" }
  build_tags = "", --- you can provide extra build tags for tests or debugger
}

local dap_config = function()
  vim.fn.sign_define('DapBreakpoint', {
    text = _GO_NVIM_CFG.icons.breakpoint,
    texthl = '',
    linehl = '',
    numhl = ''
  })
  vim.fn.sign_define('DapStopped', {
    text = _GO_NVIM_CFG.icons.currentpos,
    texthl = '',
    linehl = '',
    numhl = ''
  })
  vim.cmd([[command! BreakCondition lua require"dap".set_breakpoint(vim.fn.input("Breakpoint condition: "))]])

  vim.cmd([[command! ReplRun lua require"dap".repl.run_last()]])
  vim.cmd([[command! ReplToggle lua require"dap".repl.toggle()]])
  vim.cmd([[command! ReplOpen  lua require"dap".repl.open(), 'split']])
  vim.cmd([[command! DapRerun lua require'dap'.disconnect();require'dap'.close();require'dap'.run_last()]])

  vim.cmd([[command! DapStop lua require'go.dap'.stop()]])
  vim.g.dap_virtual_text = true
end

function go.setup(cfg)
  cfg = cfg or {}
  if cfg.max_len then
    print('go.nvim max_len renamed to max_line_len')
  end
  _GO_NVIM_CFG = vim.tbl_extend("force", _GO_NVIM_CFG, cfg)

  vim.cmd [[autocmd FileType go setlocal omnifunc=v:lua.vim.lsp.omnifunc]]

  vim.cmd([[command! GoMake silent lua require'go.asyncmake'.make()]])

  vim.cmd([[command! GoFmt lua require("go.format").gofmt()]])
  vim.cmd([[command! -nargs=* GoImport lua require("go.format").goimport(<f-args>)]])

  vim.cmd([[command! GoGenerate       :setl makeprg=go\ generate | :GoMake]])
  vim.cmd([[command! -nargs=* GoBuild :setl makeprg=go\ build | lua require'go.asyncmake'.make(<f-args>)]])
  vim.cmd([[command! -nargs=* GoRun   :setl makeprg=go\ run | lua require'go.asyncmake'.make(<f-args>)]])
  -- if you want to output to quickfix
  -- vim.cmd(
  --     [[command! -nargs=* GoTest  :setl makeprg=go\ test\ -v\ ./...| lua require'go.asyncmake'.make(<f-args>)]])

  -- example to running test in split buffer
  vim.cmd([[command! -nargs=* GoTest  :setl makeprg=go\ test\ -v\ ./...| lua require'go.runner'.make(<f-args>)]])

  vim.cmd([[command! -nargs=* GoCoverage lua require'go.coverage'.run(<f-args>)]])
  -- vim.cmd([[command! GoTestCompile  :setl makeprg=go\ build | :GoMake]])
  vim.cmd([[command! GoLint         :setl makeprg=golangci-lint\ run\ --out-format\ tab | :GoMake]])

  -- e.g. GoTestFunc unit
  vim.cmd([[command! -nargs=* GoTestFunc     lua require('go.gotest').test_fun(<f-args>)]])

  -- e.g. GoTestFile unit
  vim.cmd([[command! -nargs=* GoTestFile    lua require('go.gotest').test_file(<f-args>)]])
  vim.cmd([[command! GoAddTest      lua require("go.gotests").fun_test()]])
  vim.cmd([[command! GoAddExpTest   lua require("go.gotests").exported_test()]])
  vim.cmd([[command! GoAddAllTest   lua require("go.gotests").all_test()]])

  vim.cmd([[command! GoCodeLenAct   lua require("go.codelens").run_action()]])

  vim.cmd([[command! -nargs=* GoAddTag lua require("go.tags").add(<f-args>)]])
  vim.cmd([[command! -nargs=* GoRmTag lua require("go.tags").rm(<f-args>)]])
  vim.cmd([[command! -nargs=* GoImpl  lua require("go.impl").run(<f-args>)]])
  vim.cmd([[command! -nargs=* GoDoc   lua require("go.godoc").run(<f-args>)]])
  vim.cmd([[command!          GoClearTag lua require("go.tags").clear()]])
  vim.cmd([[command!          GoCmt lua require("go.comment").gen()]])
  vim.cmd([[command!          GoRename lua require("go.rename").run()]])
  vim.cmd([[command!          GoIfErr lua require("go.iferr").run()]])
  vim.cmd([[command!          GoFillStruct lua require("go.reftool").fillstruct()]])
  vim.cmd([[command!          GoFillSwitch lua require("go.reftool").fillswitch()]])
  vim.cmd([[command!          GoFixPlurals lua require("go.reftool").fixplurals()]])

  vim.cmd([[command! -bang    GoAlt lua require"go.alternate".switch("<bang>"=="!", '')]])
  vim.cmd([[command! -bang    GoAltV lua require"go.alternate".switch("<bang>"=="!", 'vsplit')]])
  vim.cmd([[command! -bang    GoAltS lua require"go.alternate".switch("<bang>"=="!", 'split')]])
  vim.cmd("au FileType go au QuickFixCmdPost  [^l]* nested cwindow")
  vim.cmd("au FileType go au QuickFixCmdPost    l* nested lwindow")

  if _GO_NVIM_CFG.dap_debug then
    dap_config()
    vim.cmd([[command! -nargs=*  GoDebug lua require"go.dap".run(<f-args>)]])
    vim.cmd([[command!           GoBreakToggle lua require"go.dap".breakpt()]])
    vim.cmd([[command! BreakCondition lua require"dap".set_breakpoint(vim.fn.input("Breakpoint condition: "))]])

    vim.cmd([[command! ReplRun lua require"dap".repl.run_last()]])
    vim.cmd([[command! ReplToggle lua require"dap".repl.toggle()]])
    vim.cmd([[command! ReplOpen  lua require"dap".repl.open(), 'split']])
    vim.cmd([[command! DapRerun lua require'dap'.disconnect();require'dap'.close();require'dap'.run_last()]])

    vim.cmd([[command! GoDbgStop lua require'go.dap'.stop()]])

  end

  if _GO_NVIM_CFG.lsp_cfg then
    require'go.lsp'.setup()
    if _GO_NVIM_CFG.lsp_diag_hdlr then
      require 'go.lsp_diag'
    end
  end
  require('go.coverage').highlight()
  if _GO_NVIM_CFG.lsp_codelens then
    require'go.codelens'.setup()
  end

  -- TODO remove in future
  vim.cmd([[command! Gofmt echo 'use GoFmt']])
  vim.cmd([[command! -nargs=* Goimport echo 'use GoImport']])
end
return go
