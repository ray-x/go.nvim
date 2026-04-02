local utils = require('go.utils')
local log = utils.log
local gopls = require('go.gopls')
local help_items = {}
local vfn = vim.fn
local m = {}
function m.help_complete(_, _, _)
  if #help_items < 1 then
    local doc = vfn.systemlist('go help')
    if vim.v.shell_error ~= 0 then
      vim.notify(string.format('failed to run go help %d', vim.v.shell_error), vim.log.levels.ERROR)
      return
    end

    for _, line in ipairs(doc) do
      local m1 = string.match(line, '^%s+([%w-]+)')
      if m1 ~= nil and m1 ~= 'go' then
        table.insert(help_items, m1)
      end
    end
    table.sort(help_items)
  end
  return help_items
end

local function match_doc_flag(lead)
  local doc_flags = { '-all', '-c', '-cmd', '-short', '-src', '-u' }

  local items = {}
  local p = string.format('^%s', lead)
  for _, f in ipairs(doc_flags) do
    local k = string.match(f, p)
    log(k, f, p)
    if k then
      table.insert(items, f)
    end
  end
  table.sort(items)
  log(items)

  return items or {}
end

local function match_partial_item_name(pkg, pattern)
  local cmd = string.format('go doc %s', pkg)
  local doc = vfn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    utils.warn('go doc failed', vim.inspect(doc))
    return
  end

  local items = {}
  for _, _type in ipairs({ 'var', 'const', 'func', 'type' }) do
    local patterns = {
      string.format('^%%s*%s (%s%%w+)', _type, pattern),
      string.format('^%%s*%s %%(.-%%) (%s%%w+)', _type, pattern),
    }
    log(patterns)
    for _, line in ipairs(doc) do
      local k
      for _, pat in ipairs(patterns) do
        k = string.match(line, pat)
        if k then
          log(k)
          table.insert(items, k)
          break
        end
      end
    end
  end
  table.sort(items)
  log(items)
  return items
end

