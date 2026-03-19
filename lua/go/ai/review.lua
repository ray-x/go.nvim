-- GoCodeReview: AI-powered code review for go.nvim
local M = {}

local provider = require('go.ai.provider')
local macros = require('go.ai.macros')
local ui = require('go.ai.ui')
local prompts = require('go.prompts')
local utils = require('go.utils')
local log = utils.log

-- ─── System prompts ──────────────────────────────────────────────────────────

-- stylua: ignore start
local code_review_system_prompt =
  [[You are an experienced Golang code reviewer. Your task is to review Go language source code for correctness, readability, performance, best practices, and style. Carefully analyze the given Go code snippet or file and provide specific actionable feedback to improve quality. Identify issues such as bugs, inefficient constructs, poor naming, inconsistent formatting, concurrency pitfalls, error handling mistakes, or deviations from idiomatic Go. Suggest precise code changes and explain why they improve the code.

When reviewing, reason step-by-step about each aspect of the code before concluding. Be polite, professional, and constructive.
]]
  .. prompts.review_guidelines()
  .. [[

# Instructions

1. Read the entire Go code provided.
2. For each audit category above, check whether any issues apply.
3. For each Go-specific review dimension, check whether any issues apply.
4. Assess functionality and correctness.
5. Evaluate code readability and style against Go conventions.
6. Check for performance or concurrency issues.
7. Review error handling and package usage.
8. Provide only actionable improvements — skip praise or explanations of what is already good.

# Output Format

The source code is provided with explicit line markers in the format "L<number>|" at the start of each line.
For example:
  L10| func main() {
  L11| 	os.Getenv("KEY")
  L12| }
If you find an issue on the line starting with "L11|", you MUST output line number 11.

If there are NO improvements needed:
- Output exactly one line: a brief overall summary (e.g. "Code looks idiomatic and correct.").

If there ARE improvements, output ONLY lines in vim quickfix format:
  <filename>:<line>:<col>: <severity>: [<principle>] <violation>: <message>. Refactor: <suggestion>
where <severity> is:
  error     — compile errors and logic errors only (code will not build or produces wrong results)
  warning   — issues that must be handled for production: memory leaks, heap escapes, missing/incorrect timeouts, unclosed resources, unhandled signals, etc.
  info      — all other improvements: style, naming, readability, idiomatic Go, minor refactors, etc.
and <principle> is one of: Effective Go, 100 Go Mistakes, Google Style

Example input:
  L41| 	params := map[string]string{
  L42| 		"ProjectID":     projectID,
  L43| 		"ServingConfig": os.Getenv("SERVING_CONFIG"),
  L44| 	}

CRITICAL: Read the "L<number>|" prefix of the EXACT line containing the issue. That number is the line number you must use. Do NOT use the line number of a nearby or enclosing line.

Rules:
- Do NOT output any introduction, summary header, markdown, or conclusion.
- Do NOT use code blocks or bullet points.
- Each issue must be a separate line in the exact quickfix format above.
- Line numbers MUST match the prefixed line numbers in the provided code. If exact line is unknown, use line 1.
- Focus on practical, specific improvements only.

If code is not provided, output exactly: error: no Go source code provided for review.
]]

local code_review_system_prompt_short =
  [[You are an experienced Go code reviewer. Review the given Go code for bugs, correctness, error handling, concurrency issues, and major style problems. Focus on actionable issues only.

The source code has line markers "L<number>|" at the start of each line. Use those numbers for line references.

If there are NO issues: output one summary line (e.g. "Code looks correct and idiomatic.").

If there ARE issues, output ONLY lines in vim quickfix format:
  <filename>:<line>:<col>: <severity>: <message>. Refactor: <suggestion>
where <severity> is: error (bugs/compile errors), warning (resource leaks, races, missing cleanup), info (style/naming).

Rules:
- No markdown, no headers, no bullet points. One quickfix line per issue.
- Line numbers MUST match the L<number> prefixes in the provided code.
]]

local diff_review_system_prompt_short =
  [[You are an experienced Go code reviewer. Review the unified diff for bugs, correctness, error handling, concurrency issues, and major style problems in the changed lines (+ lines) only.

Use NEW file line numbers from diff hunk headers (@@ -a,b +c,d @@).

If there are NO issues: output one summary line.

If there ARE issues, output ONLY lines in vim quickfix format:
  <filename>:<line>:<col>: <severity>: <message>. Refactor: <suggestion>
where <severity> is: error, warning, info.

Rules:
- No markdown, no headers, no bullet points. One quickfix line per issue.
]]

