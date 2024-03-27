local utils = require('go.utils')

local gorename = 'gorename'
local vfn = vim.fn

local lsprename = function()
  local input = vim.ui.input

  vim.ui.input = _GO_NVIM_CFG.go_input()
  vim.lsp.buf.rename()
  return vim.defer_fn(function()
    vim.ui.input = input
  end, 1000)
end

local run = function(to_identifier, ...)
  require('go.install').install(gorename)
  local fname = vfn.expand('%:p') -- %:p:h ? %:p

  local old_identifier = vfn.expand('<cword>')

  local prompt = vfn.printf("GoRename '%s' to (may take a while) :", old_identifier)
  to_identifier = to_identifier or vfn.input(prompt, old_identifier)
  local byte_offset = vfn.wordcount().cursor_bytes

  local client = require('go.lsp').client()
  if client then
    -- TODO check gopls?
    return lsprename()
  end

  local offset = string.format('%s:#%i', fname, byte_offset)

  local setup = { gorename, '-offset', offset, '-to', to_identifier }

  vfn.jobstart(setup, {
    on_stdout = function(_, data, _)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      -- local result = vfn.json_decode(data)
      local result = vim.json.decode(data)
      if
        result.errors ~= nil
        or result.lines == nil
        or result['start'] == nil
        or result['start'] == 0
      then
        vim.notify('failed to rename' .. vim.inspect(result), vim.log.levels.ERROR)
      end
      vim.notify('renamed to ' .. to_identifier, vim.log.levels.DEBUG)
    end,
  })
end
return { run = run, lsprename = lsprename }
