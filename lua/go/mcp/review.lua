local M = {}
local mcp_context = require('go.mcp.context')
local log = require('go.utils').log
local prompts = require('go.prompts')

-- JSON output format shared by all MCP review prompts
local json_output_format = [[
# Output Format

You MUST output ONLY a JSON array. Do NOT include any introduction, summary, explanation, markdown, or commentary before or after the JSON.

JSON array of objects with fields:
- "file": filename
- "line": line number (integer)
- "col": column number (integer, default 1)
- "severity": "error" | "warning" | "info"
- "violation": short violation label (e.g., "Non-idiomatic naming", "Slice memory leak")
- "principle": one of "[Effective Go]", "[100 Go Mistakes]", "[Google Style]"
- "message": description of the issue
- "refactor": brief refactored code or suggestion (optional, empty string if not applicable)

If no issues found, return exactly: []

CRITICAL: Your entire response must be valid JSON. No text outside the JSON array.
]]

-- stylua: ignore start
local mcp_code_review_system =
  [[You are an experienced Go code reviewer with access to semantic context from gopls.
Your task is to review Go source code for correctness, readability, performance, best practices, and style.
Use the semantic context to assess impact on callers, interfaces, and downstream consumers.
Provide only actionable improvements — skip praise or explanations of what is already good.
]]
  .. prompts.review_guidelines() .. json_output_format

local mcp_code_review_system_short =
  [[You are an experienced Go code reviewer with semantic context from gopls.
Focus on: bugs, correctness, error handling, concurrency issues, resource leaks, and breaking changes to callers/interfaces.
]] .. json_output_format

local mcp_diff_review_system =
  [[You are an experienced Go code reviewer with access to semantic context from gopls.
You are reviewing a unified diff of Go source code changes. Focus on the changed lines.
Use the semantic context to assess impact on callers, interfaces, and downstream consumers.
Provide only actionable improvements — skip praise or explanations of what is already good.
]]
  .. prompts.review_guidelines() .. json_output_format

local mcp_diff_review_system_short =
  [[You are an experienced Go code reviewer with semantic context from gopls.
Review the unified diff for bugs, correctness, error handling, concurrency, and breaking changes in the changed lines only.
]] .. json_output_format
-- stylua: ignore end

--- Build the enriched user prompt with diff/code + semantic context
---@param code_text string the code or diff text
---@param semantic_context string gathered MCP context
---@param opts table optional; opts.diff=true for diff mode
---@return string the user prompt for AI
local function build_enriched_prompt(code_text, semantic_context, opts)
  local parts = {}
  if opts and opts.message and opts.message ~= '' then
    table.insert(parts, '## Change Description\n' .. opts.message .. '\n')
  end
  if not (opts and opts.skip_source) then
    if opts and opts.diff then
      table.insert(parts, '## Git Diff\n```diff\n' .. code_text .. '\n```')
    else
      table.insert(parts, '## Source Code\n```go\n' .. code_text .. '\n```')
    end
  end
  table.insert(parts, '\n## Semantic Context for Changed Symbols\n' .. semantic_context)
  if not opts or not opts.brief then
    table.insert(parts, '\nUse the semantic context to assess caller impact, interface contracts, and downstream breakage.')
    table.insert(parts, '\nReminder: Output ONLY the JSON array. No markdown, no summary, no prose.')
  end
  return table.concat(parts, '\n')
end