local diff_review_system_prompt =
  [[You are an experienced Golang code reviewer. You are reviewing a unified diff (git diff) of Go source code changes against a base branch. Focus ONLY on the changed lines (lines starting with + or context around them). Evaluate the changes for correctness, readability, performance, best practices, and style.

IMPORTANT: Use the NEW file line numbers from the diff hunk headers (the second number in @@ -a,b +c,d @@). For added/changed lines (starting with +), compute the actual file line number by counting from the hunk start.
]]
  .. prompts.review_guidelines()
  .. [[

# Instructions

1. Read the unified diff carefully.
2. Focus only on the added/modified code (+ lines).
3. For each audit category above, check whether any issues apply to the changed code.
4. For each Go-specific review dimension, check whether any issues apply to the changed code.
5. Evaluate changed code for bugs, style, performance, concurrency, error handling.
6. Skip praise — output improvements only.

# Output Format

If there are NO improvements needed:
- Output exactly one line: a brief summary (e.g. "Changes look correct and idiomatic.").

If there ARE improvements, output ONLY lines in vim quickfix format:
  <filename>:<line>:<col>: <severity>: [<principle>] <violation>: <message>. Refactor: <suggestion>
where <severity> is:
  error     — compile errors and logic errors only (code will not build or produces wrong results)
  warning   — issues that must be handled for production: memory leaks, heap escapes, missing/incorrect timeouts, unclosed resources, unhandled signals, etc.
  info      — all other improvements: style, naming, readability, idiomatic Go, minor refactors, etc.
and <principle> is one of: Effective Go, 100 Go Mistakes, Google Style

Rules:
- Do NOT output any introduction, summary header, markdown, or bullet points.
- Each issue must be a separate line in the exact quickfix format above.
- Line numbers must be the NEW file line numbers (post-change), 1-based.
- Focus on practical, specific improvements only.
]]
-- stylua: ignore end

-- Export prompts for external use (e.g. mcp/review.lua)
M.code_review_system_prompt = code_review_system_prompt
M.code_review_system_prompt_short = code_review_system_prompt_short
M.diff_review_system_prompt = diff_review_system_prompt
M.diff_review_system_prompt_short = diff_review_system_prompt_short

-- ─── Git helpers ─────────────────────────────────────────────────────────────

--- Detect the default branch of the repository.
--- @return string
function M.detect_default_branch()
  -- Check remote HEAD first (most reliable)
  local h = vim.fn.systemlist('git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null')
  if vim.v.shell_error == 0 and h[1] then
    local branch = h[1]:match('refs/remotes/origin/(.+)')
    if branch then
      return branch
    end
  end
  -- Fallback: check if main or master exists locally
  for _, name in ipairs({ 'main', 'master' }) do
    vim.fn.system('git rev-parse --verify ' .. name .. ' 2>/dev/null')
    if vim.v.shell_error == 0 then
      return name
    end
  end
  return 'main'
end

--- Get the unified diff of a file against a branch.
--- @param filepath string  Absolute path to the file
--- @param branch string  Branch name to diff against
--- @param callback function  Called with (diff_text, err_msg)
local function get_git_diff(filepath, branch, callback)
  local rel = vim.fn.fnamemodify(filepath, ':.')
  vim.system({ 'git', 'diff', '-U10', branch .. '...HEAD', '--', rel }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, 'git diff failed: ' .. (result.stderr or ''):gsub('%s+$', ''))
        return
      end
      local diff = vim.trim(result.stdout or '')
      if diff == '' then
        callback(nil, 'no changes against ' .. branch)
        return
      end
      callback(diff, nil)
    end)
  end)
end

-- ─── Response parsing ────────────────────────────────────────────────────────

