-- GoAIEdit: AI-powered code editing with diff preview for go.nvim
-- Uses Neovim 0.11+ virt_lines for inline diff preview.
local M = {}

local provider = require('go.ai.provider')
local macros = require('go.ai.macros')
local session = require('go.ai.session')

local edit_system_prompt = [[You are an expert Go developer. The user will provide Go code and an instruction to modify it.

Rules:
1. Return ONLY the modified Go code in a single fenced code block (```go ... ```).
2. No explanation or commentary outside the code block.
3. Preserve the original code structure, formatting, and comments unless the instruction specifically asks to change them.
4. Only make changes that are directly requested.
5. Return the complete modified code, not just the changed parts.
]]

--- Extract Go code from LLM response (handles fenced code blocks)
local function extract_code(response)
  -- Try fenced Go code block
  local code = response:match('```go%s*\n(.-)\n?```')
  if code then
    return vim.trim(code)
  end
  -- Try generic fenced block
  code = response:match('```%s*\n(.-)\n?```')
  if code then
    return vim.trim(code)
  end
  -- Fallback: strip any leading/trailing fences
  code = response:gsub('^```%w*\n?', ''):gsub('\n?```$', '')
  return vim.trim(code)
end

-- ─── Simple LCS-based line diff ─────────────────────────────────────────────

--- Compute the Longest Common Subsequence table for two arrays of lines.
--- Returns a 2D table where lcs[i][j] = length of LCS of a[1..i], b[1..j].
local function lcs_table(a, b)
  local m, n = #a, #b
  local t = {}
  for i = 0, m do
    t[i] = {}
    for j = 0, n do
      t[i][j] = 0
    end
  end
  for i = 1, m do
    for j = 1, n do
      if a[i] == b[j] then
        t[i][j] = t[i - 1][j - 1] + 1
      else
        t[i][j] = math.max(t[i - 1][j], t[i][j - 1])
      end
    end
  end
  return t
end

--- Produce a list of diff hunks from two line arrays.
--- Each hunk is { type = "equal"|"delete"|"insert", lines = {...}, old_start, new_start }
--- old_start/new_start are 1-based indices into the respective arrays.
local function compute_diff(old_lines, new_lines)
  local t = lcs_table(old_lines, new_lines)
  -- Backtrack to produce edit script
  local ops = {}
  local i, j = #old_lines, #new_lines
  while i > 0 or j > 0 do
    if i > 0 and j > 0 and old_lines[i] == new_lines[j] then
      table.insert(ops, 1, { type = 'equal', old_idx = i, new_idx = j })
      i = i - 1
      j = j - 1
    elseif j > 0 and (i == 0 or t[i][j - 1] >= t[i - 1][j]) then
      table.insert(ops, 1, { type = 'insert', new_idx = j })
      j = j - 1
    else
      table.insert(ops, 1, { type = 'delete', old_idx = i })
      i = i - 1
    end
  end
  return ops
end

-- ─── Highlight groups ───────────────────────────────────────────────────────

local ns = vim.api.nvim_create_namespace('GoAIEdit')

