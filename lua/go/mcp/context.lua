local M = {}
local log = require('go.utils').log

--- Parse a unified diff to extract changed file/line info
---@param diff_text string
---@return table[] list of {file, start_line, end_line}
function M.parse_diff_hunks(diff_text)
  local hunks = {}
  local current_file = nil
  for line in diff_text:gmatch('[^\n]+') do
    local file = line:match('^%+%+%+ b/(.+%.go)$')
    if file then
      current_file = file
    end
    local start, count = line:match('^@@ %-[%d,]+ %+(%d+),?(%d*) @@')
    if start and current_file then
      count = tonumber(count) or 1
      table.insert(hunks, {
        file = current_file,
        start_line = tonumber(start),
        end_line = tonumber(start) + count - 1,
      })
    end
  end
  return hunks
end

--- Load a file into a buffer and ensure treesitter + LSP are ready
---@param filepath string absolute path
---@return number|nil bufnr
local function ensure_buffer(filepath)
  if vim.fn.filereadable(filepath) ~= 1 then
    return nil
  end
  local bufnr = vim.fn.bufadd(filepath)
  vim.fn.bufload(bufnr)
  if vim.bo[bufnr].filetype == '' then
    vim.bo[bufnr].filetype = 'go'
  end
  return bufnr
end

--- Read a specific line from a file (1-indexed)
---@param filepath string absolute path
---@param lnum number 1-indexed line number
---@return string|nil
local function read_line(filepath, lnum)
  -- Try from loaded buffer first
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    local lines = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)
    if lines and lines[1] then
      return vim.trim(lines[1])
    end
  end
  -- Fall back to reading from disk
  local f = io.open(filepath, 'r')
  if not f then
    return nil
  end
  local i = 0
  for line in f:lines() do
    i = i + 1
    if i == lnum then
      f:close()
      return vim.trim(line)
    end
  end
  f:close()
  return nil
end

--- Check if a filename is a test file
---@param fname string
---@return boolean
local function is_test_file(fname)
  return fname:match('_test%.go$') ~= nil
end

--- Format a reference location, including line text for non-test files
---@param uri string LSP URI
---@param line number 0-indexed
---@return string
local function format_ref_location(uri, line)
  local fpath = vim.uri_to_fname(uri)
  local fname = vim.fn.fnamemodify(fpath, ':.')
  local lnum = line + 1

  if is_test_file(fname) then
    return string.format('\t- %s:%d', fname, lnum)
  end

  local text = read_line(fpath, lnum)
  if text then
    return string.format('\t- %s:%d  `%s`', fname, lnum, text)
  end
  return string.format('\t- %s:%d', fname, lnum)
end

--- Format a caller location, including line text for non-test files
---@param uri string LSP URI
---@param line number 0-indexed
---@param caller_name string
---@return string
local function format_caller_location(uri, line, caller_name)
  local fpath = vim.uri_to_fname(uri)
  local fname = vim.fn.fnamemodify(fpath, ':.')
  local lnum = line + 1

  if is_test_file(fname) then
    return string.format('\t- %s:%d — %s()', fname, lnum, caller_name)
  end

  local text = read_line(fpath, lnum)
  if text then
    return string.format('\t- %s:%d — %s()  `%s`', fname, lnum, caller_name, text)
  end
  return string.format('\t- %s:%d — %s()', fname, lnum, caller_name)
end

