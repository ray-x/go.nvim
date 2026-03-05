local M = {}
local mcp_context = require('go.mcp.context')
local log = require('go.utils').log

--- Build the enriched prompt with diff + semantic context
---@param diff_text string the git diff
---@param semantic_context string gathered MCP context
---@param opts table
---@return string the full prompt for AI
local function build_enriched_prompt(diff_text, semantic_context, opts)
  return string.format([[
You are an expert Go code reviewer. Review the following code changes.

You have access to **semantic context** gathered from gopls — this includes
information about callers, references, and interface implementations for
every changed symbol. Use this to assess the **full impact** of the changes:
- Are callers affected by signature changes?
- Do interface contracts still hold?
- Are there downstream consumers that might break?
- Are error handling patterns consistent with existing callers?

## Git Diff
```diff
%s
```

## Semantic Context for Changed Symbols
%s

## Instructions
1. Identify bugs, race conditions, security issues, and API contract violations.
2. Flag changes that break callers or interface implementations (you have the data).
3. Check error handling, nil safety, and resource cleanup.
4. Assess backward compatibility using the reference/caller information.
5. Suggest concrete improvements.

Respond ONLY with a JSON array. Each element:
{"file":"<path>","line":<number>,"severity":"error|warning|info","message":"<text>"}
No markdown wrapping. Just the JSON array.
]], diff_text, semantic_context)
end

--- Enhanced code review with semantic context from the running gopls LSP
---@param opts table {diff=bool, branch=string, visual=bool, lines=string}
function M.review(opts)
  opts = opts or {}
  local ai = require('go.ai')

  -- Get the diff or file content (reuse existing logic)
  local code_text
  if opts.diff then
    local branch = opts.branch or 'main'
    code_text = vim.fn.system({ 'git', 'diff', branch, '--', '*.go' })
    if vim.v.shell_error ~= 0 then
      -- Try master if main doesn't exist
      code_text = vim.fn.system({ 'git', 'diff', 'master', '--', '*.go' })
    end
  elseif opts.visual and opts.lines then
    code_text = opts.lines
  else
    local bufnr = vim.api.nvim_get_current_buf()
    code_text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  end

  if not code_text or #code_text == 0 then
    vim.notify('No code to review', vim.log.levels.WARN)
    return
  end

  vim.notify('go.nvim [Review]: gathering semantic context from gopls...', vim.log.levels.INFO)

  local function send_review(sys_prompt, semantic_ctx)
    local prompt = build_enriched_prompt(code_text, semantic_ctx, opts)
    ai.request(
      sys_prompt,
      prompt,
      { max_tokens = 4096, temperature = 0 },
      function(response)
        M._handle_review_response(response)
      end
    )
  end

  if opts.diff then
    -- Use the NEW function from context.lua
    mcp_context.gather_diff_context(code_text, function(semantic_ctx)
      vim.schedule(function()
        vim.notify('go.nvim [Review]: semantic context ready. Sending to AI...', vim.log.levels.INFO)
        send_review(ai.diff_review_system_prompt, semantic_ctx)
      end)
    end)
  else
    local bufnr = vim.api.nvim_get_current_buf()
    -- Use the NEW function from context.lua
    mcp_context.gather_buffer_context(bufnr, function(semantic_ctx)
      vim.schedule(function()
        vim.notify('go.nvim [Review]: semantic context ready. Sending to AI...', vim.log.levels.INFO)
        send_review(ai.code_review_system_prompt, semantic_ctx)
      end)
    end)
  end
end

--- Parse AI response and populate quickfix list
function M._handle_review_response(response)
  vim.schedule(function()
    if not response or #response == 0 then
      vim.notify('No review findings', vim.log.levels.INFO)
      return
    end

    -- Strip markdown code fences if present
    local cleaned = response:gsub('^```json%s*', ''):gsub('%s*```$', '')
    local ok, findings = pcall(vim.json.decode, cleaned)
    if not ok or type(findings) ~= 'table' then
      vim.notify('Failed to parse AI review response', vim.log.levels.ERROR)
      log('Raw response:', response)
      return
    end

    local qf_items = {}
    for _, f in ipairs(findings) do
      local severity_map = {
        error = 'E',
        warning = 'W',
        info = 'I',
      }
      table.insert(qf_items, {
        filename = f.file or vim.fn.expand('%'),
        lnum = f.line or 1,
        col = 1,
        text = f.message or '',
        type = severity_map[f.severity] or 'I',
      })
    end

    vim.fn.setqflist(qf_items, 'r')
    vim.fn.setqflist({}, 'a', { title = 'GoCodeReview (MCP-enhanced)' })
    if #qf_items > 0 then
      vim.cmd('copen')
    end
    vim.notify(string.format('Code review: %d findings', #qf_items), vim.log.levels.INFO)
  end)
end

return M