-- Forward declaration for split diff (used by inline diff's 'gd' keymap)
local open_split_diff

local function ensure_hl_groups()
  -- Deleted lines: red background with strikethrough
  vim.api.nvim_set_hl(0, 'GoAIEditDelete', { bg = '#3c1f1f', fg = '#cc6666', strikethrough = true, default = true })
  -- Added lines: green background
  vim.api.nvim_set_hl(0, 'GoAIEditAdd', { bg = '#1f3c1f', fg = '#b5bd68', default = true })
  -- Dimmed unchanged lines in the edited region
  vim.api.nvim_set_hl(0, 'GoAIEditDim', { fg = '#666666', default = true })
  -- Separator hint line
  vim.api.nvim_set_hl(0, 'GoAIEditHint', { fg = '#888888', italic = true, default = true })
end

-- ─── Inline diff view using virt_lines ──────────────────────────────────────

--- Show an inline diff preview in the current buffer using virtual lines.
--- Deleted lines appear as red strikethrough virtual lines.
--- Added lines appear as green virtual lines.
--- @param bufnr number       Buffer number
--- @param start_line number  1-based start line of the edited region
--- @param end_line number    1-based end line of the edited region (inclusive)
--- @param new_lines table    Array of replacement lines from the LLM
local function show_inline_diff(bufnr, start_line, end_line, new_lines)
  ensure_hl_groups()

  local old_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local ops = compute_diff(old_lines, new_lines)

  -- Clear any previous preview
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- We walk through the ops and attach virtual lines to the appropriate buffer lines.
  -- For each buffer line in the region, we collect the virtual lines that should appear below it.
  --
  -- Strategy:
  --   - 'equal' lines: dim the original line, no virtual lines needed
  --   - 'delete' lines: highlight the original line in red (it will be removed)
  --   - 'insert' lines: show as green virtual lines below the previous anchor line
  --
  -- We process ops and group consecutive inserts/deletes into hunks,
  -- placing virtual lines after the last equal line before the hunk.

  -- First, dim all lines in the region
  for line = start_line, end_line do
    vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
      line_hl_group = 'GoAIEditDim',
      priority = 10,
    })
  end

  -- Now process the diff operations
  -- We need to track which buffer line (in the old region) we're anchoring virtual lines to
  local pending_virt = {} -- virtual lines to attach after current anchor

  -- anchor_buf_line: the 0-based buffer line to attach pending virtual lines to
  -- defaults to start_line - 1 (line before the region) if inserts come first
  local anchor_buf_line = start_line - 2 -- will be adjusted; -2 means "before region start"

  local function flush_virt()
    if #pending_virt == 0 then
      return
    end
    local attach_line = math.max(0, anchor_buf_line)
    -- If anchor is before the region, attach to the first line of the region
    if anchor_buf_line < start_line - 1 then
      attach_line = start_line - 1
    end
    vim.api.nvim_buf_set_extmark(bufnr, ns, attach_line, 0, {
      virt_lines = pending_virt,
      virt_lines_above = (anchor_buf_line < start_line - 1),
      priority = 100,
    })
    pending_virt = {}
  end

  for _, op in ipairs(ops) do
    if op.type == 'equal' then
      flush_virt()
      -- Update anchor to this equal line in the buffer
      anchor_buf_line = start_line - 1 + op.old_idx - 1
      -- Remove dim, show as normal
      vim.api.nvim_buf_set_extmark(bufnr, ns, anchor_buf_line, 0, {
        line_hl_group = '',
        priority = 10,
      })
    elseif op.type == 'delete' then
      flush_virt()
      -- Mark the original line as deleted (red highlight)
      local buf_line = start_line - 1 + op.old_idx - 1
      anchor_buf_line = buf_line
      vim.api.nvim_buf_set_extmark(bufnr, ns, buf_line, 0, {
        line_hl_group = 'GoAIEditDelete',
        priority = 20,
      })
    elseif op.type == 'insert' then
      -- Queue as virtual line below current anchor
      local text = new_lines[op.new_idx] or ''
      table.insert(pending_virt, { { '+ ' .. text, 'GoAIEditAdd' } })
    end
  end
  flush_virt()

  -- Add hint line at the end of the region
  local hint_line = start_line - 1 + #old_lines - 1
  if hint_line < 0 then
    hint_line = 0
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns, hint_line, 0, {
    virt_lines = { { { '  [ga/CR = accept] [q/Esc = reject] [gd = split diff]', 'GoAIEditHint' } } },
    priority = 50,
  })
end

--- Clear the inline diff preview and remove temporary keymaps.
local function clear_inline_diff(bufnr, keymap_ids)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  if keymap_ids then
    for _, key in ipairs(keymap_ids) do
      pcall(vim.keymap.del, 'n', key, { buffer = bufnr })
    end
  end
end

