-- some of commands extracted from gopher.vim
local go = {}
_GO_NVIM_CFG = {
  goimport = "gopls", -- if set to 'gopls' will use gopls format, also goimport
  fillstruct = "gopls",
  gofmt = "gofumpt", -- if set to gopls will use gopls format
  max_line_len = 120,
  tag_transform = false,
  test_dir = "",
  comment_placeholder = "   ",
  icons = { breakpoint = "🧘", currentpos = "🏃" },
  verbose = false,
  log_path = vim.fn.expand("$HOME") .. "/tmp/gonvim.log",
  lsp_cfg = false, -- false: do nothing
                   -- true: apply non-default gopls setup defined in go/lsp.lua
                   -- if lsp_cfg is a table, merge table with with non-default gopls setup in go/lsp.lua, e.g.
  lsp_gofumpt = false, -- true: set default gofmt in gopls format to gofumpt
  lsp_on_attach = nil, -- nil: use on_attach function defined in go/lsp.lua for gopls,
                       --      when lsp_cfg is true
                       -- if lsp_on_attach is a function: use this function as on_attach function for gopls,
                       --                                 when lsp_cfg is true
  lsp_diag_hdlr = true, -- hook lsp diag handler
  lsp_codelens = true,
  gopls_remote_auto = true,
  gocoverage_sign = "█",
  gocoverage_sign_priority = 5,
  dap_debug = true,
  textobjects = true,
  dap_debug_gui = true,
  dap_vt = true, -- false, true and 'all frames'
  gopls_cmd = nil, --- you can provide gopls path and cmd if it not in PATH, e.g. cmd = {  "/home/ray/.local/nvim/data/lspinstall/go/gopls" }
  build_tags = "", --- you can provide extra build tags for tests or debugger
  test_runner = "go", -- richgo, go test, richgo, dlv, ginkgo
  run_in_floaterm = false, -- set to true to run in float window.
}

local dap_config = function()
  vim.cmd([[command! BreakCondition lua require"dap".set_breakpoint(vim.fn.input("Breakpoint condition: "))]])

  vim.cmd([[command! ReplRun lua require"dap".repl.run_last()]])
  vim.cmd([[command! ReplToggle lua require"dap".repl.toggle()]])
  vim.cmd([[command! ReplOpen  lua require"dap".repl.open(), 'split']])
  vim.cmd([[command! DapRerun lua require'dap'.disconnect();require'dap'.close();require'dap'.run_last()]])

  vim.cmd([[command! DapStop lua require'go.dap'.stop()]])
end

