-- todo
-- for func name(args) rets {}
-- add cmts // name : rets
local comment = { hl_timestamp = {} }
local placeholder = _GO_NVIM_CFG.comment.placeholder or ''
local ulog = require('go.utils').log
local api = vim.api
local node_from_match = require('go.ts.utils').node_from_match

local gen_comment = function()
  local comments = nil

  local ns = require('go.ts.go').get_package_node_at_pos()
  if ns then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// Package ' .. ns.name .. ' provides ' .. ns.name
    return comments, ns
  end
  ns = require('go.ts.go').get_func_method_node_at_pos()
  if ns then
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end
  ns = require('go.ts.go').get_struct_node_at_pos()
  if ns then
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end
  ns = require('go.ts.go').get_interface_node_at_pos()
  if ns then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end

  ns = require('go.ts.go').get_type_node_at_pos()
  if ns then
    -- ulog("parnode" .. vim.inspect(ns))
    comments = '// ' .. ns.name .. ' ' .. ns.type
    return comments, ns
  end
  return ''
end

local wrap_comment = function(comment_line, ns)
  if string.len(comment_line) > 0 and string.len(placeholder) > 0 then
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
    local ts_utils = require('nvim-treesitter.ts_utils')
    ns = ts_utils.get_node_at_cursor()
    local node_text = vim.treesitter.get_node_text(ns, bufnr)

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

local ns_id = vim.api.nvim_create_namespace('GoCommentCode')

local function highlight_go_code_in_comments()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  if ft ~= 'go' or not _GO_NVIM_CFG.comment.highlight then
    return
  end

  -- Create a namespace for the highlights
  -- Clear any existing highlights in this namespace
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Get the Tree-sitter parser for Go
  local parser = vim.treesitter.get_parser(bufnr, 'go')
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Collect code elements (types, functions, variables, constants, keywords, parameters)
  local code_elements = {
    types = {},
    functions = {},
    variables = {},
    constants = {},
    parameters = {},
    methods = {},
    methods_params = {},
    keywords = {},
  }

  -- Define queries to capture code elements
  local queries = {
    types = [[
            (type_spec name: (type_identifier) @type_name)
        ]],
    functions = [[
            (function_declaration name: (identifier) @function_name)
        ]],
    variables = [[
            (var_spec name: (identifier) @variable_name)
        ]],
    constants = [[
            (const_spec name: (identifier) @constant_name)
        ]],
    parameters = [[
            (function_declaration
                parameters: (parameter_list
                    (parameter_declaration
                        name: (identifier) @param_name)))
        ]],
    methods = [[
            (method_declaration
              name: (field_identifier) @method_name)
        ]],
    methods_params = [[
            (method_declaration
              parameters: (parameter_list
                (parameter_declaration
                  name: (identifier) @param_name)))
        ]],
    -- Keywords are predefined in Go
    keywords = {
      'func',
      'interface',
      'defer',
      'map',
      'struct',
      'chan',
      'package',
      'const',
      'returns',
      '+build',
      'go:build',
      'go:generate',
    },
  }

  if _GO_NVIM_CFG.comment.queries then
    for k, v in pairs(_GO_NVIM_CFG.comment.queries) do
      queries[k] = v
    end
  end

  -- Function to collect names from query
  local function collect_names(query_string, capture_name, target_table)
    local query = vim.treesitter.query.parse('go', query_string)
    local capture_index = nil

    -- Find the index of the capture name in the query's captures
    for idx, name in ipairs(query.captures) do
      if name == capture_name then
        capture_index = idx
        break
      end
    end

    if not capture_index then
      vim.notify('Capture name "' .. capture_name .. '" not found in query', vim.log.levels.INFO)
      return
    end

    -- Note capture_index should be 1
    for pattern, match, metadata in query:iter_matches(root, bufnr, 0, -1) do
      local node = node_from_match(match, capture_index)
      local name = vim.treesitter.get_node_text(node, bufnr)
      target_table[name] = true
      ulog('name', name)
    end
  end

  -- Collect code elements
  collect_names(queries.types, 'type_name', code_elements.types)
  collect_names(queries.functions, 'function_name', code_elements.functions)
  collect_names(queries.methods, 'method_name', code_elements.methods)
  collect_names(queries.methods_params, 'param_name', code_elements.methods_params)
  collect_names(queries.variables, 'variable_name', code_elements.variables)
  collect_names(queries.constants, 'constant_name', code_elements.constants)
  collect_names(queries.parameters, 'param_name', code_elements.parameters)

  -- Build patterns for each category
  local function build_pattern(names)
    local words = {}
    for name, _ in pairs(names) do
      table.insert(words, vim.fn.escape(name, '\\'))
    end
    if #words == 0 then
      return nil
    end
    return '\\C\\<\\(' .. table.concat(words, '\\|') .. '\\)\\>'
  end

  local patterns = {
    types = build_pattern(code_elements.types),
    functions = build_pattern(code_elements.functions),
    methods = build_pattern(code_elements.methods),
    variables = build_pattern(code_elements.variables),
    constants = build_pattern(code_elements.constants),
    parameters = build_pattern(code_elements.parameters),
    methods_params = build_pattern(code_elements.methods_params),
    keywords = '\\<\\(' .. table.concat(queries.keywords, '\\|') .. '\\)\\>',
    -- match square brackets and content inside them e.g. [slice.Sort]
    -- matchbrackets = '\\[\\([^\\[\\]]*\\)\\]',
  }

  -- Compile regexes
  local regexes = {}
  for category, pattern_str in pairs(patterns) do
    if pattern_str then
      regexes[category] = vim.regex(pattern_str)
    end
  end

  -- Define the highlight groups for each category
  local highlight_groups = {
    types = '@comment.go.type',
    functions = '@comment.go.function',
    methods = '@comment.go.method',
    variables = '@comment.go.var',
    constants = '@comment.go.constant',
    parameters = '@comment.go.para',
    methods_params = '@comment.go.para',
    keywords = '@comment.go.keyword',
    matchbrackets = '@comment.go.method',
  }

  if _GO_NVIM_CFG.comment.highlight_groups then
    for k, v in pairs(_GO_NVIM_CFG.comment.highlight_groups) do
      highlight_groups[k] = v
    end
  end

  -- Define a query to find comment nodes
  local comment_query = vim.treesitter.query.parse('go', '(comment) @comment')

  local capture_index = nil

  -- Find the index of the capture name in the query's captures
  for idx, name in ipairs(comment_query.captures) do
    ulog('name', name)
    if name == 'comment' then
      capture_index = idx
      break
    end
  end

  -- Iterate over the captures in the query
  for _, matches, _ in comment_query:iter_matches(root, bufnr, 0, -1) do
    local node = node_from_match(matches, capture_index)
    local start_row, start_col, end_row, end_col = node:range()

    for row = start_row, end_row do
      local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
      local col_start = 0
      local col_end = #line

      if row == start_row then
        col_start = start_col
      end
      if row == end_row then
        col_end = end_col
      end

      -- For each category, search for matches and apply highlights
      for category, regex in pairs(regexes) do
        local s = col_start
        while s < col_end do
          local m_start, m_end = regex:match_line(bufnr, row, s, col_end)
          if not m_start then
            break
          end

          -- m_start and m_end are relative to 's'
          local hl_start_col = m_start + s
          local hl_end_col = m_end + s
          -- ulog('highlight', row, hl_start_col, hl_end_col, line:sub(hl_start_col, hl_end_col))

          -- Apply the highlight to the matched word
          vim.api.nvim_buf_add_highlight(
            bufnr,
            ns_id,
            highlight_groups[category],
            row,
            hl_start_col,
            hl_end_col
          )

          s = hl_end_col -- Move to the end of the current match
        end
      end
    end
  end