--- Open inline diff and bind accept/reject keymaps.
--- @param bufnr number
--- @param start_line number  1-based
--- @param end_line number    1-based inclusive
--- @param new_code string
local function open_inline_diff(bufnr, start_line, end_line, new_code)
  local new_lines = vim.split(new_code, '\n', { plain = true })
  show_inline_diff(bufnr, start_line, end_line, new_lines)

  local bound_keys = { 'ga', '<CR>', 'q', '<Esc>', 'gd' }
  local map_opts = { buffer = bufnr, nowait = true, silent = true }

  local function accept()
    clear_inline_diff(bufnr, bound_keys)
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_lines)
    vim.notify('[GoAIEdit]: changes applied', vim.log.levels.INFO)
  end

  local function reject()
    clear_inline_diff(bufnr, bound_keys)
    vim.notify('[GoAIEdit]: changes discarded', vim.log.levels.INFO)
  end

  local function split_diff()
    clear_inline_diff(bufnr, bound_keys)
    open_split_diff(bufnr, start_line, end_line, new_code)
  end

  vim.keymap.set('n', 'ga', accept, map_opts)
  vim.keymap.set('n', '<CR>', accept, map_opts)
  vim.keymap.set('n', 'q', reject, map_opts)
  vim.keymap.set('n', '<Esc>', reject, map_opts)
  vim.keymap.set('n', 'gd', split_diff, map_opts)

  vim.notify('[GoAIEdit]: inline diff shown — ga/CR=accept, q/Esc=reject, gd=split diff', vim.log.levels.INFO)
end

-- ─── Split diff view (fallback / alternative) ──────────────────────────────

--- Open a traditional vertical split diff view.
--- @param orig_bufnr number
--- @param start_line number  1-based
--- @param end_line number    1-based inclusive
--- @param new_code string
open_split_diff = function(orig_bufnr, start_line, end_line, new_code)
  local new_lines = vim.split(new_code, '\n', { plain = true })
  local orig_win = vim.api.nvim_get_current_win()

  local scratch_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, new_lines)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = scratch_buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = scratch_buf })
  vim.api.nvim_set_option_value('filetype', 'go', { buf = scratch_buf })
  vim.api.nvim_buf_set_name(scratch_buf, '[GoAIEdit Preview]')
  vim.api.nvim_set_option_value('modifiable', false, { buf = scratch_buf })

  vim.cmd('vsplit')
  local preview_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(preview_win, scratch_buf)

  vim.api.nvim_set_current_win(orig_win)
  vim.cmd('diffthis')
  vim.api.nvim_set_current_win(preview_win)
  vim.cmd('diffthis')

  local function cleanup()
    if vim.api.nvim_win_is_valid(preview_win) then
      vim.api.nvim_set_current_win(preview_win)
      vim.cmd('diffoff')
      vim.api.nvim_win_close(preview_win, true)
    end
    if vim.api.nvim_win_is_valid(orig_win) then
      vim.api.nvim_set_current_win(orig_win)
      vim.cmd('diffoff')
    end
  end

  local function accept()
    vim.api.nvim_set_option_value('modifiable', true, { buf = scratch_buf })
    local final_lines = vim.api.nvim_buf_get_lines(scratch_buf, 0, -1, false)
    cleanup()
    vim.api.nvim_buf_set_lines(orig_bufnr, start_line - 1, end_line, false, final_lines)
    vim.notify('[GoAIEdit]: changes applied', vim.log.levels.INFO)
  end

  local function reject()
    cleanup()
    vim.notify('[GoAIEdit]: changes discarded', vim.log.levels.INFO)
  end

  local smap = { buffer = scratch_buf, nowait = true, silent = true }
  vim.keymap.set('n', '<CR>', accept, smap)
  vim.keymap.set('n', 'ga', accept, smap)
  vim.keymap.set('n', 'q', reject, smap)
  vim.keymap.set('n', '<Esc>', reject, smap)

  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = scratch_buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(orig_win) then
        pcall(function()
          vim.api.nvim_set_current_win(orig_win)
          vim.cmd('diffoff')
        end)
      end
    end,
  })

  vim.notify('[GoAIEdit]: split diff — <CR>/ga = accept, q/<Esc> = reject', vim.log.levels.INFO)
