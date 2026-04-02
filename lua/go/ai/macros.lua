-- Prompt macro expansion (/buffer, /file, /function) for go.nvim AI features
local M = {}

--- Replace first plain occurrence of `target` in `str` with `replacement`.
local function plain_replace(str, target, replacement)
  local pos = str:find(target, 1, true)
  if not pos then
    return str
  end
  return str:sub(1, pos - 1) .. replacement .. str:sub(pos + #target)
end

M.plain_replace = plain_replace

--- Get the enclosing function/method node and its text from the buffer.
--- Returns (func_text, func_name, start_row, end_row) or (nil, nil) if cursor is not inside a function.
--- start_row and end_row are 1-based line numbers.
local function get_enclosing_func(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local current_node = vim.treesitter.get_node({ bufnr = bufnr })
  if not current_node then
    return nil, nil
  end
  local expr = current_node
  while expr do
    if expr:type() == 'function_declaration' or expr:type() == 'method_declaration' then
      break
    end
    expr = expr:parent()
  end
  if not expr then
    return nil, nil
  end

  local func_text = vim.treesitter.get_node_text(expr, bufnr) or ''

  -- Extract function name
  local name_node = expr:field('name')
  local func_name = ''
  if name_node and name_node[1] then
    func_name = vim.treesitter.get_node_text(name_node[1], bufnr) or ''
  end

  -- Extract line range (0-based from treesitter, convert to 1-based)
  local sr, _, er, _ = expr:range()

  return func_text, func_name, sr + 1, er + 1
end

M.get_enclosing_func = get_enclosing_func

--- Expand context macros (/buffer, /file, /function) in a prompt string.
--- Async because /buffer and /file use vim.ui.select.
--- Replaces macros with the name; file/buffer content is returned separately
--- as `context_attachments` so callers can place it appropriately.
--- @param prompt string        The prompt text, possibly containing macros
--- @param source_bufnr number  The buffer that was active when the command was invoked
--- @param callback function    Called with (expanded_prompt, context_attachments)
---   context_attachments is a string of code blocks (may be empty)
function M.expand(prompt, source_bufnr, callback)
  local has_buffer = prompt:find('/buffer', 1, true) ~= nil
  local has_file = prompt:find('/file', 1, true) ~= nil
  local has_function = prompt:find('/function', 1, true) ~= nil

  if not (has_buffer or has_file or has_function) then
    callback(prompt, '')
    return
  end

  local result = prompt
  local attachments = {}

  -- /function is synchronous: inline the function body directly
  if has_function then
    local func_text = get_enclosing_func(source_bufnr)
    if func_text and func_text ~= '' then
      result = plain_replace(result, '/function', string.format('\n```go\n%s\n```\n', func_text))
    else
      vim.notify('go.nvim [AI]: /function — no enclosing function found', vim.log.levels.WARN)
      result = plain_replace(result, '/function', '')
    end
  end

  -- /buffer: select from loaded listed buffers, replace with name, attach content
  local function resolve_buffer(text, cb)
    if not has_buffer then
      cb(text)
      return
    end
    local items = {}
    local default_idx = 1
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted then
        local name = vim.api.nvim_buf_get_name(b)
        if name ~= '' then
          local short = vim.fn.fnamemodify(name, ':~:.')
          table.insert(items, { bufnr = b, display = short })
          if b == source_bufnr then
            default_idx = #items
          end
        end
      end
    end
    if #items == 0 then
      vim.notify('go.nvim [AI]: /buffer — no listed buffers', vim.log.levels.WARN)
      cb(plain_replace(text, '/buffer', ''))
      return
    end
    -- Move default to first position
    if default_idx > 1 then
      local def = table.remove(items, default_idx)
      table.insert(items, 1, def)
    end
    vim.ui.select(items, {
      prompt = 'Select buffer (/buffer):',
      format_item = function(item)
        return item.display
      end,
    }, function(choice)
      if choice then
        local buf_lines = vim.api.nvim_buf_get_lines(choice.bufnr, 0, -1, false)
        local content = table.concat(buf_lines, '\n')
        local ft = vim.bo[choice.bufnr].filetype or 'go'
        text = plain_replace(text, '/buffer', '`' .. choice.display .. '`')
        table.insert(attachments, string.format('## Buffer: %s\n```%s\n%s\n```', choice.display, ft, content))
      else
        text = plain_replace(text, '/buffer', '')
      end
      cb(text)
    end)
  end

  -- /file: select from Go files in workspace, replace with name, attach content
  local function resolve_file(text, cb)
    if not has_file then
      cb(text)
      return
    end
    local current_file = vim.api.nvim_buf_get_name(source_bufnr)
    local cwd = vim.fn.getcwd()
    local go_files = vim.fn.glob(cwd .. '/**/*.go', false, true)
    local items = {}
    local default_idx = 1
    for _, f in ipairs(go_files) do
      local rel = vim.fn.fnamemodify(f, ':.')
      table.insert(items, { path = f, display = rel })
      if f == current_file then
        default_idx = #items
      end
    end
    if #items == 0 then
      vim.notify('go.nvim [AI]: /file — no Go files found in workspace', vim.log.levels.WARN)
      cb(plain_replace(text, '/file', ''))
      return
    end
    if default_idx > 1 then
      local def = table.remove(items, default_idx)
      table.insert(items, 1, def)
    end
    vim.ui.select(items, {
      prompt = 'Select file (/file):',
      format_item = function(item)
        return item.display
      end,
    }, function(choice)
      if choice then
        local fh = io.open(choice.path, 'r')
        if fh then
          local content = fh:read('*a')
          fh:close()
          text = plain_replace(text, '/file', '`' .. choice.display .. '`')
          table.insert(attachments, string.format('## File: %s\n```go\n%s\n```', choice.display, content))
        else
          text = plain_replace(text, '/file', '`' .. choice.display .. '`')
        end
      else
        text = plain_replace(text, '/file', '')
      end
      cb(text)
    end)
  end

  -- Chain: resolve_buffer → resolve_file → callback
  resolve_buffer(result, function(after_buffer)
    resolve_file(after_buffer, function(after_file)
      callback(after_file, table.concat(attachments, '\n\n'))
    end)
  end)
end

--- Check whether a prompt contains any context macro
--- @param prompt string
--- @return boolean
function M.has_macros(prompt)
  return prompt:find('/buffer', 1, true) ~= nil
    or prompt:find('/file', 1, true) ~= nil
    or prompt:find('/function', 1, true) ~= nil
end

return M