--- Enhanced code review with semantic context from the running gopls LSP
---@param opts table {diff=bool, branch=string, visual=bool, lines=string}
function M.review(opts)
  opts = opts or {}
  local ai = require('go.ai')

  local source_bufnr = vim.api.nvim_get_current_buf()

  -- Expand macros in -m message before proceeding
  local function do_review(expanded_opts)
    -- Get the diff or file content (reuse existing logic)
    local code_text
    if expanded_opts.diff then
      -- Determine base branch for diff:
      -- 1) honor explicit expanded_opts.branch
      -- 2) otherwise, use ai.detect_default_branch() if available
      -- 3) fall back to legacy master/main behavior for compatibility
      local branch = expanded_opts.branch
      if not branch or branch == '' then
        if ai.detect_default_branch then
          branch = ai.detect_default_branch()
        end
      end

      if not branch or branch == '' then
        branch = 'master'
      end

      code_text = vim.fn.system({ 'git', 'diff', '-U10', branch, '--', '*.go' })

      -- If diffing against the detected/explicit branch fails, try legacy fallbacks.
      if vim.v.shell_error ~= 0 and branch ~= 'master' and branch ~= 'main' then
        code_text = vim.fn.system({ 'git', 'diff', '-U10', 'master', '--', '*.go' })
        if vim.v.shell_error ~= 0 then
          code_text = vim.fn.system({ 'git', 'diff', '-U10', 'main', '--', '*.go' })
        end
      end
    elseif expanded_opts.visual and expanded_opts.lines then
      code_text = expanded_opts.lines
    else
      local bufnr = vim.api.nvim_get_current_buf()
      code_text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
    end

    if not code_text or #code_text == 0 then
      vim.notify('No code to review', vim.log.levels.WARN)
      return
    end

    vim.notify('[GoReview]: gathering semantic context from gopls...', vim.log.levels.INFO)

    local brief = expanded_opts.brief or false

    local function send_review(sys_prompt, semantic_ctx)
      local prompt = build_enriched_prompt(code_text, semantic_ctx, expanded_opts)
      ai.request(sys_prompt, prompt, { max_tokens = 4096, temperature = 0 }, function(response)
        M._handle_review_response(response)
      end)
    end

    if expanded_opts.diff then
      mcp_context.gather_diff_context(code_text, function(semantic_ctx)
        vim.schedule(function()
          vim.notify('go.nvim [Review]: semantic context ready. Sending to AI...', vim.log.levels.INFO)
          local sys = brief and mcp_diff_review_system_short or mcp_diff_review_system
          send_review(sys, semantic_ctx)
        end)
      end)
    else
      local bufnr = vim.api.nvim_get_current_buf()
      mcp_context.gather_buffer_context(bufnr, function(semantic_ctx)
        vim.schedule(function()
          vim.notify('go.nvim [Review]: semantic context ready. Sending to AI...', vim.log.levels.INFO)
          local sys = brief and mcp_code_review_system_short or mcp_code_review_system
          send_review(sys, semantic_ctx)
        end)
      end)
    end
  end

  -- If -m message contains macros, expand them first
  if opts.message and opts.message ~= '' and ai.expand_macros then
    local has_macro = opts.message:find('/buffer', 1, true)
      or opts.message:find('/file', 1, true)
      or opts.message:find('/function', 1, true)
    ai.expand_macros(opts.message, source_bufnr, function(expanded_msg, ctx_attachments)
      if ctx_attachments and ctx_attachments ~= '' then
        expanded_msg = expanded_msg .. '\n\n' .. ctx_attachments
      end
      local new_opts = vim.tbl_extend('force', opts, { message = expanded_msg, skip_source = has_macro and true or false })
      do_review(new_opts)
    end)
  else
    do_review(opts)
  end
end

--- Parse AI response and populate quickfix list
function M._handle_review_response(response)
  vim.schedule(function()
    if not response or #response == 0 then
      vim.notify('No review findings', vim.log.levels.INFO)
      return
    end

    -- Extract JSON array from response: handle fenced code blocks with surrounding prose
    local json_str
    local json_fence_start, json_fence_end  -- track position for markdown extraction

    -- 1) Look for a fenced JSON code block
    do
      local s, e, cap = response:find('```json%s*\n(.-)\n?```')
      if s then
        json_str = cap
        json_fence_start = s
        json_fence_end = e
      end
    end

    -- 2) Fallback: fence without language tag
    if not json_str then
      local s, e, cap = response:find('```%s*\n(.-)\n?```')
      if s then
        json_str = cap
        json_fence_start = s
        json_fence_end = e
      end
    end

    -- 3) Fallback: find the outermost [ ... ] array by bracket depth
    if not json_str then
      local start = response:find('%[%s*{')  -- must start with [{
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

    -- No JSON found — display the entire response as markdown
    if not json_str then
      local ai = require('go.ai')
      if ai.show_markdown_float then
        ai.show_markdown_float(response, ' GoCodeReview (MCP) ')
      else
        vim.notify(response, vim.log.levels.INFO)
      end
      return
    end

    json_str = vim.trim(json_str)
    local ok, findings = pcall(vim.json.decode, json_str)
    if not ok or type(findings) ~= 'table' then
      -- JSON extraction found something but decode failed — show raw response as markdown
      local ai = require('go.ai')
      if ai.show_markdown_float then
        ai.show_markdown_float(response, ' GoCodeReview (MCP) ')
      else
        vim.notify('Failed to parse AI review response', vim.log.levels.ERROR)
        log('Raw response:', response)
      end
      return
    end

    local qf_items = {}
    local severity_map = {
      error = 'E',
      warning = 'W',
      info = 'I',
    }
    log(findings)
    for _, item in ipairs(findings) do
      -- Build enriched message with violation/principle/refactor when available

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
      local text = table.concat(parts, ' ')

      table.insert(qf_items, {
        filename = item.file or vim.fn.expand('%'),
        lnum = tonumber(item.line) or 1,
        col = tonumber(item.col) or 1,
        text = text,
        type = severity_map[item.severity] or 'W',
      })
    end

    vim.fn.setqflist(qf_items, 'r')
    vim.fn.setqflist({}, 'a', { title = 'GoCodeReview (MCP-enhanced)' })
    if #qf_items > 0 then
      vim.cmd('copen')
    end
    vim.notify(string.format('Code review: %d findings', #qf_items), vim.log.levels.INFO)

    -- Show surrounding markdown prose (summary, recommendations) in a float
    local md_parts = {}
    if json_fence_start then
      local before = vim.trim(response:sub(1, json_fence_start - 1))
      local after = vim.trim(response:sub(json_fence_end + 1))
      if before ~= '' then table.insert(md_parts, before) end
      if after ~= '' then table.insert(md_parts, after) end
    end
    if #md_parts > 0 then
      local ai = require('go.ai')
      if ai.show_markdown_float then
        ai.show_markdown_float(table.concat(md_parts, '\n\n'), ' GoCodeReview (MCP) ')
      end
    end
  end)
end

return M
