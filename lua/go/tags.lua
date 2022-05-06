local utils = require("go.utils")

local tags = {}
-- support -add-tags, --add-options, -remove-tags, -remove-options, clear-tags, clear-options
-- for struct and line range
-- gomodifytags -file demo.go -struct Server -add-tags json
-- gomodifytags -file demo.go -struct Server -add-tags json -w
-- gomodifytags -file demo.go -struct Server -add-tags json,xml
-- gomodifytags -file demo.go -struct Server -add-tags json,xml -transform camelcase
-- gomodifytags -file demo.go -line 8,11 -clear-tags xml

local opts = {
  "-add-tags",
  "-add-options",
  "-remove-tags",
  "-remove-options",
  "-clear-tags",
  "-clear-options",
}

local gomodify = "gomodifytags"
local transform = _GO_NVIM_CFG.tag_transform
tags.modify = function(...)
  require("go.install").install(gomodify)
  local fname = vim.fn.expand("%") -- %:p:h ? %:p
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local ns = require("go.ts.go").get_struct_node_at_pos(row, col)
  if utils.empty(ns) then
    return
  end

  -- vim.notify("parnode" .. vim.inspect(ns), vim.lsp.log_levels.DEBUG)
  local struct_name = ns.name
  local rs, re = ns.dim.s.r, ns.dim.e.r
  local setup = { gomodify, "-format", "json", "-file", fname, "-w" }

  if struct_name == nil then
    local _, csrow, _, _ = unpack(vim.fn.getpos("."))
    table.insert(setup, "-line")
    table.insert(setup, csrow)
  else
    table.insert(setup, "-struct")
    table.insert(setup, struct_name)
  end
  if transform then
    table.insert(setup, "-transform")
    table.insert(setup, transform)
  end
  local arg = { ... }
  for i, v in ipairs(arg) do
    table.insert(setup, v)
  end

  if #arg == 1 and arg[1] ~= "-clear-tags" then
    table.insert(setup, "json")
  end
  -- vim.notify(vim.inspect(setup), vim.lsp.log_levels.DEBUG)
  local j = vim.fn.jobstart(setup, {
    on_stdout = function(jobid, data, event)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      local tagged = vim.fn.json_decode(data)
      -- vim.notify(vim.inspect(tagged), vim.lsp.log_levels.DEBUG)
      -- vim.notify(tagged["start"] .. " " .. tagged["end"] .. " " .. tagged.lines, vim.lsp.log_levels.ERROR)
      if tagged.errors ~= nil or tagged.lines == nil or tagged["start"] == nil or tagged["start"] == 0 then
        vim.notify("failed to set tags" .. vim.inspect(tagged), vim.lsp.log_levels.ERROR)
      end
      for index, value in ipairs(tagged.lines) do
        tagged.lines[index] = utils.rtrim(value)
      end
      -- trim tail spaces?
      vim.api.nvim_buf_set_lines(0, tagged["start"] - 1, tagged["start"] - 1 + #tagged.lines, false, tagged.lines)
      vim.cmd("write")
      vim.notify("struct updated ", vim.lsp.log_levels.DEBUG)
    end,
  })
end

tags.add = function(...)
  local cmd = { "-add-tags" }
  local arg = { ... }
  if #arg == 0 then
    arg = { "json" }
  end
  for _, v in ipairs(arg) do
    table.insert(cmd, v)
  end

  tags.modify(unpack(cmd))
end

tags.rm = function(...)
  local cmd = { "-remove-tags" }
  local arg = { ... }
  if #arg == 0 then
    arg = { "json" }
  end
  for _, v in ipairs(arg) do
    table.insert(cmd, v)
  end
  tags.modify(unpack(cmd))
end

tags.clear = function()
  local cmd = { "-clear-tags" }
  tags.modify(unpack(cmd))
end

return tags