end

---@diagnostic disable-next-line: unused-local
local function toggle_go_comment_highlight()
  _GO_NVIM_CFG.comment.highlight = not _GO_NVIM_CFG.comment.highlight
  if _GO_NVIM_CFG.comment.highlight then
    highlight = require('go.utils').throttle(
      highlight_go_code_in_comments,
      _GO_NVIM_CFG.comment.highlight_debounce
    )
    highlight()
  else
    vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
  end
end

comment.highlight = highlight_go_code_in_comments
comment.toggle_highlight = toggle_go_comment_highlight

vim.api.nvim_create_user_command('ToggleGoCommentHighlight', function()
  require('go.comment').toggle_highlight()
end, {})

local group = vim.api.nvim_create_augroup('gonvim__comment_hl', {})
vim.api.nvim_create_autocmd(
  { 'BufEnter', 'BufWritePost', 'WinEnter', 'InsertLeave', 'CursorHold' },
  {
    pattern = { '*.go' },
    group = group,
    callback = function(opts)
      if _GO_NVIM_CFG.comment.highlight then
        -- check
        local filename = vim.api.nvim_buf_get_name(0)
        local timestamp = comment.hl_timestamp[filename]
        if timestamp and timestamp == vim.fn.getftime(filename) then
          return
        end
        require('go.comment').highlight()
        comment.hl_timestamp[filename] = vim.fn.getftime(filename)
      end
    end,
  }
)

-- Define highlight groups for code elements within comments
vim.api.nvim_set_hl(0, '@comment.go.type', { link = '@markup.heading' })
vim.api.nvim_set_hl(0, '@comment.go.function', { link = '@markup.heading' })
vim.api.nvim_set_hl(0, '@comment.go.method', { link = '@markup.heading' })
vim.api.nvim_set_hl(0, '@comment.go.var', { link = '@markup.emphasis' })
vim.api.nvim_set_hl(0, '@comment.go.constant', { link = '@markup.emphasis' })
vim.api.nvim_set_hl(0, '@comment.go.para', { link = '@markup.list' }) -- New highlight group
vim.api.nvim_set_hl(0, '@comment.go.keyword', { link = '@markup.strong' })

vim.api.nvim_set_hl(0, '@bold.comment', { bold = true })
vim.api.nvim_set_hl(0, '@italic.comment', { italic = true })
vim.api.nvim_set_hl(0, '@underline.comment', { underline = true })
vim.api.nvim_set_hl(0, '@strikethrough.comment', { strikethrough = true })
vim.api.nvim_set_hl(0, '@markup.link.label.markdown_inline', { underline = true })
vim.api.nvim_set_hl(0, '@markup.link.label', { underline = true, fg = 'blue' })

vim.api.nvim_set_hl(0, '@comment.documentation.go', { link = '@comment.note' })

return comment
