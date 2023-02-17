local vfn = vim.fn

local utils = require('go.utils')
local create_cmd = function(cmd, func, opt)
  opt = vim.tbl_extend('force', { desc = 'go.nvim ' .. cmd }, opt or {})
  vim.api.nvim_create_user_command(cmd, func, opt)
end

local dap_config = function()
  create_cmd('BreakCondition', function(_)
    local dap = utils.load_plugin('nvim-dap', 'dap')
    if not dap then
      return
    end
    dap.set_breakpoint(vfn.input('Breakpoint condition: '))
  end)
  create_cmd('LogPoint', function(_)
    local dap = utils.load_plugin('nvim-dap', 'dap')
    if not dap then
      return
    end
    dap.set_breakpoint(nil, nil, vfn.input('Log message: '))
  end)

  create_cmd('ReplRun', function(_)
    local dap = utils.load_plugin('nvim-dap', 'dap')
    if not dap then
      return
    end
    dap.repl.run_last()
  end)
  create_cmd('ReplToggle', function(_)
    local dap = utils.load_plugin('nvim-dap', 'dap')
    if not dap then
      return
    end
    dap.repl.toggle()
  end)
  create_cmd('ReplOpen', function(_)
    local dap = utils.load_plugin('nvim-dap', 'dap')
    if not dap then
      return
    end
    dap.repl.open()
    vim.cmd('split')
  end)
  create_cmd('DapRerun', function(_)
    local dap = utils.load_plugin('nvim-dap', 'dap')
    if not dap then
      return
    end
    dap.disconnect()
    dap.close()
    dap.run_last()
  end)
  local gdap = require('go.dap')
  create_cmd('GoDebug', function(opts)
    local dap = utils.load_plugin('nvim-dap', 'dap')
    if not dap then
      return
    end
    gdap.run(unpack(opts.fargs))
  end, {
    complete = function(a, l)
      return package.loaded.go.dbg_complete(a, l)
    end,
    nargs = '*',
  })
  create_cmd('GoCreateLaunch', function(_)
    require('go.launch').config()
  end)

  create_cmd('GoBreakSave', function(_)
    gdap.save_brks()
  end)
  create_cmd('GoBreakLoad', function(_)
    local dap = utils.load_plugin('nvim-dap', 'dap')
    if not dap then
      return
    end
    gdap.load_brks()
  end)

  create_cmd('DapStop', function(_)
    require('go.dap').stop()
  end)
  create_cmd('GoDbgConfig', function(_)
    require('go.launch').config()
  end)
  create_cmd('GoBreakToggle', function(_)
    local dap = utils.load_plugin('nvim-dap', 'dap')
    if not dap then
      return
    end
    gdap.breakpt()
  end)
  create_cmd('GoDbgKeys', function(_)
    gdap.debug_keys()
  end)
  create_cmd('DapUiFloat', function(_)
    require('dapui').float_element()
  end)
  create_cmd('DapUiToggle', function(_)
    require('dapui').toggle()
  end)

  create_cmd('GoDbgStop', function(_)
    gdap.stop(true)
  end)
  create_cmd('GoDbgContinue', function(_)
    local dap = utils.load_plugin('nvim-dap', 'dap')
    if not dap then
      return
    end
    dap.continue()
  end)
end

