local vfn = vim.fn

local utils = require('go.utils')
local create_cmd = function(cmd, func, opt)
  if _GO_NVIM_CFG.remap_commands then
    local remap = _GO_NVIM_CFG.remap_commands
    if remap[cmd] ~= nil then
      if type(remap[cmd]) == 'string' then
        cmd = remap[cmd] -- remap
      elseif type(remap[cmd]) == 'boolean' and remap[cmd] == false then
        return -- disable
      end
    end
  end

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

    local gobin = _GO_NVIM_CFG.go
    local cmd = string.format(
      [[command! -nargs=* GoGenerate :setl makeprg=%s\ generate | lua require'go.asyncmake'.make(<f-args>)]],
      gobin
    )
    vim.cmd(cmd)

    cmd = string.format(
      [[command! -nargs=* -complete=customlist,v:lua.package.loaded.go.package_complete GoVet :setl makeprg=%s\ vet | lua require'go.asyncmake'.make(<f-args>)]],
      gobin
    )
    vim.cmd(cmd)

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

    local lint_cfg = _GO_NVIM_CFG.golangci_lint or { default = 'standard' }
    local default = [[\ --default=]] .. lint_cfg.default
    local disable = lint_cfg.disable or {}
    local enable = lint_cfg.enable or {}
    local enable_only = lint_cfg.enable_only or {}
    local enable_str = ''
    local no_config = lint_cfg.no_config and [[\ --no-config]] or ''
    local config_path = (lint_cfg.config and [[\ --config=]] .. lint_cfg.config) or ''

    local disable_str = ''
    if #enable > 0 then
      enable_str = [[\ --enable=]] .. table.concat(enable, ',')
    end
    if #disable > 0 then
      disable_str = [[\ --disable=]] .. table.concat(disable, ',')
    end
    if #enable_only > 0 then
      enable_only_str = [[\ --enable-only=]] .. table.concat(enable_only, ',')
    end

    local enable_only_str = ''
    local null = '/dev/null'

    if utils.is_windows() then
      null = 'NUL'
    end
    local cmd_str = string.format(
      [[command! -nargs=* -complete=customlist,v:lua.package.loaded.go.package_complete GoLint :setl makeprg=golangci-lint\ run\ --output.json.path=%s\ --output.text.path=stdout\ --output.text.print-issued-lines=false\ --output.text.colors=false\ --show-stats=false%s%s%s%s%s%s | :GoMake ]],
      null,
      default,
      config_path,
      no_config,
      disable_str,
      enable_str,
      enable_only_str
    )
    vim.cmd(cmd_str)

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


    create_cmd('GoCodeLenAct', function(_)
      require('go.codelens').run_action()
    end)
    create_cmd('GoCodeAction', function(t)
      require('go.codeaction').run_code_action(t)
    end, { range = true })

    create_cmd('GoModifyTag', function(opts)
      require('go.tags').modify(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.modify_tags_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('GoImplements', function(opts)
      vim.lsp.buf.implementation()
    end, {})

    create_cmd('GoDocBrowser', function(opts)
      require('go.gopls').doc(opts.fargs)
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

    create_cmd('GoFillSwitch', function(_)
      require('go.reftool').fillswitch()
    end)
    create_cmd('GoFixPlurals', function(_)
      require('go.fixplurals').fixplurals()
    end)

    create_cmd('GoListImports', function(_)
      local lines = require('go.gopls').list_imports().PackageImports or {}

      local close_events = { 'CursorMoved', 'CursorMovedI', 'BufHidden', 'InsertCharPre' }
      local config = {
        close_events = close_events,
        focusable = true,
        border = 'single',
        width = 80,
        zindex = 100,
        height = #lines,
      }
      vim.lsp.util.open_floating_preview(lines, 'go', config)
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

    create_cmd('GoGenReturn', function()
      require('go.lsp').hover_returns()
    end)

    create_cmd('GoVulnCheck', function(opts)
      require('go.govulncheck').run(opts.fargs)
    end, { nargs = '*' })
    create_cmd('GoEnum', function(opts)
      require('go.enum').run(unpack(opts.fargs))
    end, { nargs = '*' })
    create_cmd('GoNew', function(opts)
      require('go.template.gonew').new(opts.fargs)
    end, {
      nargs = '*',
      complete = function(_, _, _)
        -- return completion candidates as a list-like table
        return require('go.template.gonew').complete
      end,
    })

    create_cmd('GoToggleInlay', function(opts)
      local enabled = vim.lsp.inlay_hint.is_enabled()
      vim.lsp.inlay_hint.enable(not enabled)
    end, {
      nargs = '*',
    })
  end,
}