--- Use treesitter to find symbols (functions, types, methods) at given lines
---@param bufnr number
---@param start_line number (0-indexed)
---@param end_line number (0-indexed)
---@return table[] symbols [{name, kind, line, col}]
function M.find_symbols_in_range(bufnr, start_line, end_line)
  local symbols = {}
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'go')
  if not ok or not parser then
    return symbols
  end
  local trees = parser:parse()
  if not trees or not trees[1] then
    return symbols
  end
  local root = trees[1]:root()

  local query_text = [[
    (function_declaration name: (identifier) @func_name) @func
    (method_declaration name: (field_identifier) @method_name) @method
    (type_declaration (type_spec name: (type_identifier) @type_name)) @type
  ]]

  local qok, query = pcall(vim.treesitter.query.parse, 'go', query_text)
  if not qok then
    return symbols
  end

  for id, node, _ in query:iter_captures(root, bufnr, start_line, end_line + 1) do
    local name = query.captures[id]
    if name == 'func_name' or name == 'method_name' or name == 'type_name' then
      local text = vim.treesitter.get_node_text(node, bufnr)
      local row, col = node:start()
      local kind = name:match('^(%w+)_')
      table.insert(symbols, { name = text, kind = kind, line = row, col = col })
    end
  end
  return symbols
end

