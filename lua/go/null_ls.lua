local vim, fn = vim, vim.fn
local utils = require('go.utils')
local log = utils.log

local function handler()
  local severities = { error = 1, warning = 2, information = 3, hint = 4 }
  return function(msg, done)
    if msg == nil or msg.output == nil then
      return
    end

    local msgs = msg.output
    msgs = vim.split(msgs, '\n', true)

    local diags = {}
    local package, filename, line
    -- the output is jsonencoded
    local output = ''

    for _, m in pairs(msgs) do
      if vim.fn.empty(m) == 0 then
        local entry = vim.fn.json_decode(m)
        if entry.Action == 'run' then
          package = entry.Package
          output = ''
        elseif entry.Action == 'output' then
          log(entry)
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
          log(entry)
          if filename:find(fn.expand('%:t')) then -- can be output from other files
            table.insert(diags, {
              file = filename,
              row = tonumber(line),
              col = 1,
              message = output,
              severity = severities.error,
              source = 'go test',
            })
          end
          output = ''
        end
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
    local DIAGNOSTICS_ON_SAVE = methods.internal.DIAGNOSTICS_ON_SAVE

    return {
      method = null_ls.methods.DIAGNOSTICS,
      filetypes = { 'go' },
      generator = null_ls.generator({
        command = 'go',
        args = function()
          local a = { 'test', '-json' }
          local pkg = require('go.gotest').get_test_path()
          table.insert(a, pkg)
          log(a)
          return a
        end,
        to_stdin = false,
        method = DIAGNOSTICS_ON_SAVE,
        from_stderr = false,
        -- choose an output format (raw, json, or line)
        -- format = 'json',
        format = 'raw',
        check_exit_code = function(code, stderr)
          local success = code <= 1
          log(code, stderr)
          if not success then
            -- can be noisy for things that run often (e.g. diagnostics), but can
            -- be useful for things that run on demand (e.g. formatting)
            vim.notify('go test failed: ' .. tostring(stderr))
          end
          return success
        end,
        on_output = handler(),
      }),
    }
  end,
}
