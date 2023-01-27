local vim, fn = vim, vim.fn
local utils = require('go.utils')
local log = utils.log

local extract_filepath = utils.extract_filepath

local function handler()
  local severities = { error = 1, warning = 2, information = 3, hint = 4 }
  return function(msg, done)
    if msg == nil or msg.output == nil then
      return
    end
    if msg.lsp_method == 'textDocument/didChange' or msg.method == 'NULL_LS_DIAGNOSTICS' then
      -- there is no need to run on didChange, has to run until fil saved
      return log('skip didChange')
    end
    if vim.fn.empty(msg.err) == 0 then
      log('error', msg.err)
      return
    end

    log(msg.method)
    -- log(msg)
    local msgs = msg.output
    msgs = vim.split(msgs, '\n', true)

    local diags = {}
    local package, filename, line
    -- the output is jsonencoded
    local output = ''

    local qf = {}
    for _, m in pairs(msgs) do
      if vim.fn.empty(m) == 0 then
        local entry = vim.fn.json_decode(m)
        if entry.Action == 'run' then
          package = entry.Package
          output = ''
        elseif entry.Action == 'output' then
          if vim.fn.empty(entry.Output) == 0 then
            local ma = vim.fn.matchlist(entry.Output, [[\v\s*(\w+.+\.go):(\d+):]])
            if ma[2] then
              log(ma)
              filename = package .. utils.sep() .. ma[2]
              if fn.filereadable(filename) == 0 then
                filename = fn.fnamemodify(fn.expand('%:h'), ':~:.') .. utils.sep() .. ma[2]
              end
              line = ma[3]
            end
            output = output .. (entry.Output or '')
            -- log(output or 'nil')
          end
        elseif entry.Action == 'pass' or entry.Action == 'skip' then
          -- log(entry)
          -- reset
          output = ''
        elseif entry.Action == 'fail' and vim.fn.empty(output) == 0 then
          -- log(entry)
          if filename and filename:find(fn.expand('%:t')) then -- can be output from other files
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
            local p = extract_filepath(value)
            if p then
              value = p .. utils.ltrim(value)
            end
            qflines[i] = value
          end
          vim.list_extend(qf, qflines)
          output = ''
        end
      end
      if #qf > 0 then
        local efm = require('go.gotest').efm()
        vim.fn.setqflist({}, ' ', { title = 'gotest', lines = qf, efm = efm })
      end
    end
    log(diags)
    -- local ok, d = pcall(vim.fn.json_decode, msg)
    return done(diags)
  end
end
-- register with
-- null_ls.register(gotest)
return {
  gotest = function()
    local nulls = utils.load_plugin('null-ls', 'null-ls')
    if nulls == nil then
      vim.notify('failed to load null-ls', vim.lsp.log_levels.WARN)
      return
    end

    local null_ls = require('null-ls')
    local methods = require('null-ls.methods')

    return {
      name = 'gotest',
      method = null_ls.methods.DIAGNOSTICS_ON_SAVE,
      filetypes = { 'go' },
      generator = null_ls.generator({
        command = 'go',
        args = function()
          local gt = require('go.gotest')
          local a = { 'test', '-json' }
          local tests = gt.get_test_cases()
          log(tests)

          local pkg = require('go.gotest').get_test_path()
          if not tests or not tests[1] then
            table.insert(a, pkg)
          else
            tests = tests[1]

            local sh = vim.o.shell
            table.insert(a, '-run')
            table.insert(a, tests)
            table.insert(a, pkg)
          end
          log(a)
          return a
        end,
        to_stdin = false,
        method = methods.internal.DIAGNOSTICS_ON_SAVE,
        from_stderr = false,
        format = 'raw',
        check_exit_code = function(code, stderr)
          local success = code <= 1
          log(code, stderr)
          if not success then
            -- can be noisy for things that run often (e.g. diagnostics), but can
            -- be useful for things that run on demand (e.g. formatting)
            vim.notify('go test failed: ' .. tostring(stderr))
          end
          return true
        end,
        on_output = handler(),
      }),
    }
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
