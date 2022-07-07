-- some of commands extracted from gopher.vim
local go = {}
local vfn = vim.fn
local create_cmd = vim.api.nvim_create_user_command

-- Keep this in sync with README.md
-- Keep this in sync with doc/go.txt
_GO_NVIM_CFG = {
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
  lsp_format_on_save = 1,
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
  lsp_diag_update_in_insert = false,
  lsp_fmt_async = false, -- async lsp.buf.format
  go_boilplater_url = "https://github.com/thockin/go-build-template.git",
  gopls_cmd = nil, --- you can provide gopls path and cmd if it not in PATH, e.g. cmd = {  "/home/ray/.local/nvim/data/lspinstall/go/gopls" }
  gopls_remote_auto = true,
  gocoverage_sign = "█",
  gocoverage_sign_priority = 5,
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
  test_efm = false, -- errorfomat for quickfix, default mix mode, set to true will be efm only

  username = "",
  useremail = "",
}

local dap_config = function()
  vim.cmd([[command! BreakCondition lua require"dap".set_breakpoint(vfn.input("Breakpoint condition: "))]])

  vim.cmd([[command! ReplRun lua require"dap".repl.run_last()]])
  vim.cmd([[command! ReplToggle lua require"dap".repl.toggle()]])
  vim.cmd([[command! ReplOpen  lua require"dap".repl.open(), 'split']])
  vim.cmd([[command! DapRerun lua require'dap'.disconnect();require'dap'.close();require'dap'.run_last()]])

  vim.cmd([[command! DapStop lua require'go.dap'.stop()]])
end

-- TODO: nvim_{add,del}_user_command  https://github.com/neovim/neovim/pull/16752

