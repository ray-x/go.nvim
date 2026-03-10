local M = {}
local mcp_context = require('go.mcp.context')
local log = require('go.utils').log
local prompts = require('go.prompts')

-- JSON output format shared by all MCP review prompts
local json_output_format = [[

Output as JSON array of objects with fields:
- "file": filename
- "line": line number (integer)
- "col": column number (integer, default 1)
- "severity": "error" | "warning" | "info"
- "violation": short violation label (e.g., "Non-idiomatic naming", "Slice memory leak")
- "principle": one of "[Effective Go]", "[100 Go Mistakes]", "[Google Style]"
- "message": description of the issue
- "refactor": brief refactored code or suggestion (optional, empty string if not applicable)

If no issues found, return: []
]]

-- stylua: ignore start
local mcp_code_review_system =
  [[You are an experienced Go code reviewer with access to semantic context from gopls.
Your task is to review Go source code for correctness, readability, performance, best practices, and style.
Use the semantic context to assess impact on callers, interfaces, and downstream consumers.

When reviewing, reason step-by-step about each aspect of the code before concluding. Be polite, professional, and constructive.
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

When reviewing, reason step-by-step about each aspect of the code before concluding. Be polite, professional, and constructive.
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
  if opts and opts.diff then
    table.insert(parts, '## Git Diff\n```diff\n' .. code_text .. '\n```')
  else
    table.insert(parts, '## Source Code\n```go\n' .. code_text .. '\n```')
  end
  table.insert(parts, '\n## Semantic Context for Changed Symbols\n' .. semantic_context)
  if not opts or not opts.brief then
    table.insert(parts, '\nUse the semantic context to assess the full impact:')
    table.insert(parts, '- Are callers affected by signature changes?')
    table.insert(parts, '- Do interface contracts still hold?')
    table.insert(parts, '- Are there downstream consumers that might break?')
    table.insert(parts, '- Are error handling patterns consistent with existing callers?')
  end
  return table.concat(parts, '\n')
end

--- Enhanced code review with semantic context from the running gopls LSP
---@param opts table {diff=bool, branch=string, visual=bool, lines=string}
function M.review(opts)
  opts = opts or {}
  local ai = require('go.ai')

  -- Get the diff or file content (reuse existing logic)
  local code_text
  if opts.diff then
    local branch = opts.branch or 'master'
    code_text = vim.fn.system({ 'git', 'diff', '-U10', branch, '--', '*.go' })
    if vim.v.shell_error ~= 0 then
      code_text = vim.fn.system({ 'git', 'diff', '-U10', 'main', '--', '*.go' })
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

  vim.notify('[GoReview]: gathering semantic context from gopls...', vim.log.levels.INFO)

  local brief = opts.brief or false

  local function send_review(sys_prompt, semantic_ctx)
    local prompt = build_enriched_prompt(code_text, semantic_ctx, opts)
    ai.request(sys_prompt, prompt, { max_tokens = 4096, temperature = 0 }, function(response)
      M._handle_review_response(response)
    end)
  end

  if opts.diff then
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
    log(findings)
    for _, item in ipairs(findings) do
      local severity_map = {
        error = 'E',
        warning = 'W',
        info = 'I',
      }
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
  end)
end

return M