function m.doc_complete(_, cmdline, _)
  local words = vim.split(cmdline, '%s+')
  if string.match(words[#words], '^-') then
    log(words)
    return match_doc_flag(words[#words])
  end

  if #words > 2 and string.match(words[#words - 1], '^-') == nil then
    local pkg = words[#words - 1]
    local item = words[#words]
    return match_partial_item_name(pkg, item)
  elseif #words > 1 and string.match(words[#words], '^[^-].+%..*') ~= nil then
    local pkg, item, method = unpack(vim.split(words[#words], '%.'))
    if method then
      pkg = string.format('%s.%s', pkg, item)
      item = method
    end
    local comps = match_partial_item_name(pkg, item)
    for i, comp in ipairs(comps or {}) do
      comps[i] = string.format('%s.%s', pkg, comp)
    end
    return comps or {}
  elseif #words >= 1 and not string.match(words[#words], '^-') then
    local pkgs = gopls.list_pkgs()
    if pkgs then
      local match = {}
      if #words > 1 and #words[#words] > 0 then
        for _, value in ipairs(pkgs) do
          if string.match(value, words[#words]) then
            table.insert(match, value)
          end
        end
      else
        match = pkgs
      end
      log(match)
      return match or {}
    end
  end
  return ''
end

-- go output doc in plain text
-- if the line start with 4 spaces, it is plain text
-- if the line start with 0 spaces, or multiple of 8 spaces, it is a go code block
-- wrap the go code block with ```go
local function doc_output_parser(doclines)
  local lines = {}
  local code_block = false
  for _, line in ipairs(doclines) do
    -- if line start with 0 spaces, or multiple of 8 spaces, it is a go code block
    local leading_spaces = string.match(line, '^%s*')
    if #leading_spaces == 0 or (#leading_spaces % 8 == 0 and code_block) then
      -- this is code block
      if not code_block then
        table.insert(lines, '```go')
        code_block = true
      end
      table.insert(lines, line)
    else
      if code_block then
        table.insert(lines, '```')
        code_block = false
      end
      table.insert(lines, line)
    end
  end

  if code_block then
    table.insert(lines, '```')
  end

  return lines
end

m.run = function(fargs)
  log(fargs)

  if vim.fn.empty(fargs) == 1 then
    return vim.lsp.buf.hover()
  end

  local setup = { 'go', 'doc', unpack(fargs or {}) }
  -- get height and width of the window
  local height = math.floor(vim.api.nvim_get_option('lines') * 0.4)
  local max_height = math.floor(vim.api.nvim_get_option('lines') * 0.8)
  local width = math.floor(vim.api.nvim_get_option('columns') * 0.62)
  local max_width = math.floor(vim.api.nvim_get_option('columns') * 0.8)

  local max_linewidth

  --
  return vfn.jobstart(setup, {
    on_stdout = function(_, data, _)
      data, max_linewidth = utils.handle_job_data(data)
      if not data then
        return
      end
      if #data == 0 then
        vim.notify('no doc found', vim.log.levels.WARN)
        return
      end
      local markdown = doc_output_parser(data)

      log('go doc first lines', data[1], markdown[1], markdown[2], markdown[3])
      -- log('go doc first lines', data, markdown)

      height = math.min(#data, max_height - 2)
      width = math.min(max_linewidth, width)

      local close_events = { 'CursorMoved', 'CursorMovedI', 'BufHidden', 'InsertCharPre' }
      local config = {
        close_events = close_events,
        focusable = true,
        border = 'rounded',
        width = width,
        height = height,
        max_width = max_width,
        max_height = max_height,
        offset_x = (vim.api.nvim_get_option('columns') - width) / 2 - 1,
        offset_y = math.max(3, (vim.api.nvim_get_option('lines') - height) / 2 - 1) - 1,
        relative = 'editor',
        title = table.concat(fargs, ' '),
      }
      vim.lsp.util.open_floating_preview(markdown, 'markdown', config)
    end,
  }),
    setup
end

-- ─── GoDocAI ─────────────────────────────────────────────────────────────────

local doc_ai_system_prompt =
  [[You are a Go documentation expert. The user will give you a vague or partial query about a Go function, method, type, or package, along with source code and/or doc output that was found.

Your task is to produce clear, comprehensive, human-readable documentation in Markdown format for the matched symbol(s).

For each symbol found, include:
1. **Signature** — the full function/method/type signature in a Go code block
2. **Description** — a clear explanation of what it does, its purpose, and typical usage
3. **Parameters** — describe each parameter (if applicable)
4. **Return values** — describe each return value (if applicable)
5. **Example** — a short usage example in a Go code block (if helpful)
6. **Notes** — any caveats, common mistakes, or related functions worth mentioning

If the source code includes existing comments/doc, incorporate and expand on them.
If multiple symbols match, document each one separately.
Keep the output concise but informative. Do NOT include any preamble like "Here is the documentation".
]]

--- Try to find source code for a symbol using multiple strategies:
--- 1. `go doc -src` for an exact or partial match
--- 2. `go doc` (without -src) for doc-only output
--- 3. gopls workspace/symbol for fuzzy lookup, then read the source
--- Returns (source_text, symbol_label) or (nil, error_msg)
local function find_symbol_source(query, callback)
  -- Strategy 1: try `go doc -all` first to get doc text
  local doc_cmd = string.format('go doc -all %s 2>/dev/null', vim.fn.shellescape(query))
  local doc_text = vim.fn.system(doc_cmd)
  local doc_ok = (vim.v.shell_error == 0 and doc_text and vim.trim(doc_text) ~= '')

  -- Strategy 2: try `go doc -src` to get source code
  local src_cmd = string.format('go doc -src %s 2>/dev/null', vim.fn.shellescape(query))
  local src_text = vim.fn.system(src_cmd)
  local src_ok = (vim.v.shell_error == 0 and src_text and vim.trim(src_text) ~= '')

  if doc_ok or src_ok then
    local combined = ''
    if doc_ok then
      combined = combined .. '--- go doc output ---\n' .. vim.trim(doc_text) .. '\n\n'
    end
    if src_ok then
      combined = combined .. '--- source code ---\n' .. vim.trim(src_text)
    end
    callback(combined, query)
    return
  end

  -- Strategy 3: use gopls workspace/symbol for fuzzy matching
  local clients = vim.lsp.get_clients({ bufnr = 0, name = 'gopls' })
  if not clients or #clients == 0 then
    callback(nil, 'no documentation found for "' .. query .. '" (go doc failed and gopls not available)')
    return
  end

  vim.lsp.buf_request(0, 'workspace/symbol', { query = query }, function(err, result)
    if err or not result or #result == 0 then
      callback(nil, 'no symbols found matching "' .. query .. '"')
      return
    end

    vim.schedule(function()
      -- Collect up to 5 best matches
      local matches = {}
      for i, sym in ipairs(result) do
        if i > 5 then
          break
        end
        local loc = sym.location
        if loc and loc.uri then
          local fpath = vim.uri_to_fname(loc.uri)
          local line = (loc.range and loc.range.start and loc.range.start.line) or 0
          table.insert(matches, {
            name = sym.name,
            container = sym.containerName or '',
            filepath = fpath,
            line = line,
          })
        end
      end

      if #matches == 0 then
        callback(nil, 'no readable symbols found for "' .. query .. '"')
        return
      end

      -- Read source around each match
      local parts = {}
      for _, match in ipairs(matches) do
        local ok_file, file_lines = pcall(function()
          return vim.fn.readfile(match.filepath)
        end)
        if ok_file and file_lines then
          local start_line = math.max(0, match.line - 2)
          local end_line = math.min(#file_lines, match.line + 50)
          local snippet = {}
          for l = start_line + 1, end_line do
            table.insert(snippet, file_lines[l])
          end
          local label = match.name
          if match.container ~= '' then
            label = match.container .. '.' .. match.name
          end
          table.insert(
            parts,
            string.format(
              '--- %s (from %s:%d) ---\n%s',
              label,
              vim.fn.fnamemodify(match.filepath, ':~:.'),
              match.line + 1,
              table.concat(snippet, '\n')
            )
          )
        end
      end

      if #parts == 0 then
        callback(nil, 'found symbols but could not read source for "' .. query .. '"')
        return
      end

      callback(table.concat(parts, '\n\n'), query)
    end)
  end)
end

--- Entry point for :GoDocAI {query}
--- Finds the symbol using go doc / gopls, then generates rich AI documentation.
--- @param opts table  Standard nvim command opts (fargs)
m.run_ai = function(opts)
  local fargs = (type(opts) == 'table' and opts.fargs) or opts or {}
  local query = vim.trim(table.concat(fargs, ' '))

  if query == '' then
    -- Fallback: use the word under cursor
    query = vim.fn.expand('<cword>')
    if not query or query == '' then
      vim.notify('go.nvim [DocAI]: please provide a query or place cursor on a symbol', vim.log.levels.WARN)
      return
    end
  end

  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.enable then
    vim.notify(
      'go.nvim [DocAI]: AI is disabled. Set ai = { enable = true } in go.nvim setup to use GoDocAI',
      vim.log.levels.WARN
    )
    return
  end

  vim.notify('go.nvim [DocAI]: searching for "' .. query .. '" …', vim.log.levels.INFO)

  find_symbol_source(query, function(source, label)
    if not source then
      vim.notify('go.nvim [DocAI]: ' .. (label or 'symbol not found'), vim.log.levels.WARN)
      return
    end

    local user_msg = string.format('Query: %s\n\n%s', label, source)

    vim.notify('go.nvim [DocAI]: generating documentation …', vim.log.levels.INFO)

    require('go.ai').request(doc_ai_system_prompt, user_msg, { max_tokens = 1500 }, function(resp)
      resp = vim.trim(resp)
      if resp == '' then
        vim.notify('go.nvim [DocAI]: AI returned empty response', vim.log.levels.WARN)
        return
      end

      -- Display in a floating window
      local lines = vim.split(resp, '\n', { plain = true })
      local height = math.min(#lines + 2, math.floor(vim.api.nvim_get_option('lines') * 0.8))
      local width = math.min(80, math.floor(vim.api.nvim_get_option('columns') * 0.8))
      -- Find the longest line to set width
      for _, line in ipairs(lines) do
        if #line > width then
          width = math.min(#line + 2, math.floor(vim.api.nvim_get_option('columns') * 0.9))
        end
      end

      local float_config = {
        close_events = { 'CursorMoved', 'CursorMovedI', 'BufHidden', 'InsertCharPre' },
        focusable = true,
        border = 'rounded',
        width = width,
        height = height,
        max_width = math.floor(vim.api.nvim_get_option('columns') * 0.9),
        max_height = math.floor(vim.api.nvim_get_option('lines') * 0.9),
        offset_x = (vim.api.nvim_get_option('columns') - width) / 2 - 1,
        offset_y = math.max(3, (vim.api.nvim_get_option('lines') - height) / 2 - 1) - 1,
        relative = 'editor',
        title = 'GoDocAI: ' .. query,
      }
      vim.lsp.util.open_floating_preview(lines, 'markdown', float_config)
    end)
  end)
end

return m
