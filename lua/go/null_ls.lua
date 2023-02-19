local vim, vfn = vim, vim.fn
local utils = require('go.utils')
local log = utils.log

local extract_filepath = utils.extract_filepath
local null_ls = require('null-ls')

local function handler()
  local severities = { error = 1, warning = 2, information = 3, hint = 4 }

  local diags = {}
  return function(msg, done)
    if msg == nil or msg.output == nil then
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

    log(msg.method)
    -- log(msg)
    local msgs = msg.output
    msgs = vim.split(msgs, '\n', true)
    log(#msgs, msgs)
    if #msgs == 0 then
      return
    end
    local verbose = true
    local failure = {}
    if #msgs > 100 then -- lua is slow
      log('reduce')
      verbose = false
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
    for idx, m in pairs(msgs) do
      -- log(idx)
      if vfn.empty(m) == 0 then
        if m:find('--- PASS') or m:find('--- SKIP') or m:find('=== RUN') then
          output = ''
        else
          local entry = json_decode(m)
          entry = entry or {}
          -- log(entry)
          if entry.Action == 'run' then
            package = entry.Package
            output = ''
          elseif entry.Action == 'output' then
            package = entry.Package
            if vfn.empty(entry.Output) == 1 or false then
              output = ''
            else
              log(idx, entry)
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

              -- log(found, filename, lnum)
              if found == true then
                local pkg_path = require('go.gotest').get_test_path() .. utils.sep()
                output = pkg_path .. utils.ltrim(entry.Output)
              else -- not found or format is correct
                if #output > 1 then
                  output = output .. (entry.Output or '')
                else
                  output = output .. (entry.Output or '')
                end
              end
              if entry.Output:find('FAIL') or entry.Output:find('panic') then
                table.insert(panic, entry.Output)
              end
              log(idx, filename, output or 'nil')
            end
          elseif entry.Action == 'pass' or entry.Action == 'skip' then
            -- log(entry)
            -- reset
            output = ''
          elseif entry.Action == 'fail' and vfn.empty(output) == 0 then
            log(idx, entry, filename, output)
            if filename and filename:find(vfn.expand('%:t:r')) then -- can be output from other files
              table.insert(diags, {
                file = filename,
                row = tonumber(line),
                col = 1,
                message = output,
                severity = severities.error,
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
            -- reset
            local plines = ''
            if #panic > 0 then
              plines = table.concat(panic, '')
            end
          end
        end
      end
    end

    if #qf > 0 then
      local efm = require('go.gotest').efm()
      vfn.setqflist({}, ' ', { title = 'gotest', lines = qf, efm = efm })
      log(qf, efm)
    end
    log(diags)

    vim.notify('go test failed: ' .. '\n please check quickfix!\n', vim.log.levels.WARN)
    -- local ok, d = pcall(vfn.json_decode, msg)
    return done(diags)
  end
end
local h = require('null-ls.helpers')
local methods = require('null-ls.methods')

local DIAGNOSTICS_ON_SAVE = methods.internal.DIAGNOSTICS_ON_SAVE

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
      method = DIAGNOSTICS_ON_SAVE,
      filetypes = { 'go' },
      generator_opts = {
        command = 'golangci-lint',
        to_stdin = true,
        from_stderr = false,
        ignore_stderr = true,
        async = true,
        format = 'raw',
        args = function()
          local rfname = vfn.fnamemodify(vfn.expand('%'), ':~:.')
          log(rfname) -- repplace $FILENAME ?
          golangci_diags = {} -- CHECK: is here the best place to call
          return {
            'run',
            '--fix=false',
            '--out-format=json',
            '--path-prefix',
            '$ROOT',
            '$FILENAME',
          }
        end,
        check_exit_code = function(code)
          if code > 2 then
            vim.notify('go lint failed, please check quickfix')
            return false
          end
          return true
        end,
        on_output = function(msg, done)
          if msg == nil then
            return {}
          end

          if vfn.empty(msg.err) == 0 then
            -- stderr output, might be a compile failure
            vim.notify('error: ' .. msg.err, vim.log.levels.WARN)
          end

          log(msg.method)
          if msg.output == nil then
            return
          end

          local msgs = msg.output
          msgs = vim.split(msgs, '\n', true)

          -- the output is jsonencoded

          for _, m in pairs(msgs) do
            if vfn.empty(m) == 0 then
              local entry = vfn.json_decode(m)
              if entry['Report'] and entry['Report']['Error'] then
                log:warn(entry['Report']['Error'])
                return golangci_diags
              end
              local issues = entry['Issues']
              -- local bufname = vfn.expand('%:p')
              if type(issues) == 'table' then
                for _, d in ipairs(issues) do
                  if d.Pos then --and d.Pos.Filename == bufname then
                    log(d)
                    table.insert(golangci_diags, {
                      source = string.format('golangci-lint:%s', d.FromLinter),
                      row = d.Pos.Line,
                      col = d.Pos.Column,
                      message = d.Text,
                      severity = h.diagnostics.severities['warning'],
                    })
                  end
                end
              end
            end
          end
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
    local pkg_path = ''

    return h.make_builtin({
      name = 'gotest',
      method = null_ls.methods.DIAGNOSTICS_ON_SAVE,
      filetypes = { 'go' },
      generator_opts = {
        command = 'go',
        async = true,
        args = function()
          local gt = require('go.gotest')
          local a = { 'test', '-json' }
          local tests = gt.get_test_cases()
          log(tests)

          local pkg = require('go.gotest').get_test_path()
          pkg_path = pkg
          if vfn.empty(tests) == 1 then
            table.insert(a, pkg)
          else
            local sh = vim.o.shell
            table.insert(a, '-run')
            table.insert(a, tests)
            table.insert(a, pkg)
          end
          log(a)
          return a
        end,
        method = methods.internal.DIAGNOSTICS_ON_SAVE,
        format = 'raw',
        timeout = 5000,
        check_exit_code = function(code, stderr)
          local success = code <= 1
          log(code, stderr)
          -- if not success then
          --   -- can be noisy for things that run often (e.g. diagnostics), but can
          --   -- be useful for things that run on demand (e.g. formatting)
          --   vim.schedule_wrap(function()
          --     vim.notify('go test failed: ' .. tostring(stderr), vim.log.levels.WARN)
          --   end)
          -- end
          return true
        end,
        on_output = handler(pkg_path),
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
          log(fname)
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