return {
  add_cmds = function()
    vim.cmd([[
    augroup go.filetype
    autocmd!
      autocmd FileType go setlocal omnifunc=v:lua.vim.lsp.omnifunc
      autocmd FileType go au QuickFixCmdPost  [^l]* nested cwindow
      autocmd FileType go au QuickFixCmdPost    l* nested lwindow
    augroup end
    ]])

    create_cmd('GoMake', function(_)
      require('go.asyncmake').make()
    end)

    create_cmd('GoFmt', function(opts)
      require('go.format').gofmt(unpack(opts.fargs))
    end, { nargs = '*' })

    create_cmd('GoImport', function(opts)
      require('go.format').goimport(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.doc_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('GoGet', function(opts)
      require('go.goget').run(opts.fargs)
    end, { nargs = '*' })

    local gobin = _GO_NVIM_CFG.go
    local cmd = string.format(
      [[command! -nargs=* GoGenerate :setl makeprg=%s\ generate | lua require'go.asyncmake'.make(<f-args>)]],
      gobin
    )
    vim.cmd(cmd)

    cmd = string.format(
      [[command! -nargs=* -complete=customlist,v:lua.package.loaded.go.package_complete GoBuild :setl makeprg=%s\ build | lua require'go.asyncmake'.make(<f-args>)]],
      gobin
    )
    vim.cmd(cmd)

    cmd = string.format(
      [[command! -nargs=* -complete=customlist,v:lua.package.loaded.go.package_complete GoVet :setl makeprg=%s\ vet | lua require'go.asyncmake'.make(<f-args>)]],
      gobin
    )
    vim.cmd(cmd)

    cmd = string.format(
      [[command! -nargs=* -complete=customlist,v:lua.package.loaded.go.package_complete GoRun   :setl makeprg=%s\ run | lua require'go.asyncmake'.make(<f-args>)]],
      gobin
    )
    vim.cmd(cmd)

    create_cmd('GoStop', function(opts)
      require('go.asyncmake').stopjob(unpack(opts.fargs))
    end, { nargs = '*' })
    -- if you want to output to quickfix

    -- example to running test in split buffer
    -- vim.cmd(
    --     [[command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoTest  :setl makeprg=go\ test\ -v\ | lua require'go.runner'.make(<f-args>)]])

    create_cmd('GoTest', function(opts)
      require('go.gotest').test(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.package_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('GoTestSum', function(opts)
      if opts.fargs[1] == '-w' then
        return require('go.gotestsum').watch()
      end
      require('go.gotestsum').run(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.package_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('GoCoverage', function(opts)
      require('go.coverage').run(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.package_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('GoPkgOutline', function(opts)
      require('go.package').outline(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.package_complete(a, l)
      end,
      nargs = '*',
    })

    -- vim.cmd([[command! GoTestCompile  :setl makeprg=go\ build | :GoMake]])
    --print-issued-lines=false

    vim.cmd(
      [[command! GoLint         :setl makeprg=golangci-lint\ run\ --print-issued-lines=false\ --exclude-use-default=false | :GoMake]]
    )

    create_cmd('GoProject', function(opts)
      require('go.project').setup()
    end)
    create_cmd('GoCheat', function(opts)
      require('go.chtsh').run(unpack(opts.fargs))
    end, { nargs = '*' })
    -- e.g. GoTestFunc unit
    create_cmd('GoTestFunc', function(opts)
      require('go.gotest').test_func(unpack(opts.fargs))
    end, { nargs = '*' })

    create_cmd('GoTestSubCase', function(opts)
      require('go.gotest').test_tblcase(unpack(opts.fargs))
    end, { nargs = '*' })
    -- e.g. GoTestFile unit
    --  command! -nargs=* -complete=custom,v:lua.package.loaded.go.package_complete GoTestFile lua require('go.gotest').test_file(<f-args>)

    create_cmd('GoTestFile', function(opts)
      require('go.gotest').test_file(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.package_complete(a, l)
      end,
      nargs = '*',
    })
    create_cmd('GoTestPkg', function(opts)
      require('go.gotest').test_package(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.package_complete(a, l)
      end,
      nargs = '*',
    })
    create_cmd('GoAddTest', function(opts)
      require('go.gotests').fun_test(unpack(opts.fargs))
    end)
    create_cmd('GoAddExpTest', function(opts)
      require('go.gotests').exported_test(unpack(opts.fargs))
    end, { nargs = '*' })
    create_cmd('GoAddAllTest', function(opts)
      require('go.gotests').all_test(unpack(opts.fargs))
    end, { nargs = '*' })
    create_cmd('GoModVendor', function(opts)
      require('go.mod').run('vendor', unpack(opts.fargs))
    end, { nargs = '*' })
    create_cmd('GoModInit', function(opts)
      require('go.mod').run('init', unpack(opts.fargs))
    end, { nargs = '*' })
    create_cmd('GoEnv', function(opts)
      require('go.env').load_env(unpack(opts.fargs))
    end, { nargs = '*' })

    create_cmd('GoCodeLenAct', function(_)
      require('go.codelens').run_action()
    end)
    create_cmd('GoCodeAction', function(t)
      if t.range ~= 0 then
        require('go.codeaction').run_range_code_action({ t.line1, t.line2 })
      else
        require('go.codeaction').run_code_action()
      end
    end, { range = true })

    create_cmd('GoModifyTag', function(opts)
      require('go.tags').modify(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.modify_tags_complete(a, l)
      end,
      nargs = '*',
    })
    create_cmd('GoAddTag', function(opts)
      require('go.tags').add(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.add_tags_complete(a, l)
      end,
      nargs = '*',
    })
    create_cmd('GoRmTag', function(opts)
      require('go.tags').rm(unpack(opts.fargs))
    end, { nargs = '*' })
    create_cmd('GoImpl', function(opts)
      require('go.impl').run(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.impl_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('GoDoc', function(opts)
      require('go.godoc').run(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.doc_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('GoInstallBinary', function(opts)
      require('go.install').install(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.tools_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('GoUpdateBinary', function(opts)
      require('go.install').update(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.tools_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('GoInstallBinaries', function(_)
      require('go.install').install_all()
    end)
    create_cmd('GoUpdateBinaries', function(_)
      require('go.install').update_all()
    end)

    create_cmd('GoClearTag', function(_)
      require('go.tags').clear()
    end)
    create_cmd('GoCmt', function(_)
      require('go.comment').gen()
    end)
    create_cmd('GoRename', function(_)
      require('go.rename').lsprename()
    end)
    create_cmd('GoIfErr', function(_)
      require('go.iferr').run()
    end)
    create_cmd('GoFillStruct', function(_)
      require('go.reftool').fillstruct()
    end)
    create_cmd('GoFillSwitch', function(_)
      require('go.reftool').fillswitch()
    end)
    create_cmd('GoFixPlurals', function(_)
      require('go.fixplurals').fixplurals()
    end)

    create_cmd('GoAlt', function(opts)
      require('go.alternate').switch(opts.bang, '')
    end, { bang = true })
    create_cmd('GoAltV', function(opts)
      require('go.alternate').switch(opts.bang, 'vsplit')
    end, { bang = true })
    create_cmd('GoAltS', function(opts)
      require('go.alternate').switch(opts.bang, 'split')
    end, { bang = true })

    create_cmd('GoModTidy', function(_)
      require('go.gopls').tidy()
    end)
    create_cmd('GoListImports', function(_)
      print(vim.inspect(require('go.gopls').list_imports()))
    end)

    create_cmd('GoCallstack', function(_)
      require('go.guru').callstack(-1)
    end)
    create_cmd('GoChannel', function(_)
      require('go.guru').channel_peers(-1)
    end)

    if _GO_NVIM_CFG.dap_debug then
      dap_config()
    end
    create_cmd('GoMockGen', require('go.mockgen').run, {
      nargs = '*',
      -- bang = true,
      complete = function(_, _, _)
        -- return completion candidates as a list-like table
        return { '-p', '-d', '-i', '-s' }
      end,
    })

    create_cmd('GoEnv', function(opts)
      require('go.env').load_env(unpack(opts.fargs))
    end, { nargs = '*' })

    create_cmd('GoGenReturn', function()
      require('go.lsp').hover_returns()
    end)

    create_cmd('GoJson2Struct', function(opts)
      require('go.json2struct').run(opts)
    end, {
      nargs = '*',
      bang = true,
      register = true,
      -- complete = function(ArgLead, CmdLine, CursorPos)
      complete = function(_, _, _)
        return { 'myStruct' }
      end,
      range = true,
    })

    create_cmd('Gomvp', function(opts)
      require('go.gomvp').run(opts.fargs)
    end, {
      complete = function(a, l)
        return package.loaded.go.package_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('Govulnckeck', function(opts)
      require('go.govulncheck').run(opts.fargs)
    end, { nargs = '*' })
    create_cmd('GoEnum', function(opts)
      require('go.enum').run(unpack(opts.fargs))
    end, { nargs = '*' })
  end,
}