function go.setup(cfg)
  cfg = cfg or {}
  if cfg.max_len then
    vim.notify("go.nvim max_len renamed to max_line_len", vim.lsp.log_levels.WARN)
  end
  _GO_NVIM_CFG = vim.tbl_extend("force", _GO_NVIM_CFG, cfg)

  vim.cmd([[autocmd FileType go setlocal omnifunc=v:lua.vim.lsp.omnifunc]])

  vim.cmd([[command! GoMake silent lua require'go.asyncmake'.make()]])

  vim.cmd([[command!  -nargs=* GoFmt lua require("go.format").gofmt({<f-args>})]])

  vim.cmd(
    [[command! -nargs=*  -complete=custom,v:lua.package.loaded.go.doc_complete  GoImport lua require("go.format").goimport(<f-args>)]]
  )

  vim.cmd([[command! -nargs=* GoGet lua require'go.goget'.run({<f-args>})]])
  local gobin = _GO_NVIM_CFG.go
  local cmd = string.format([[command! GoGenerate       :setl makeprg=%s\ generate | :GoMake]], gobin)
  vim.cmd(cmd)
  cmd = string.format(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoBuild :setl makeprg=%s\ build | lua require'go.asyncmake'.make(<f-args>)]],
    gobin
  )
  vim.cmd(cmd)
  cmd = string.format(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoVet :setl makeprg=%s\ vet | lua require'go.asyncmake'.make(<f-args>)]],
    gobin
  )
  vim.cmd(cmd)
  cmd = string.format(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoRun   :setl makeprg=%s\ run | lua require'go.asyncmake'.make(<f-args>)]],
    gobin
  )
  vim.cmd(cmd)

  vim.cmd([[command! -nargs=* GoStop lua require("go.asyncmake").stopjob(<f-args>)]])
  -- if you want to output to quickfix

  -- example to running test in split buffer
  -- vim.cmd(
  --     [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoTest  :setl makeprg=go\ test\ -v\ | lua require'go.runner'.make(<f-args>)]])

  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoTest lua require('go.gotest').test(<f-args>)]]
  )

  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoCoverage lua require'go.coverage'.run(<f-args>)]]
  )

  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoPkgOutline lua require'go.package'.outline(<f-args>)]]
  )
  -- vim.cmd([[command! GoTestCompile  :setl makeprg=go\ build | :GoMake]])
  --print-issued-lines=false
  vim.cmd(
    [[command! GoLint         :setl makeprg=golangci-lint\ run\ --print-issued-lines=false\ --exclude-use-default=false | :GoMake]]
  )

  vim.cmd([[command! -nargs=* GoProject    lua require('go.project').setup(<f-args>)]])
  vim.cmd([[command! -nargs=* GoCheat      lua require('go.chtsh').run(<f-args>)]])
  -- e.g. GoTestFunc unit
  vim.cmd([[command! -nargs=* GoTestFunc   lua require('go.gotest').test_func(<f-args>)]])

  -- e.g. GoTestFile unit
  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoTestFile lua require('go.gotest').test_file(<f-args>)]]
  )
  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoTestPkg lua require('go.gotest').test_package(<f-args>)]]
  )
  vim.cmd([[command! -nargs=* GoAddTest      lua require("go.gotests").fun_test(<f-args>)]])
  vim.cmd([[command! -nargs=* GoAddExpTest   lua require("go.gotests").exported_test(<f-args>)]])
  vim.cmd([[command! -nargs=* GoAddAllTest   lua require("go.gotests").all_test(<f-args>)]])
  vim.cmd([[command! -nargs=* GoModVendor   lua require("go.mod").run('vendor')]])
  vim.cmd([[command! -nargs=* GoModInit lua require"go.mod".run('init')]])
  vim.cmd([[command! -nargs=* GoEnv lua require"go.env".load_env(<f-args>)]])

  vim.cmd([[command! GoCodeLenAct   lua require("go.codelens").run_action()]])
  vim.cmd([[command! GoCodeAction   lua require("go.codeaction").run_action()]])

  vim.cmd(
    [[command! -nargs=*  -complete=custom,v:lua.package.loaded.go.modify_tags_complete GoModifyTag lua require("go.tags").modify(<f-args>)]]
  )
  vim.cmd(
    [[command! -nargs=*  -complete=custom,v:lua.package.loaded.go.add_tags_complete  GoAddTag lua require("go.tags").add(<f-args>)]]
  )
  vim.cmd([[command! -nargs=* GoRmTag lua require("go.tags").rm(<f-args>)]])
  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.impl_complete GoImpl  lua require("go.impl").run(<f-args>)]]
  )

  vim.cmd(
    [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.doc_complete GoDoc lua require'go.godoc'.run('doc', {<f-args>})]]
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
  vim.cmd([[command!          GoRename lua require("go.rename").lsprename()]])
  vim.cmd([[command!          GoIfErr lua require("go.iferr").run()]])
  vim.cmd([[command!          GoFillStruct lua require("go.reftool").fillstruct()]])
  vim.cmd([[command!          GoFillSwitch lua require("go.reftool").fillswitch()]])
  vim.cmd([[command!          GoFixPlurals lua require("go.fixplurals").fixplurals()]])

  vim.cmd([[command! -bang    GoAlt lua require"go.alternate".switch("<bang>"=="!", '')]])
  vim.cmd([[command! -bang    GoAltV lua require"go.alternate".switch("<bang>"=="!", 'vsplit')]])
  vim.cmd([[command! -bang    GoAltS lua require"go.alternate".switch("<bang>"=="!", 'split')]])
  vim.cmd("au FileType go au QuickFixCmdPost  [^l]* nested cwindow")
  vim.cmd("au FileType go au QuickFixCmdPost    l* nested lwindow")

  vim.cmd([[command! -bang    GoModTidy lua require"go.gopls".tidy()]])
  vim.cmd([[command! -bang    GoListImports lua print(vim.inspect(require"go.gopls".list_imports()))]])

  vim.cmd([[command! -bang    GoCallstack lua require"go.guru".callstack(-1)]])
  vim.cmd([[command! -bang    GoChannel lua require"go.guru".channel_peers(-1)]])



  if _GO_NVIM_CFG.dap_debug then
    dap_config()
    vim.cmd(
      [[command! -nargs=*  -complete=custom,v:lua.package.loaded.go.dbg_complete  GoDebug lua require"go.dap".run(<f-args>)]]
    )
    vim.cmd([[command! GoCreateLaunch lua require"go.launch".config()]])
    vim.cmd([[command! GoBreakSave lua require"go.dap".save_brks()]])
    vim.cmd([[command! GoBreakLoad lua require"go.dap".load_brks()]])

    vim.cmd([[command! GoDbgConfig lua require"go.launch".config()]])
    vim.cmd([[command! GoBreakToggle lua require"go.dap".breakpt()]])
    vim.cmd([[command! GoDbgKeys lua require"go.dap".debug_keys()]])
    vim.cmd([[command! BreakCondition lua require"dap".set_breakpoint(vfn.input("Breakpoint condition: "))]])
    vim.cmd([[command! ReplRun lua require"dap".repl.run_last()]])
    vim.cmd([[command! ReplToggle lua require"dap".repl.toggle()]])
    vim.cmd([[command! ReplOpen  lua require"dap".repl.open(), 'split']])
    vim.cmd([[command! DapRerun lua require'dap'.disconnect();require'dap'.close();require'dap'.run_last()]])
    vim.cmd([[command! DapUiFloat lua require("dapui").float_element()]])
    vim.cmd([[command! DapUiToggle lua require("dapui").toggle()]])

    vim.cmd([[command! GoDbgStop lua require'go.dap'.stop(true)]])
    vim.cmd([[command! GoDbgContinue lua require'dap'.continue()]])
    create_cmd('GoMockGen',
      require"go.mockgen".run,
     {
        nargs = "*",
        -- bang = true,
        complete = function(ArgLead, CmdLine, CursorPos)
            -- return completion candidates as a list-like table
            return { '-p', '-d', '-i', '-s'}
        end,
    })
  end

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
  vim.notify("runner not supported " .. runner, vim.lsp.log_levels.ERROR)