--- Get symbol context using the EXISTING running LSP client (no second gopls)
---@param bufnr number
---@param line number 0-indexed
---@param col number 0-indexed
---@param callback function(context_string)
function M.get_symbol_context_via_lsp(bufnr, line, col, callback)
  local results = {}
  local pending = 3

  -- Find an attached gopls client for this buffer
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = 'gopls' })
  if #clients == 0 then
    clients = vim.lsp.get_clients({ name = 'gopls' })
    if #clients == 0 then
      callback('(no gopls LSP client available)')
      return
    end
    vim.lsp.buf_attach_client(bufnr, clients[1].id)
  end

  local function make_params()
    return {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) },
      position = { line = line, character = col },
    }
  end

  local function check_done()
    pending = pending - 1
    if pending <= 0 then
      callback(table.concat(results, '\n'))
    end
  end

  -- 1. References
  local ref_params = make_params()
  ref_params.context = { includeDeclaration = false }
  vim.lsp.buf_request(bufnr, 'textDocument/references', ref_params, function(err, result)
    if not err and result and #result > 0 then
      local refs = {}
      local seen = {}
      for _, ref in ipairs(result) do
        local fname = vim.fn.fnamemodify(vim.uri_to_fname(ref.uri), ':.')
        local key = string.format('- %s:%d', fname, ref.range.start.line + 1)
        if not seen[key] then
          seen[key] = true
          table.insert(refs, format_ref_location(ref.uri, ref.range.start.line))
        end
        if #refs >= 10 then
          table.insert(refs, string.format('  ... and %d more', #result - 10))
          break
        end
      end
      table.insert(results, '\n* References (' .. #result .. '):\n' .. table.concat(refs, '\n'))
    end
    check_done()
  end)

  -- 2. Incoming calls (who calls this?)
  vim.lsp.buf_request(bufnr, 'textDocument/prepareCallHierarchy', make_params(), function(err, result)
    if err or not result or #result == 0 then
      check_done()
      return
    end
    vim.lsp.buf_request(bufnr, 'callHierarchy/incomingCalls', { item = result[1] }, function(err2, calls)
      if not err2 and calls and #calls > 0 then
        local callers = {}
        for _, call in ipairs(calls) do
          table.insert(callers, format_caller_location(
            call.from.uri, call.from.range.start.line, call.from.name
          ))
          if #callers >= 15 then
            table.insert(callers, string.format('  ... and %d more', #calls - 15))
            break
          end
        end
        table.insert(results, '\n* Callers (' .. #calls .. '):\n' .. table.concat(callers, '\n'))
      end
      check_done()
    end)
  end)

  -- 3. Implementations (for interfaces/methods)
  vim.lsp.buf_request(bufnr, 'textDocument/implementation', make_params(), function(err, result)
    if not err and result and #result > 0 then
      local impls = {}
      for _, impl in ipairs(result) do
        table.insert(impls, format_ref_location(impl.uri, impl.range.start.line))
        if #impls >= 15 then
          break
        end
      end
      table.insert(results, '\n* Implementations (' .. #result .. '):\n' .. table.concat(impls, '\n'))
    end
    check_done()
  end)
end

-- Backward-compatible alias
M.get_symbol_context = M.get_symbol_context_via_lsp

--- Gather semantic context for all changed symbols across diff files
--- Uses the EXISTING gopls LSP client instead of a separate MCP process
---@param diff_text string
---@param callback function(semantic_context: string)
function M.gather_diff_context(diff_text, callback)
  local hunks = M.parse_diff_hunks(diff_text)

  if #hunks == 0 then
    callback('(no changed Go symbols detected)')
    return
  end

  local by_file = {}
  for _, hunk in ipairs(hunks) do
    by_file[hunk.file] = by_file[hunk.file] or {}
    table.insert(by_file[hunk.file], hunk)
  end

  local all_context = {}
  local files_pending = vim.tbl_count(by_file)

  if files_pending == 0 then
    callback('(no changed Go files)')
    return
  end

  for file, file_hunks in pairs(by_file) do
    local abs_path = vim.fn.getcwd() .. '/' .. file
    local bufnr = ensure_buffer(abs_path)

    if not bufnr then
      log('mcp/context: cannot load file', abs_path)
      files_pending = files_pending - 1
      if files_pending == 0 then
        callback(table.concat(all_context, '\n\n'))
      end
      goto continue
    end

    local symbols = {}
    for _, hunk in ipairs(file_hunks) do
      local found = M.find_symbols_in_range(bufnr, hunk.start_line - 1, hunk.end_line - 1)
      for _, sym in ipairs(found) do
        symbols[sym.name] = sym
      end
    end

    local symbol_list = vim.tbl_values(symbols)
    if #symbol_list == 0 then
      table.insert(all_context,
        string.format('## File: %s\n(changed lines do not contain function/type declarations)', file))
      files_pending = files_pending - 1
      if files_pending == 0 then
        callback(table.concat(all_context, '\n\n'))
      end
    else
      local syms_pending = #symbol_list
      for _, sym in ipairs(symbol_list) do
        local header = string.format('### Symbol: `%s` (%s) in %s:%d', sym.name, sym.kind, file, sym.line + 1)

        M.get_symbol_context_via_lsp(bufnr, sym.line, sym.col, function(ctx)
          if ctx and #ctx > 0 then
            table.insert(all_context, header .. '\n' .. ctx)
          else
            table.insert(all_context, header .. '\n(no callers/references found — possibly unexported or unused)')
          end

          syms_pending = syms_pending - 1
          if syms_pending == 0 then
            files_pending = files_pending - 1
            if files_pending == 0 then
              callback(table.concat(all_context, '\n\n'))
            end
          end
        end)
      end
    end

    ::continue::
  end
end

--- Gather context for all symbols in a single buffer (non-diff mode)
---@param bufnr number
---@param callback function(semantic_context: string)
function M.gather_buffer_context(bufnr, callback)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local symbols = M.find_symbols_in_range(bufnr, 0, line_count - 1)
  local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':.')

  if #symbols == 0 then
    callback('(no function/type declarations found in buffer)')
    return
  end

  if #symbols > 15 then
    log('mcp/context: truncating symbols from', #symbols, 'to 15')
    local truncated = {}
    for i = 1, 15 do
      truncated[i] = symbols[i]
    end
    symbols = truncated
  end

  local all_ctx = {}
  local pending = #symbols

  for _, sym in ipairs(symbols) do
    local header = string.format('* Symbol: `%s` (%s) in %s:%d', sym.name, sym.kind, file, sym.line + 1)

    M.get_symbol_context_via_lsp(bufnr, sym.line, sym.col, function(ctx)
      if ctx and #ctx > 0 then
        table.insert(all_ctx, header .. '\n' .. ctx)
      else
        table.insert(all_ctx, header .. '\n(no callers/references found)')
      end

      pending = pending - 1
      if pending == 0 then
        callback(table.concat(all_ctx, '\n\n'))
      end
    end)
  end
end

return M

