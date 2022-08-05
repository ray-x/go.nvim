local runner = require('go.runner')
local utils = require('go.utils')
local log = utils.log
local uv, api = vim.loop, vim.api
local M = {}
-- visual select json text and run the command
function M.run(opts)
  local args, bang = opts.args, opts.bang
  local register = opts.register
  local json

  local range = vim.lsp.util.make_given_range_params().range
  if register then
    json = vim.fn.getreg(register)
  else
    log(range)
    json = vim.api.nvim_buf_get_lines(0, range.start.line, range['end'].line + 1, true)
    json[1] = json[1]:sub(range.start.character + 1)
    json[#json] = json[#json]:sub(1, range['end'].character + 1)
  end
  if #json == 1 then
    json = vim.split(json[1], '\n')
  end
  log(json)

  local cmd = { 'json-to-struct', '-name', args[1] or 'myStruct' }

  local opts = {
    update_buffer = true,
    on_exit = function(code, signal, output_buf)
      log(code, signal, output_buf)
      if code ~= 0 or signal ~= 0 then
        vim.notify(
          'error code' .. tostring(code) .. ' ' .. tostring(signal) .. vim.inspect(output_buf or ''),
          vim.lsp.log_levels.WARN
        )
      end
      local output = vim.split(output_buf, '\n')
      if output[1] == 'package main' then
        table.remove(output, 1)
      end
      vim.schedule(function()
        if not bang then
          api.nvim_buf_set_lines(0, range['end'].line + 1, range['end'].line + 1, false, output)
        else
          vim.fn.setreg('g', table.concat(output, '\n'))
          vim.notify('Json To Struct JSON converted and placed in register "g"')
        end
      end)
    end,
  }
  stdin, _, _ = runner.run(cmd, opts)
  uv.write(stdin, json)

  return cmd, opts
end

return M