end

-- go.dbg_complete = function(arglead, cmdline, cursorpos)
go.dbg_complete = function(_, _, _)
  --  richgo, go test, richgo, dlv, ginkgo
  local testopts = { "--help", "--test", "--nearest", "--file", "--package", "--attach", "--stop", "--restart", "--breakpoint", "--tag" }
  return table.concat(testopts, "\n")
end

go.tools_complete = function(_, _, _)
  local gotools = require("go.install").gotools
  table.sort(gotools)
  return table.concat(gotools, "\n")
end

go.impl_complete = function(arglead, cmdline, cursorpos)
  -- print(table.concat(require("go.impl").complete(arglead, cmdline, cursorpos), "\n"))
  return table.concat(require("go.impl").complete(arglead, cmdline, cursorpos), "\n")

  -- local testopts = { "test", "nearest", "file", "stop", "restart" }
  -- return table.concat(testopts, "\n")
end

go.modify_tags_complete = function(_, _, _)
  local opts = {
    "-add-tags",
    "-add-options",
    "-remove-tags",
    "-remove-options",
    "-clear-tags",
    "-clear-options",
  }
  return table.concat(opts, "\n")
end

-- how to deal complete https://github.com/vim-scripts/marvim/blob/c159856871aa18fa4f3249c6aa312c52f586d1ef/plugin/marvim.vim#L259

-- go.add_tags_complete = function(arglead, line, pos)
go.add_tags_complete = function(arglead, line, _)
  -- print("lead: ",arglead, "L", line, "p" )
  local transf = { "camelcase", "snakecase", "lispcase", "pascalcase", "titlecase", "keep" }
  local ret = {}
  if #vim.split(line, "%s+") >= 2 then
    if vim.startswith("-transform", arglead) then
      return "-transform"
    end
    table.foreach(transf, function(_, tag)
      if vim.startswith(tag, arglead) then
        ret[#ret + 1] = tag
      end
    end)
    if #ret > 0 then
      return table.concat(ret, "\n")
    end
    return table.concat(transf, "\n")
  end

  local opts = {
    "json",
    "json.yml",
    "-transform",
  }
  return table.concat(opts, "\n")
end

return go
