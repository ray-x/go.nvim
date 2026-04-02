-- todo
-- for func name(args) rets {}
-- add cmts // name : rets
local comment = {}
local placeholder = _GO_NVIM_CFG.comment_placeholder or ''
local ulog = require('go.utils').log
local api = vim.api

local gen_comment = function()
  local comments = nil

  local ns = require('go.ts.go').get_package_node_at_pos()
  if ns ~= nil and ns ~= {} then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// Package ' .. ns.name .. ' provides ' .. ns.name
    return comments, ns
  end
  ns = require('go.ts.go').get_func_method_node_at_pos()
  if ns ~= nil and ns ~= {} then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end
  ns = require('go.ts.go').get_struct_node_at_pos()
  if ns ~= nil and ns ~= {} then
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end
  ns = require('go.ts.go').get_interface_node_at_pos()
  if ns ~= nil and ns ~= {} then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end

  ns = require('go.ts.go').get_type_node_at_pos()
  if ns ~= nil and ns ~= {} then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end
  return ''
end

local wrap_comment = function(comment_line, ns)
  if string.len(comment_line) > 0 and placeholder ~= nil and string.len(placeholder) > 0 then
    return comment_line .. ' ' .. placeholder, ns
  end
  return comment_line, ns
end

comment.gen = function()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  local c, ns = wrap_comment(gen_comment())
  local bufnr = api.nvim_get_current_buf()
  if ns == nil then
    -- nothing found
    ns = vim.treesitter.get_node({ bufnr = bufnr })
    local node_text = require('go.utils').get_node_text(ns, bufnr)

    local line = api.nvim_get_current_line()
    local regex = '^(%s+)'
    local q = line:match(regex)
    c = (q or '') .. '// ' .. node_text
    c, _ = wrap_comment(c, {})
    vim.fn.append(row - 1, c)
    vim.fn.cursor(row, #c + 1)
    return
  end
  ulog(vim.inspect(ns))
  row, col = ns.dim.s.r, ns.dim.s.c
  ulog('set cursor ' .. tostring(row))
  api.nvim_win_set_cursor(0, { row, col })
  -- insert doc
  vim.fn.append(row - 1, c)
  -- set curosr
  vim.fn.cursor(row, #c + 1)
  -- enter into insert mode
  api.nvim_command('startinsert!')
  return c
end

local comment_system_prompt = [[You are a Go documentation expert.
Generate a Go doc comment for the given code declaration.

Rules:
1. Follow Go documentation conventions (https://go.dev/doc/comment).
2. The comment must start with "// <Name> " where <Name> is the identifier name.
3. For package clauses, start with "// Package <name> ".
4. Be concise but informative. Describe what it does, not how.
5. If the code has parameters, mention important ones only when their purpose is non-obvious.
6. Return ONLY the comment lines (each starting with "//"). No code, no markdown fences, no extra text.
7. If it's a multi-line comment, use multiple "// " lines.
8. Do not add a blank line between comment lines.
]]

--- Get the declaration node and its source text at cursor
local function get_declaration_at_cursor()
  local bufnr = api.nvim_get_current_buf()

  -- Try each node type in order
  local getters = {
    { fn = require('go.ts.go').get_package_node_at_pos, kind = 'package' },
    { fn = require('go.ts.go').get_func_method_node_at_pos, kind = 'function' },
    { fn = require('go.ts.go').get_struct_node_at_pos, kind = 'struct' },
    { fn = require('go.ts.go').get_interface_node_at_pos, kind = 'interface' },
    { fn = require('go.ts.go').get_type_node_at_pos, kind = 'type' },
  }

  for _, g in ipairs(getters) do
    local ns = g.fn()
    if ns and ns.declaring_node then
      local source = vim.treesitter.get_node_text(ns.declaring_node, bufnr)
      return ns, source, g.kind
    end
  end
  return nil, nil, nil
end

--- Generate doc comment using AI/Copilot
comment.gen_ai = function()
  local ns, source, kind = get_declaration_at_cursor()
  if not ns or not source then
    vim.notify('go.nvim [AI Comment]: no Go declaration found at cursor', vim.log.levels.WARN)
    return
  end

  local file = vim.fn.expand('%:t') or ''
  local user_msg = string.format('File: %s\nKind: %s\n\n```go\n%s\n```', file, kind, source)

  vim.notify('go.nvim [AI Comment]: generating …', vim.log.levels.INFO)

  require('go.ai').request(comment_system_prompt, user_msg, { max_tokens = 300 }, function(resp)
    -- Strip markdown fences if present
    resp = resp:gsub('^```%w*\n?', ''):gsub('\n?```$', '')
    resp = vim.trim(resp)

    -- Split into lines and validate each starts with "//"
    local lines = vim.split(resp, '\n', { plain = true })
    local comment_lines = {}
    for _, line in ipairs(lines) do
      line = vim.trim(line)
      if line:match('^//') then
        table.insert(comment_lines, line)
      end
    end

    if #comment_lines == 0 then
      vim.notify('go.nvim [AI Comment]: LLM returned no valid comment lines', vim.log.levels.WARN)
      return
    end

    local row = ns.dim.s.r
    -- Insert comment lines above the declaration
    for i = #comment_lines, 1, -1 do
      vim.fn.append(row - 1, comment_lines[i])
    end
    -- Position cursor at the end of the first comment line
    vim.fn.cursor(row, #comment_lines[1] + 1)
  end)
end

return comment