--- Parse the LLM review response and open the quickfix list.
--- Handles JSON (fenced or raw), quickfix-format lines, and markdown prose.
--- @param response string  Raw LLM output
--- @param filename string  Absolute path to the reviewed file
function M.handle_response(response, filename)
  response = vim.trim(response)

  -- Try to extract a JSON array from fenced code block or raw text.
  local json_str
  local json_fence_start, json_fence_end

  -- 1) Look for a fenced JSON code block
  do
    local s, e, cap = response:find('```json%s*\n(.-)\n?```')
    if s then
      json_str = cap
      json_fence_start = s
      json_fence_end = e
    end
  end

  -- 2) Fallback: find the outermost [ ... ] array by bracket depth
  if not json_str then
    local start = response:find('%[%s*{')
    if start then
      local depth = 0
      for pos = start, #response do
        local ch = response:sub(pos, pos)
        if ch == '[' then depth = depth + 1
        elseif ch == ']' then
          depth = depth - 1
          if depth == 0 then
            json_str = response:sub(start, pos)
            break
          end
        end
      end
    end
  end

  if json_str then
    json_str = vim.trim(json_str)
    local ok, findings = pcall(vim.json.decode, json_str)
    if ok and type(findings) == 'table' then
      if #findings == 0 then
        vim.notify('[GoCodeReview]: great job! No issues found.', vim.log.levels.INFO)
        return
      end

      local qflist = {}
      local severity_map = { error = 'E', warning = 'W', info = 'I' }
      for _, item in ipairs(findings) do
        local parts = {}
        if item.violation and item.violation ~= '' then
          table.insert(parts, '[' .. item.violation .. ']')
        end
        if item.principle and item.principle ~= '' then
          table.insert(parts, item.principle)
        end
        if item.message and item.message ~= '' then
          table.insert(parts, item.message)
        end
        if item.refactor and item.refactor ~= '' then
          table.insert(parts, 'Refactor: ' .. item.refactor)
        end
        table.insert(qflist, {
          filename = item.file or filename or vim.fn.expand('%'),
          lnum = tonumber(item.line) or 1,
          col = tonumber(item.col) or 1,
          text = table.concat(parts, ' '),
          type = severity_map[item.severity] or 'W',
        })
      end

      vim.fn.setqflist({}, 'r', { title = 'GoCodeReview', items = qflist })
      vim.cmd('copen')
      vim.notify(string.format('[GoCodeReview]: %d issue(s) added to quickfix', #qflist), vim.log.levels.INFO)

      -- Show surrounding markdown prose (if any) in a float
      local md_parts = {}
      if json_fence_start then
        local before = vim.trim(response:sub(1, json_fence_start - 1))
        local after = vim.trim(response:sub(json_fence_end + 1))
        if before ~= '' then table.insert(md_parts, before) end
        if after ~= '' then table.insert(md_parts, after) end
      end
      if #md_parts > 0 then
        ui.show_markdown_float(table.concat(md_parts, '\n\n'))
      end
      return
    end
  end

  -- No JSON found — treat as plain text / markdown response
  response = response:gsub('^```%w*\n?', ''):gsub('\n?```$', '')
  response = vim.trim(response)

  local lines = vim.split(response, '\n', { plain = true })

  -- Detect "no issues" case: single non-quickfix line
  if #lines == 1 and not lines[1]:match('^[^:]+:%d+:') then
    vim.notify('go.nvim [CodeReview]: ' .. lines[1], vim.log.levels.INFO)
    return
  end

  -- Check if any line looks like quickfix format
  local has_qf_line = false
  for _, line in ipairs(lines) do
    if vim.trim(line):match('^[^:]+:%d+:') then
      has_qf_line = true
      break
    end
  end

  -- If no quickfix lines found, display as markdown
  if not has_qf_line then
    ui.show_markdown_float(response)
    return
  end

  local qflist = {}
  for _, line in ipairs(lines) do
    line = vim.trim(line)
    if line ~= '' then
      local fname, lnum, col, text = line:match('^([^:]+):(%d+):(%d+):%s*(.+)$')
      if not fname then
        fname, lnum, text = line:match('^([^:]+):(%d+):%s*(.+)$')
        col = 1
      end
      if fname and lnum and text then
        local type_char = 'W'
        local severity = text:match('^(%a+):')
        if severity then
          local sl = severity:lower()
          if sl == 'error' then
            type_char = 'E'
          elseif sl == 'suggestion' or sl == 'info' or sl == 'note' then
            type_char = 'I'
          end
        end
        table.insert(qflist, {
          filename = filename,
          lnum = tonumber(lnum) or 1,
          col = tonumber(col) or 1,
          text = text,
          type = type_char,
        })
      else
        if line ~= '' then
          table.insert(qflist, {
            filename = filename,
            lnum = 1,
            col = 1,
            text = line,
            type = 'W',
          })
        end
      end
    end
  end

  if #qflist == 0 then
    vim.notify('[GoCodeReview]: great job! No issues found.', vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist({}, 'r', { title = 'GoCodeReview', items = qflist })
  vim.cmd('copen')
  vim.notify(string.format('[GoCodeReview]: %d issue(s) added to quickfix', #qflist), vim.log.levels.INFO)
end

-- ─── Entry point ─────────────────────────────────────────────────────────────

--- Entry point for :GoCodeReview [-d [branch]] [-b] [-m <message>]
--- Reviews the current buffer, visual selection, or diff against a branch.
---   :GoCodeReview           — review entire file
---   :'<,'>GoCodeReview      — review visual selection
---   :GoCodeReview -d        — review only changes vs main/master (auto-detected)
---   :GoCodeReview -d develop — review only changes vs 'develop'
---   :GoCodeReview -m add lru cache and remove fifo cache — provide change context
--- @param opts table  Standard nvim command opts (range, line1, line2, fargs)
function M.run(opts)
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.enable then
    vim.notify(
      'go.nvim [AI]: AI is disabled. Set ai = { enable = true } in go.nvim setup to use GoCodeReview',
      vim.log.levels.WARN
    )
    return
  end

  local fargs = (type(opts) == 'table' and opts.fargs) or {}

  -- Parse flags: -d [branch], -b/--brief, -m <message>
  local diff_mode = false
  local diff_branch = nil
  local brief = false
  local change_message = nil
  local i = 1
  while i <= #fargs do
    local arg = fargs[i]
    if arg == '-d' or arg == '--diff' then
      diff_mode = true
      if fargs[i + 1] and not fargs[i + 1]:match('^%-') then
        diff_branch = fargs[i + 1]
        i = i + 1
      end
    elseif arg == '-b' or arg == '--brief' then
      brief = true
    elseif arg == '-m' or arg == '--message' then
      local msg_parts = {}
      for j = i + 1, #fargs do
        table.insert(msg_parts, fargs[j])
      end
      local raw = table.concat(msg_parts, ' ')
      change_message = raw:gsub('\\n', '\n')
      break
    end
    i = i + 1
  end

  local source_bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.fn.expand('%:p')

  local function continue_review(msg, skip_source)
    local cm = msg

    if diff_mode then
      local branch = diff_branch or M.detect_default_branch()
      vim.notify('[GoCodeReview]: diffing against ' .. branch .. ' …', vim.log.levels.INFO)
      get_git_diff(filename, branch, function(diff, err)
        if err then
          vim.notify('[GoCodeReview]: ' .. err, vim.log.levels.WARN)
          return
        end
        local short_name = vim.fn.expand('%:t')
        local user_msg = ''
        if cm and cm ~= '' then
          user_msg = '## Change Description\n' .. cm .. '\n\n'
        end
        user_msg = user_msg .. string.format('File: %s\nBase branch: %s\n\n```diff\n%s\n```', short_name, branch, diff)
        local sys = brief and diff_review_system_prompt_short or diff_review_system_prompt
        provider.request(sys, user_msg, { max_tokens = 1500, temperature = 0 }, function(resp)
          M.handle_response(resp, filename)
        end)
      end)
      return
    end

    -- Full-file / visual-selection review
    local lines
    local start_line = 1
    if type(opts) == 'table' and opts.range and opts.range == 2 then
      lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
      start_line = opts.line1
    else
      lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    end

    if #lines == 0 and not skip_source then
      vim.notify('[GoCodeReview]: buffer is empty', vim.log.levels.WARN)
      return
    end

    local short_name = vim.fn.expand('%:t')
    local user_msg = ''
    if cm and cm ~= '' then
      user_msg = '## Change Description\n' .. cm .. '\n\n'
    end
    if not skip_source then
      local numbered = {}
      for i_line, line in ipairs(lines) do
        table.insert(numbered, string.format('L%d| %s', start_line + i_line - 1, line))
      end
      local code = table.concat(numbered, '\n')
      user_msg = user_msg .. string.format('File: %s\n\n```go\n%s\n```', short_name, code)
    end

    vim.notify('[GoCodeReview]: reviewing …', vim.log.levels.INFO)

    local sys = brief and code_review_system_prompt_short or code_review_system_prompt
    provider.request(sys, user_msg, { max_tokens = 1500, temperature = 0 }, function(resp)
      M.handle_response(resp, filename)
    end)
  end

  if change_message and change_message ~= '' then
    local has_macro = macros.has_macros(change_message)
    macros.expand(change_message, source_bufnr, function(expanded_msg, ctx_attachments)
      if ctx_attachments and ctx_attachments ~= '' then
        expanded_msg = expanded_msg .. '\n\n' .. ctx_attachments
      end
      continue_review(expanded_msg, has_macro)
    end)
  else
    continue_review(change_message, false)
  end
end

return M
