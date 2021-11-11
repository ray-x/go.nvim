local utils = require("go.utils")

local run = function(func, ...)

  vim.validate({func = {func, 'string'}})

  local setup = {'go', 'doc', vim.trim(func)}
  --
  local j = vim.fn.jobstart(setup, {
    on_stdout = function(jobid, data, event)
      data = utils.handle_job_data(data)
      if not data then
        return
      end

      local close_events = {"CursorMoved", "CursorMovedI", "BufHidden", "InsertCharPre"}
      local config = {close_events = close_events, focusable = true, border = 'single'}
      vim.lsp.util.open_floating_preview(data, 'go', config)
    end
  })
end
return {run = run}
