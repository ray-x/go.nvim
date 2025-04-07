local vim, vfn = vim, vim.fn
local utils = require('go.utils')
local log = utils.log
local trace = utils.trace
local extract_filepath = utils.extract_filepath
local h = require('null-ls.helpers')
local methods = require('null-ls.methods')

local u = require('null-ls.utils')

if _GO_NVIM_CFG.null_ls_verbose then
  trace = log
end

local severities = h.diagnostics.severities --{ error = 1, warning = 2, information = 3, hint = 4 }
local function handler()
  return function(msg, done)
    local diags = {}
    trace('hdlr called', msg, done)
    if msg == nil or msg.output == nil then
      log('no output', msg)
      return
    end
    if msg.lsp_method == 'textDocument/didChange' or msg.method == 'NULL_LS_DIAGNOSTICS' then
      -- there is no need to run on didChange, has to run until fil saved
      return log('skip didChange')
    end
    if vfn.empty(msg.err) == 0 then
      log('error', msg.err)
      return
    end

    trace(msg.method)
    -- log(msg)
    local msgs = msg.output
    msgs = vim.split(msgs, '\n', true)
    trace(#msgs, msgs)
    if #msgs == 0 then
      return
    end
    local failure = {}
    if #msgs > 100 then -- lua is slow
      trace('reduce')
      local fname = vfn.expand('%:t:r')
      local reduce = {}

      for _, m in pairs(msgs) do
        local other = m:find('=== PAUSE')
        if not other then
          local f = m:find(fname)
          local n = m:find('fail') or m:find('FAIL') or m:find('panic')
          if f or n then
            table.insert(reduce, m)
          elseif n then
            table.insert(failure, 'failed:' .. m)
          end
        end
      end
      msgs = reduce
    end
    local package, filename, line
    -- the output is jsonencoded
    local output = ''

    local json_decode = vfn.json_decode

    local qf = {}
    local panic = {} -- store failed or panic info
    local test_failed = false
    local root = msg.root or msg.cwd
    for idx, m in pairs(msgs) do
      -- log(idx)
      if vfn.empty(m) == 0 then
        if m:find('--- PASS') or m:find('--- SKIP') or m:find('=== RUN') then
          output = ''
        else
          local entry = json_decode(m)
          entry = entry or {}
          trace(entry)
          if entry.Action == 'run' then
            package = entry.Package
            output = ''
          elseif entry.Action == 'output' then
            package = entry.Package
            if vfn.empty(entry.Output) == 1 or false then
              output = ''
            else
              trace(idx, entry)
              entry.Output = utils.trim(entry.Output)
              entry.Output = entry.Output:gsub('\t', '    ')
              local found = false
              local fname
              local lnum
              found, fname, lnum = extract_filepath(entry.Output, package)
              if fname then
                filename = fname
                line = lnum
              end

              if found == true then
                local pkg_path = require('go.gotest').get_test_path() .. utils.sep()
                output = pkg_path .. utils.ltrim(entry.Output)
              else -- not found or format is correct
                output = output .. (entry.Output or '')
              end
              trace(found, filename, lnum)
              if entry.Output:find('FAIL') or entry.Output:find('panic') then
                table.insert(panic, entry.Output)
              end
              trace(idx, filename, output or 'nil')
            end
          elseif entry.Action == 'pass' or entry.Action == 'skip' then
            -- log(entry)
            -- reset
            output = ''
          elseif entry.Action == 'fail' and vfn.empty(output) == 0 then
            log('action failed', idx, entry, filename)
            trace(output)
            log('test failed ', root, filename, u.path.join(root, filename))
            if filename and filename:find(vfn.expand('%:t:r')) then -- can be output from other files
              local fname = u.path.join(root, filename)
              local bufnr = vim.uri_to_bufnr(vim.uri_from_fname(fname))
              table.insert(diags, {
                bufnr = bufnr,
                file = u.path.join(root, filename),
                row = tonumber(line),
                col = 1,
                end_row = tonumber(line) + 1,
                end_col = 0,
                message = output,
                severity = _GO_NVIM_CFG.null_ls.gotest.severity or severities.warning,
                source = 'go test',
              })
            end
            local qflines = vim.split(output, '\n')
            for i, value in ipairs(qflines) do
              if vim.fn.empty(value) == 0 then
                -- local p, _ = extract_filepath(value)
                -- if p then
                --   value = pkg_path .. utils.ltrim(value)
                --   log(value)
                -- end
                qflines[i] = value
              end
            end
            -- log(qflines)
            vim.list_extend(qf, qflines)
            output = ''
          elseif entry.Action == 'fail' then -- empty output
            -- log(idx, entry)
            if #panic > 0 then
              vim.list_extend(qf, table.concat(panic, '\n'))
            end
            test_failed = true
          end
        end
      end
    end

    if #qf > 0 then
      local efm = require('go.gotest').efm()
      vfn.setqflist({}, ' ', { title = 'gotest', lines = qf, efm = efm })
      trace(qf, efm)
    end
    trace(diags)

    if #diags > 0 or test_failed then
      vim.schedule(function()
        vim.notify('go test failed: ' .. '\n please check quickfix!\n', vim.log.levels.WARN)
      end)
    end
    -- local ok, d = pcall(vfn.json_decode, msg)
    return done(diags)
  end
end

local DIAGNOSTICS_ON_SAVE = methods.internal.DIAGNOSTICS_ON_SAVE
local DIAGNOSTICS_ON_OPEN = methods.internal.DIAGNOSTICS_ON_OPEN

-- register with
-- null_ls.register(gotest)
local golangci_diags = {}
return {
  golangci_lint = function()
    golangci_diags = {}
    return h.make_builtin({
      name = 'golangci_lint',
      meta = {
        url = 'https://golangci-lint.run/',
        description = 'A Go linter aggregator.',
      },
      method = _GO_NVIM_CFG.null_ls.golangci_lint.method
          or { DIAGNOSTICS_ON_OPEN, DIAGNOSTICS_ON_SAVE },
      filetypes = { 'go' },
      generator_opts = {
        command = 'golangci-lint',
        to_stdin = true,
        from_stderr = false,
        -- ignore_stderr = true,
        async = true,
        multiple_files = true,
        format = 'raw',
        cwd = h.cache.by_bufnr(function(params)
          local ws = vim.lsp.buf.list_workspace_folders()
          if #ws > 0 then
            return ws[1]
          end
          return u.root_pattern('go.mod')(params.bufname)
        end),
        args = function()
          local trace = log
          local rfname = vfn.fnamemodify(vfn.expand('%'), ':~:.')
          trace(rfname) -- repplace $FILENAME ?
          local disable = _GO_NVIM_CFG.golangci_lint.disable or {}
          local enable = _GO_NVIM_CFG.golangci_lint.enable or {}
          local enable_only = _GO_NVIM_CFG.golangci_lint.enable_only or {}
          local enable_str = ''
          local disable_str = ''
          local enable_only_str = ''
          if #enable > 0 then
            enable_str = '--enable=' .. table.concat(enable, ',')
          end
          if #disable > 0 then
            disable_str = '--disable=' .. table.concat(disable, ',')
          end
          if #enable_only > 0 then
            enable_only_str = '--enable-only=' .. table.concat(enable_only, ',')
          end
          golangci_diags = {} -- CHECK: is here the best place to call
          local null = '/dev/null'
          if utils.is_windows() then
            null = 'NUL'
          end
          local disable_text = '--output.text.path=' .. null
          local args = { 'run', '--fix=false', '--show-stats=false', '--output.json.path=stdout', disable_text }
          if
              _GO_NVIM_CFG.null_ls.golangci_lint
              and vim.fn.empty(_GO_NVIM_CFG.null_ls.golangci_lint) == 0
          then
            if _GO_NVIM_CFG.null_ls.golangci_lint.default  then
              table.insert(args,  '--default=' .. _GO_NVIM_CFG.null_ls.golangci_lint.default)
            end

            local no_config = _GO_NVIM_CFG.null_ls.golangci_lint.no_config and '--no-config' or ''
            local config_path = _GO_NVIM_CFG.null_ls.golangci_lint.config and '--config=' .. _GO_NVIM_CFG.null_ls.golangci_lint.config or ''
            if no_config ~= '' then
              table.insert(args, no_config)
            end

            if config_path ~= '' then
              table.insert(args, config_path)
            end


            if disable_str ~= '' then
              table.insert(args, disable_str)
            end
            if enable_str ~= '' then
              table.insert(args, enable_str)
            end

            if enable_only_str ~= '' then
              table.insert(args, enable_only_str)
            end
          end
          log(args)
          return args
        end,
        check_exit_code = function(code)
          if code > 2 then
            vim.schedule(function()
              vim.notify('go lint failed, please check quickfix')
            end)
            return false
          end
          return true
        end,
        on_output = function(msg, done)
          -- lint_output is a lsp output table, bufnr, client_id, method, output, err,cwd, root, output, command, lsp_params
          -- output is what we are interested in
          if msg == nil then
            log('no golangci-lint output', done)
            return {}
          end
          local trace = log
          msg.content = {}
          trace('golangci-lint finished with code', done, msg)
          if vfn.empty(msg.err) == 0 then
            -- stderr output, might be a compile failure
            vim.schedule(function()
              vim.notify('error: ' .. msg.err, vim.log.levels.WARN)
            end)
          end

          trace(msg.method, msg.cwd, msg.lsp_params)
          local cwd = msg.root or msg.cwd
          if msg.output == nil then
            return
          end

          local m = msg.output
          if vfn.empty(m) == 1 then
            log('no output', msg)
          end

          -- the output is jsonencoded
          trace('lint message: ', m)
          local entry = vfn.json_decode(m)
          if not entry or (entry['Report'] and entry['Report']['Error']) then
            trace('report', entry['Report']['Error'])
            return golangci_diags
          end
          local issues = entry['Issues']
          for _, d in ipairs(issues) do
            trace(
              'issue pos and source ',
              d.Pos,
              d.FromLinter,
              d.Text,
              u.path.join(cwd, d.Pos.Filename)
            )
            local fname = u.path.join(cwd, d.Pos.Filename)
            local bufnr = vim.uri_to_bufnr(vim.uri_from_fname(fname))

            -- no need to show typecheck issues
            if d.Pos and d.FromLinter ~= 'typecheck' then --and d.Pos.Filename == bufname
              trace('issues', d)
              table.insert(golangci_diags, {
                source = string.format('golangci-lint:%s', d.FromLinter),
                row = d.Pos.Line,
                col = d.Pos.Column,
                end_row = d.Pos.Line,
                end_col = d.Pos.Column + 1,
                -- filename = u.path.join(cwd, d.Pos.Filename),
                bufnr = bufnr,
                message = d.Text,
                severity = _GO_NVIM_CFG.null_ls.golangci_lint.severity or severities.hint,
              })
            end
          end
          trace(golangci_diags)
          return done(golangci_diags)
        end,
      },
      factory = h.generator_factory,
    })
  end,

  gotest = function()
    local nulls = utils.load_plugin('null-ls', 'null-ls')
    if nulls == nil then
      vim.notify('failed to load null-ls', vim.log.levels.WARN)
      return
    end
    local cmd = {}

    return h.make_builtin({
      name = 'gotest',
      method = (_GO_NVIM_CFG.null_ls.gotest and _GO_NVIM_CFG.null_ls.gotest.method)
          or { DIAGNOSTICS_ON_OPEN, DIAGNOSTICS_ON_SAVE },
      filetypes = { 'go' },

      cwd = h.cache.by_bufnr(function(params)
        local ws = vim.lsp.buf.list_workspace_folders()
        if #ws > 0 then
          return ws[1]
        end
        return u.root_pattern('go.mod')(params.bufname)
      end),
      generator_opts = {
        command = 'go',
        async = true,
        args = function()
          local gt = require('go.gotest')
          local a = { 'test', '-json' }
          local tests = gt.get_test_cases()
          trace('tests', tests)

          local pkg = require('go.gotest').get_test_path()
          if vfn.empty(tests) == 1 then
            table.insert(a, pkg)
          else
            -- local sh = vim.o.shell
            table.insert(a, '-run')
            table.insert(a, tests)
            table.insert(a, pkg)
          end
          trace('opts', a)
          cmd = a
          return a
        end,
        method = _GO_NVIM_CFG.null_ls.gotest.method
            or { DIAGNOSTICS_ON_SAVE },
        format = 'raw',
        timeout = 5000,
        check_exit_code = function(code, stderr)
          local success = code < 2
          if not success then
            vim.schedule(function()
              vim.notify('go test failed: ' .. tostring(stderr), vim.log.levels.WARN)
            end)
            log('failed to run to test', code, stderr, cmd)
          end
          -- if not success then
          --   -- can be noisy for things that run often (e.g. diagnostics), but can
          --   -- be useful for things that run on demand (e.g. formatting)
          --   vim.schedule_wrap(function()
          --     vim.notify('go test failed: ' .. tostring(stderr), vim.log.levels.WARN)
          --   end)
          -- end
          return true
        end,
        on_output = handler(),
      },
      factory = h.generator_factory,
    })
  end,
  gotest_action = function()
    return {
      name = 'gotest nearest',
      meta = {
        url = 'https://github.com/ray-x/go.nvim',
        description = 'test go code',
      },
      method = require('null-ls.methods').internal.CODE_ACTION,
      filetypes = { 'go' },
      generator = {
        factory = h.generator_factory,
        fn = function(params)
          local f, _, is_test = require('go.alternate').is_test_file()
          if not is_test then
            return
          end
          local actions = {}

          local gt = require('go.gotest')
          local cb = function()
            local test_actions = gt.test_func
            if not test_actions then
              return
            end
            log('gotest action')
            test_actions()
          end

          local fname = gt.get_test_func_name()
          trace('run for ', fname)
          if fname then
            -- local mode = vim.api.nvim_get_mode().mode
            table.insert(actions, {
              title = 'gotest ' .. fname.name,
              action = function()
                vim.api.nvim_buf_call(params.bufnr, cb)
              end,
            })
          end
          return actions
        end,
      },
    }
  end,
}
