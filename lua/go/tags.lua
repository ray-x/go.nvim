local utils = require('go.utils')
local log = utils.log

local tags = {}
-- support -add-tags, --add-options, -remove-tags, -remove-options, clear-tags, clear-options
-- for struct and line range
-- gomodifytags -file demo.go -struct Server -add-tags json
-- gomodifytags -file demo.go -struct Server -add-tags json -w
-- gomodifytags -file demo.go -struct Server -add-tags json,xml
-- gomodifytags -file demo.go -struct Server -add-tags json,xml -transform camelcase
-- gomodifytags -file demo.go -line 8,11 -clear-tags xml

local gomodify = 'gomodifytags'
local transform = _GO_NVIM_CFG.tag_transform
local options = _GO_NVIM_CFG.tag_options

tags.modify = function(...)
  require('go.install').install(gomodify)
  local fname = vim.fn.expand('%') -- %:p:h ? %:p
  local ns = require('go.ts.go').get_struct_node_at_pos()
  if utils.empty(ns) then
    return
  end

  -- vim.notify("parnode" .. vim.inspect(ns), vim.lsp.log_levels.DEBUG)
  local struct_name = ns.name
  local setup = { gomodify, '-format', 'json', '-file', fname, '-w' }

  if struct_name == nil then
    local _, csrow, _, _ = unpack(vim.fn.getpos('.'))
    table.insert(setup, '-line')
    table.insert(setup, csrow)
  else
    table.insert(setup, '-struct')
    table.insert(setup, struct_name)
  end
  local arg = { ... }
  local transflg = false
  local optsflg = false
  local optidx
  for i, v in ipairs(arg) do
    table.insert(setup, v)
    if v == '-transform' or v == '-t' then
      transflg = true
    end
    if v == '-add-options' or v == '-a' then
      optsflg = true
      optidx = i + 1
      if arg[optidx] then
        -- override options
        options = arg[optidx]
      end
    end
  end
  if not transflg then
    if transform then
      table.insert(setup, '-transform')
      table.insert(setup, transform)
    end
  end
  if not optsflg then
    if options then
      table.insert(setup, '-add-options')
      table.insert(setup, options)
    end
  end

  if #arg == 1 and arg[1] ~= '-clear-tags' then
    table.insert(setup, 'json')
  end

  log(setup)

  -- vim.notify(vim.inspect(setup), vim.lsp.log_levels.DEBUG)
  vim.fn.jobstart(setup, {
    on_stdout = function(_, data, _)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      local tagged = vim.fn.json_decode(data)
      -- vim.notify(vim.inspect(tagged), vim.lsp.log_levels.DEBUG)
      -- vim.notify(tagged["start"] .. " " .. tagged["end"] .. " " .. tagged.lines, vim.lsp.log_levels.ERROR)
      if tagged.errors ~= nil or tagged.lines == nil or tagged['start'] == nil or tagged['start'] == 0 then
        vim.notify('failed to set tags' .. vim.inspect(tagged), vim.lsp.log_levels.ERROR)
      end
      for index, value in ipairs(tagged.lines) do
        tagged.lines[index] = utils.rtrim(value)
      end
      -- trim tail spaces?
      vim.api.nvim_buf_set_lines(0, tagged['start'] - 1, tagged['start'] - 1 + #tagged.lines, false, tagged.lines)
      vim.cmd('write')
      vim.notify('struct updated ', vim.lsp.log_levels.DEBUG)
    end,
  })
end

-- e.g {"json,xml", "-transform", "camelcase"}
tags.add = function(...)
  local cmd = { '-add-tags' }
  local arg = { ... }
  if #arg == 0 then
    arg = { 'json' }
  end

  local tg = select(1, ...)
  if tg == '-transform' then
    table.insert(cmd, 'json')
  end

  for _, v in ipairs(arg) do
    table.insert(cmd, v)
  end
  log(cmd)

  tags.modify(unpack(cmd))
end

tags.rm = function(...)
  local cmd = { '-remove-tags' }
  local arg = { ... }
  if #arg == 0 then
    arg = { 'json' }
  end
  for _, v in ipairs(arg) do
    table.insert(cmd, v)
  end
  tags.modify(unpack(cmd))
end

tags.clear = function()
  local cmd = { '-clear-tags' }
  tags.modify(unpack(cmd))
end

return tags