end

--- Entry point for :GoAIEdit <instruction>
--- @param opts table  Standard nvim command opts
function M.run(opts)
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.enable then
    vim.notify(
      'go.nvim [AI]: AI is disabled. Set ai = { enable = true } in go.nvim setup',
      vim.log.levels.WARN
    )
    return
  end

  local fargs = (type(opts) == 'table' and opts.fargs) or {}
  -- Parse -h [N] flag for conversation history
  local history_pairs = 0 -- default: no history unless -h specified
  local filtered_args = {}
  local i = 1
  while i <= #fargs do
    if fargs[i] == '-h' or fargs[i] == '--history' then
      local next_arg = fargs[i + 1]
      if next_arg and next_arg:match('^%d+$') then
        history_pairs = tonumber(next_arg)
        i = i + 2
      else
        history_pairs = 0
        i = i + 1
      end
    else
      table.insert(filtered_args, fargs[i])
      i = i + 1
    end
  end
  local instruction = vim.trim(table.concat(filtered_args, ' '))

  local bufnr = vim.api.nvim_get_current_buf()
  local code_lines
  local start_line, end_line

  -- Visual selection takes priority
  if type(opts) == 'table' and opts.range and opts.range == 2 then
    code_lines = vim.api.nvim_buf_get_lines(bufnr, opts.line1 - 1, opts.line2, false)
    start_line = opts.line1
    end_line = opts.line2
  else
    -- Fall back to enclosing function
    local func_text, _, sr, er = macros.get_enclosing_func(bufnr)
    if func_text and func_text ~= '' and sr and er then
      code_lines = vim.api.nvim_buf_get_lines(bufnr, sr - 1, er, false)
      start_line = sr
      end_line = er
    end
  end

  if not code_lines or #code_lines == 0 then
    vim.notify('[GoAIEdit]: no code selected and cursor not inside a function', vim.log.levels.WARN)
    return
  end

  local code = table.concat(code_lines, '\n')

  local function do_edit(instr)
    if instr == '' then
      vim.notify('[GoAIEdit]: empty instruction', vim.log.levels.WARN)
      return
    end

    local user_msg = string.format(
      'File: %s\n\nInstruction: %s\n\n```go\n%s\n```',
      vim.fn.expand('%:t'),
      instr,
      code
    )

    -- Build session-aware request options
    local req_opts = { max_tokens = 2000, temperature = 0 }
    if history_pairs > 0 then
      req_opts.history = session.recent_messages('edit', history_pairs)
    end
    local prev_id = session.last_response_id('edit')
    if prev_id then
      req_opts.previous_response_id = prev_id
    end

    -- Save user message to session
    session.append({ command = 'edit', role = 'user', content = user_msg })

    vim.notify('[GoAIEdit]: thinking …', vim.log.levels.INFO)
    provider.request(edit_system_prompt, user_msg, req_opts, function(resp, response_id)
      -- Save assistant response to session
      session.append({ command = 'edit', role = 'assistant', content = resp, response_id = response_id })
      local new_code = extract_code(resp)
      if not new_code or new_code == '' then
        vim.notify('[GoAIEdit]: no code in response', vim.log.levels.WARN)
        return
      end
      -- If the response is identical, nothing to do
      if new_code == code then
        vim.notify('[GoAIEdit]: no changes suggested', vim.log.levels.INFO)
        return
      end
      -- Use inline diff (virt_lines) on Neovim 0.11+, fall back to split diff
      if vim.fn.has('nvim-0.11') == 1 then
        open_inline_diff(bufnr, start_line, end_line, new_code)
      else
        open_split_diff(bufnr, start_line, end_line, new_code)
      end
    end)
  end

  if instruction ~= '' then
    do_edit(instruction)
  else
    vim.ui.input({ prompt = 'GoAIEdit> ' }, function(input)
      if input and input ~= '' then
        do_edit(input)
      end
    end)
  end
end

return M
