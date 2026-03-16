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

    create_cmd('GoMake', function(_)
      require('go.asyncmake').make()
    end)

    create_cmd('GoFmt', function(opts)
      require('go.format').gofmt(unpack(opts.fargs))
    end, { nargs = '*' })

    create_cmd('GoImport', function(opts)
      vim.notify('GoImport is deprecated, use GoImports')
      require('go.format').goimports(unpack(opts.fargs))
    end, {})
    create_cmd('GoImports', function(opts)
      require('go.format').goimports(unpack(opts.fargs))
    end, {
      complete = function(a, l)
        return package.loaded.go.doc_complete(a, l)
      end,
      nargs = '*',
    })

    create_cmd('GoGet', function(opts)
      require('go.goget').run(opts.fargs)
    end, { nargs = '*' })

    create_cmd('GoTool', function(opts)
      require('go.gotool').run(opts.fargs)
    end, {

      complete = function(a, l)
        -- go tool command returns the list of sub commands
        return require('go.gotool').autocomplete(a, l)
      end,
      nargs = '*',
    })

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
    local pcmdstr = ''
    local preludes = _GO_NVIM_CFG.preludes
    local gorun_preludes = preludes.GoRun or preludes.default
    if gorun_preludes ~= nil then
      local pcmd = gorun_preludes() or {}
      if #pcmd > 0 then
        pcmdstr = table.concat(pcmd, '\\ ') .. '\\ '
      end
    end

    cmd = string.format(
      [[command! -nargs=* -complete=customlist,v:lua.package.loaded.go.package_complete GoRun   :setl makeprg=%s%s\ run | lua require'go.asyncmake'.make(<f-args>)]],
      pcmdstr,
      gobin
    )
    utils.log(cmd)
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

    create_cmd('GoPkgSymbols', function(opts)
      require('go.package').symbols()
    end, {
      complete = function(a, l)
        -- return package.loaded.go.package_complete(a, l)
        return ''
      end,
      nargs = '*',
    })
    create_cmd('GoGCDetails', function(opts)
      require('go.gopls').gc_details(unpack(opts.fargs))
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
    create_cmd('GoModDnld', function(opts)
      require('go.mod').run('download', unpack(opts.fargs))
    end, { nargs = '*' })

    create_cmd('GoModGraph', function(opts)
      require('go.mod').run('graph', unpack(opts.fargs))
    end, { nargs = '*' })
    create_cmd('GoModWhy', function(opts)
      if #opts.fargs == 0 then
        local m = require('go.mod').get_mod()
        if m then
          require('go.mod').run('why', m)
          return
        end
      end
      require('go.mod').run('why', unpack(opts.fargs))
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

    create_cmd('GoImplements', function(opts)
      vim.lsp.buf.implementation()
    end, {})

    create_cmd('GoDoc', function(opts)
      require('go.godoc').run(opts.fargs)
    end, {
      complete = function(a, l)
        return package.loaded.go.doc_complete(a, l)
      end,
      nargs = '*',
    })

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
    create_cmd('GoCmtAI', function(_)
      require('go.comment').gen_ai()
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

    create_cmd('GoWork', function(opts)
      require('go.work').run(unpack(opts.fargs))
    end, {
      nargs = '*',
      complete = function(_, _, _)
        return { 'run', 'use' }
      end,
    })
    create_cmd('GoModTidy', function(opts)
      if #opts.fargs == 0 then
        return require('go.gopls').tidy()
      end
      require('go.mod').run('tidy', unpack(opts.fargs))
    end, {
      nargs = '*',
      complete = function(a, l)
        return { '-e', '-diff', '-v', '-go', '-x', '-compat' }
      end,
    })
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
    create_cmd('Ginkgo', function(opts)
      require('go.ginkgo').run(opts.fargs)
    end, {
      nargs = '*',
      complete = function(_, _, _)
        -- return completion candidates as a list-like table
        return { 'generate', 'bootstrap', 'build', 'labels', 'run', 'watch' }
      end,
    })
    create_cmd('GinkgoFunc', function(opts)
      require('go.ginkgo').test_func(opts.fargs)
    end, {
      nargs = '*',
    })
    create_cmd('GinkgoFile', function(opts)
      require('go.ginkgo').test_file(opts.fargs)
    end, {
      nargs = '*',
    })
    create_cmd('GoToggleInlay', function(opts)
      local enabled = vim.lsp.inlay_hint.is_enabled()
      vim.lsp.inlay_hint.enable(not enabled)
    end, {
      nargs = '*',
    })

    create_cmd('GoGopls', function(opts)
      local gopls = require('go.gopls')
      local subcmd = opts.fargs[1]
      if not subcmd then
        vim.notify('Usage: GoGopls <subcommand> [json_args]', vim.log.levels.WARN)
        return
      end
      if not gopls.cmds[subcmd] then
        vim.notify('Unknown gopls subcommand: ' .. subcmd, vim.log.levels.WARN)
        return
      end
      local arg = {}
      if opts.fargs[2] then
        local json_str = table.concat(opts.fargs, ' ', 2)
        local ok, parsed = pcall(vim.json.decode, json_str)
        if ok then
          arg = parsed
        else
          -- treat remaining args as key=value pairs
          for i = 2, #opts.fargs do
            local k, v = opts.fargs[i]:match('^(.-)=(.+)$')
            if k then
              arg[k] = v
            end
          end
        end
      end
      gopls.cmds[subcmd](arg)
    end, {
      complete = function(_, _, _)
        return vim.tbl_keys(require('go.gopls').cmds)
      end,
      nargs = '+',
    })

    create_cmd('GoAI', function(opts)
      require('go.ai').run(opts)
    end, { nargs = '*',
    complete = function(_, _, _)
      return {
        '-f', -- full command catalog from go.txt
        [['test this function']],
        [['test this file']],
        [['add tags to this struct']],
        [['run AI code review']],
        [['explain this code']],
        [['refactor this code']],
        [['check for bugs']],
        [['examine error handling']],
        [['simplify this']],
        [['what does this do']],
        [['suggest improvements']],
        [['check concurrency safety']],
        [['create a commit summary']],
        [['convert to idiomatic Go']],  
      }
    end,
    range = true })

    ---@param args table the opts table passed by nvim_create_user_command
    ---@return table parsed options
    local function parse_review_args(args)
      local opts = {}
      local fargs = args.fargs or {}

      -- Check for visual range selection
      if args.range and args.range == 2 then
        opts.visual = true
        local start_line = args.line1
        local end_line = args.line2
        local bufnr = vim.api.nvim_get_current_buf()
        local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
        opts.lines = table.concat(lines, '\n')
        opts.start_line = start_line
        opts.end_line = end_line
      end

      local i = 1
      while i <= #fargs do
        local arg = fargs[i]
        if arg == '-d' or arg == '--diff' then
          opts.diff = true
          -- Next arg might be branch name
          if fargs[i + 1] and not fargs[i + 1]:match('^%-') then
            opts.branch = fargs[i + 1]
            i = i + 1
          end
        elseif arg == '-b' or arg == '--brief' then
          opts.brief = true
        elseif arg == '-f' or arg == '--full' then
          opts.full = true
        elseif arg == '-m' or arg == '--message' then
          -- Collect everything after -m as the change description
          local msg_parts = {}
          for j = i + 1, #fargs do
            table.insert(msg_parts, fargs[j])
          end
          local raw = table.concat(msg_parts, ' ')
          -- Convert literal \n sequences to real newlines
          opts.message = raw:gsub('\\n', '\n')
          break
        end
        i = i + 1
      end

      -- Default branch if diff mode but no branch specified
      if opts.diff and not opts.branch then
        opts.branch = 'master'
      end

      return opts
    end

    --- Open a floating buffer for multi-line message input using guihua textview.
    --- Falls back to a plain floating window if guihua is not available.
    --- Calls `on_submit(text)` with the buffer contents when the user submits.
    local function open_message_input(on_submit)
      local TextView = utils.load_plugin('guihua.lua', 'guihua.textview')
      if TextView then
        local width = math.min(80, vim.o.columns - 4)
        local height = math.min(10, math.floor(vim.o.lines * 0.3))
        local win = TextView:new({
          loc = 'top_center',
          rect = { height = height, width = width, pos_x = 0, pos_y = 4 },
          allow_edit = true,
          enter = true,
          ft = 'markdown',
          title = ' Change description (<C-s> submit, q cancel) ',
          title_pos = 'center',
          data = { '' },
        })
        if not win or not win.buf then
          vim.notify('[GoCodeReview]: failed to create input window', vim.log.levels.ERROR)
          return
        end

        -- Enable completion sources (Copilot, nvim-cmp) in the edit buffer
        vim.api.nvim_set_option_value('buftype', '', { buf = win.buf })
        vim.api.nvim_set_option_value('filetype', 'markdown', { buf = win.buf })
        -- Force-attach copilot if available (bypasses filetype/buftype rejection)
        local copilot_ok, copilot_cmd = pcall(require, 'copilot.command')
        if copilot_ok and copilot_cmd.attach then
          copilot_cmd.attach({ force = true, bufnr = win.buf })
        end

        local submitted = false
        local function submit()
          if submitted then return end
          submitted = true
          local lines = vim.api.nvim_buf_get_lines(win.buf, 0, -1, false)
          win:close()
          local text = vim.trim(table.concat(lines, '\n'))
          on_submit(text)
        end

        vim.keymap.set('n', '<C-s>', submit, { buffer = win.buf, silent = true })
        vim.keymap.set('n', 'q', function()
          if not submitted then
            win:close()
          end
        end, { buffer = win.buf, silent = true })
        vim.cmd('startinsert')
      else
        vim.notify('[GoCodeReview]: guihua.lua not found, failed to create input window', vim.log.levels.WARN)
      end
    end

    create_cmd('GoCodeReview', function(args)
      -- Use MCP-enhanced review when available
      local go_cfg = require('go').config() or {}

      local function do_review(extra_opts)
        if go_cfg.mcp and go_cfg.mcp.enable then
          local opts = parse_review_args(args)
          if extra_opts then opts = vim.tbl_extend('force', opts, extra_opts) end
          require('go.mcp.review').review(opts)
        else
          if extra_opts and extra_opts.message then
            -- Remove the bare -m/--message from fargs before injecting the full message
            args.fargs = args.fargs or {}
            local new_fargs = {}
            for _, a in ipairs(args.fargs) do
              if a ~= '-m' and a ~= '--message' then
                table.insert(new_fargs, a)
              end
            end
            table.insert(new_fargs, '-m')
            table.insert(new_fargs, extra_opts.message)
            args.fargs = new_fargs
          end
          require('go.ai').code_review(args)
        end
      end

      -- Check if -m is present with no text after it
      local fargs = args.fargs or {}
      local has_m, m_has_text = false, false
      for idx, a in ipairs(fargs) do
        if a == '-m' or a == '--message' then
          has_m = true
          m_has_text = (fargs[idx + 1] ~= nil and not fargs[idx + 1]:match('^%-'))
          break
        end
      end

      if has_m and not m_has_text then
        -- Open interactive buffer for multi-line input
        open_message_input(function(text)
          if text == '' then
            vim.notify('[GoCodeReview]: cancelled (empty message)', vim.log.levels.INFO)
            return
          end
          do_review({ message = text })
        end)
      else
        do_review()
      end
    end, {
      nargs = '*',
      range = true,
      complete = function(_, _, _)
        return { '-d', '--diff', '-b', '--brief', '-f', '--full', '-m', '--message' }
      end,
    })

    create_cmd('GoDocAI', function(opts)
      require('go.godoc').run_ai(opts)
    end, {
      nargs = '*',
      complete = function(a, l)
        return package.loaded.go.doc_complete(a, l)
      end,
    })
    create_cmd('GoAIChat', function(opts)
      require('go.ai').chat(opts)
    end, {
      nargs = '*',
      range = true,
      complete = function(_, _, _)
        return {
          'explain this code',
          'refactor this code',
          'check for bugs',
          'examine error handling',
          'simplify this',
          'what does this do',
          'suggest improvements',
          'check concurrency safety',
          'create a commit summary',
          'convert to idiomatic Go',
        }
      end,
    })
  end,
}