function go.setup(cfg)
  cfg = cfg or {}
  if cfg.max_len then
    print("go.nvim max_len renamed to max_line_len")
  end
  _GO_NVIM_CFG = vim.tbl_extend("force", _GO_NVIM_CFG, cfg)

  vim.cmd([[autocmd FileType go setlocal omnifunc=v:lua.vim.lsp.omnifunc]])

  vim.cmd([[command! GoMake silent lua require'go.asyncmake'.make()]])

  vim.cmd([[command! GoFmt lua require("go.format").gofmt()]])
  vim.cmd([[command! -nargs=* GoImport lua require("go.format").goimport(<f-args>)]])

  vim.cmd([[command! GoGenerate       :setl makeprg=go\ generate | :GoMake]])
  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoBuild :setl makeprg=go\ build | lua require'go.asyncmake'.make(<f-args>)]]
  )

  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoVet :setl makeprg=go\ vet | lua require'go.asyncmake'.make(<f-args>)]]
  )
  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoRun   :setl makeprg=go\ run | lua require'go.asyncmake'.make(<f-args>)]]
  )
  -- if you want to output to quickfix
  -- vim.cmd(
  --     [[command! -nargs=* GoTest  :setl makeprg=go\ test\ -v\ ./...| lua require'go.asyncmake'.make(<f-args>)]])

  local sep = require("go.utils").sep()
  -- example to running test in split buffer
  -- vim.cmd(
  --     [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoTest  :setl makeprg=go\ test\ -v\ | lua require'go.runner'.make(<f-args>)]])

  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoTest lua require('go.gotest').test(<f-args>)]]
  )

  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoCoverage lua require'go.coverage'.run(<f-args>)]]
  )
  -- vim.cmd([[command! GoTestCompile  :setl makeprg=go\ build | :GoMake]])
  --print-issued-lines=false
  vim.cmd(
    [[command! GoLint         :setl makeprg=golangci-lint\ run\ --print-issued-lines=false\ --exclude-use-default=false | :GoMake]]
  )

  -- e.g. GoTestFunc unit
  vim.cmd([[command! -nargs=* GoTestFunc     lua require('go.gotest').test_fun(<f-args>)]])

  -- e.g. GoTestFile unit
  vim.cmd([[command! -nargs=* GoTestFile    lua require('go.gotest').test_file(<f-args>)]])
  vim.cmd([[command! -nargs=* GoTestPkg    lua require('go.gotest').test_package(<f-args>)]])
  vim.cmd([[command! GoAddTest      lua require("go.gotests").fun_test()]])
  vim.cmd([[command! GoAddExpTest   lua require("go.gotests").exported_test()]])
  vim.cmd([[command! GoAddAllTest   lua require("go.gotests").all_test()]])

  vim.cmd([[command! GoCodeLenAct   lua require("go.codelens").run_action()]])
  vim.cmd([[command! GoCodeAction   lua require("go.codeaction").run_action()]])

  vim.cmd([[command! -nargs=* GoAddTag lua require("go.tags").add(<f-args>)]])
  vim.cmd([[command! -nargs=* GoRmTag lua require("go.tags").rm(<f-args>)]])
  vim.cmd([[command! -nargs=* GoImpl  lua require("go.impl").run(<f-args>)]])
  vim.cmd([[command! -nargs=* GoDoc   lua require("go.godoc").run(<f-args>)]])

  vim.cmd(
    [[command! -nargs=+ -complete=custom,v:lua.package.loaded.go.doc_complete GoDoc lua require'go.godoc'.run('doc', {<f-args>})]]
  )

  vim.cmd(
    [[command! -nargs=+ -complete=custom,v:lua.package.loaded.go.tools_complete GoInstallBinary lua require'go.install'.install(<f-args>)]]
  )

  vim.cmd(
    [[command! -nargs=+ -complete=custom,v:lua.package.loaded.go.tools_complete GoUpdateBinary lua require'go.install'.update(<f-args>)]]
  )

  vim.cmd([[command! GoInstallBinaries lua require'go.install'.install_all()]])
  vim.cmd([[command! GoUpdateBinaries lua require'go.install'.update_all()]])

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

  vim.cmd([[command! -bang    GoModTidy lua require"go.gopls".tidy()]])

  if _GO_NVIM_CFG.dap_debug then
    dap_config()
    vim.cmd(
      [[command! -nargs=*  -complete=custom,v:lua.package.loaded.go.dbg_complete  GoDebug lua require"go.dap".run(<f-args>)]]
    )
    vim.cmd([[command!           GoBreakToggle lua require"go.dap".breakpt()]])
    vim.cmd([[command! BreakCondition lua require"dap".set_breakpoint(vim.fn.input("Breakpoint condition: "))]])

    vim.cmd([[command! ReplRun lua require"dap".repl.run_last()]])
    vim.cmd([[command! ReplToggle lua require"dap".repl.toggle()]])
    vim.cmd([[command! ReplOpen  lua require"dap".repl.open(), 'split']])
    vim.cmd([[command! DapRerun lua require'dap'.disconnect();require'dap'.close();require'dap'.run_last()]])
    vim.cmd([[command! DapUiFloat lua require("dapui").float_element()]])
    vim.cmd([[command! DapUiToggle lua require("dapui").toggle()]])

    vim.cmd([[command! GoDbgStop lua require'go.dap'.stop()]])
  end

  if _GO_NVIM_CFG.lsp_cfg then
    require("go.lsp").setup()
    if _GO_NVIM_CFG.lsp_diag_hdlr then
      require("go.lsp_diag")
    end
  elseif not _GO_NVIM_CFG.lsp_cfg and _GO_NVIM_CFG.lsp_on_attach then
    vim.notify('lsp_on_attach ignored, because lsp_cfg is false', vim.lsp.log_levels.WARN)
  end
  require("go.coverage").highlight()
  if _GO_NVIM_CFG.lsp_codelens then
    require("go.codelens").setup()
  end

  if _GO_NVIM_CFG.textobjects then
    require('go.ts.textobjects').setup()
  end
  -- TODO remove in future
  vim.cmd([[command! Gofmt echo 'use GoFmt']])
  vim.cmd([[command! -nargs=* Goimport echo 'use GoImport']])
end

go.doc_complete = require("go.godoc").doc_complete
go.package_complete = require("go.package").complete

go.set_test_runner = function(runner)
  --  richgo, go test, richgo, dlv, ginkgo
  local runners = { "richgo", "go", "richgo", "ginkgo" } --  dlv
  for _, v in pairs(runners) do
    if v == runner then
      _GO_NVIM_CFG.test_runner = runner
      return
    end
  end
  print("runner not supported " .. runner)
end

go.dbg_complete = function(arglead, cmdline, cursorpos)
  --  richgo, go test, richgo, dlv, ginkgo
  local testopts = { "test", "nearest", "file", "stop", "restart" }
  return table.concat(testopts, "\n")
end

go.tools_complete = function(arglead, cmdline, cursorpos)
  local gotools = require("go.install").gotools
  table.sort(gotools)
  return table.concat(gotools, "\n")
end

return go
