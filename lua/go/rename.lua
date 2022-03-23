-- local ts_utils = require 'nvim-treesitter.ts_utils'
local utils = require("go.utils")

local gorename = "gorename"

local lsprename = function(new_name)
  if #new_name == 0 or new_name == vim.fn.expand("<cword>") then
    return
  end
  local params = vim.lsp.util.make_position_params()
  params.newName = new_name
  vim.lsp.buf_request(0, "textDocument/rename", params)
end

local run = function(to_identifier, ...)
  require("go.install").install(gorename)
  local fname = vim.fn.expand("%:p") -- %:p:h ? %:p

  local old_identifier = vim.fn.expand("<cword>")
  -- if ts_utils ~= nil then
  --   local node=ts_utils.get_node_at_cursor()
  --   if node ~= nil then
  --     local text=ts_utils.get_node_text(node)
  --     if text ~= nil and #text > 0 then
  --       old_identifier = text[1]
  --     end
  --   end
  -- end

  local prompt = vim.fn.printf("GoRename '%s' to (may take a while) :", old_identifier)
  to_identifier = to_identifier or vim.fn.input(prompt, old_identifier)
  local byte_offset = vim.fn.wordcount().cursor_bytes

  local clients = vim.lsp.get_active_clients() or {}
  if #clients > 0 then
    -- TODO check gopls?
    return lsprename(to_identifier)
  end

  local offset = string.format("%s:#%i", fname, byte_offset)

  local setup = {gorename, "-offset", offset, "-to", to_identifier}

  -- vim.notify("setup: " .. vim.inspect(setup), vim.lsp.log_levels.DEBUG)
  --
  -- local arg = {...}
  -- for i, v in ipairs(arg) do
  --   table.insert(setup, v)
  -- end
  --
  -- vim.notify(vim.inspect(setup), vim.lsp.log_levels.DEBUG)
  local j = vim.fn.jobstart(setup, {
    on_stdout = function(jobid, data, event)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      -- local result = vim.fn.json_decode(data)
      local result = vim.json.decode(data)
      if result.errors ~= nil or result.lines == nil or result["start"] == nil or result["start"] == 0 then
        vim.notify("failed to rename" .. vim.inspect(result), vim.lsp.log_levels.ERROR)
      end
      vim.notify("renamed to " .. to_identifier, vim.lsp.log_levels.DEBUG)
    end
  })
end
return {run = run}
