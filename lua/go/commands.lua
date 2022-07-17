local create_cmd = vim.api.nvim_create_user_command

local dap_config = function()
  vim.cmd([[command! BreakCondition lua require"dap".set_breakpoint(vfn.input("Breakpoint condition: "))]])

  vim.cmd([[command! ReplRun lua require"dap".repl.run_last()]])
  vim.cmd([[command! ReplToggle lua require"dap".repl.toggle()]])
  vim.cmd([[command! ReplOpen  lua require"dap".repl.open(), 'split']])
  vim.cmd([[command! DapRerun lua require'dap'.disconnect();require'dap'.close();require'dap'.run_last()]])

  vim.cmd([[command! DapStop lua require'go.dap'.stop()]])
end

return {
  add_cmds = function()
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
    end
    create_cmd("GoMockGen", require("go.mockgen").run, {
      nargs = "*",
      -- bang = true,
      complete = function(ArgLead, CmdLine, CursorPos)
        -- return completion candidates as a list-like table
        return { "-p", "-d", "-i", "-s" }
      end,
    })
  end,
}
