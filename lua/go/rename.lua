-- local ts_utils = require 'nvim-treesitter.ts_utils'
local util = require("go.util")

local gorename = "gorename"
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

  local prompt = vim.fn.printf("Goename '%s' to (may take a while) :", old_identifier)
  to_identifier = to_identifier or vim.fn.input(prompt, old_identifier)
  local byte_offset = vim.fn.wordcount().cursor_bytes

  local offset = string.format("%s:#%i", fname, byte_offset)

  local setup = {gorename, "-offset", offset, "-to", to_identifier}

  -- print("setup: ", vim.inspect(setup))
  --
  -- local arg = {...}
  -- for i, v in ipairs(arg) do
  --   table.insert(setup, v)
  -- end
  --
  -- print(vim.inspect(setup))
  local j =
    vim.fn.jobstart(
    setup,
    {
      on_stdout = function(jobid, data, event)
        data = util.handle_job_data(data)
        if not data then return end
        local result = vim.fn.json_decode(data)
        if result.errors ~= nil or result.lines == nil or result["start"] == nil or result["start"]  == 0 then
          print("failed to rename" .. vim.inspect(result))
        end
        print("renamed to " .. to_identifier)
      end
    }
  )
end
return {run = run}
