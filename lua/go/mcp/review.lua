local M = {}
local mcp_context = require('go.mcp.context')
local log = require('go.utils').log

-- stylua: ignore start
local enriched_prompt_short = [[
You are an experienced Go code reviewer. Review the code changes using the semantic context from gopls to assess impact on callers, interfaces, and downstream consumers.

## Git Diff
```diff
%s
```

## Semantic Context for Changed Symbols
%s

Focus on: bugs, correctness, error handling, concurrency issues, resource leaks, and breaking changes to callers/interfaces.

Output as JSON array of objects with fields:
- "file": filename
- "line": line number (integer)
- "col": column number (integer, default 1)
- "severity": "error" | "warning" | "info"
- "violation": short violation label
- "principle": "[Effective Go]" | "[100 Go Mistakes]" | "[Google Style]"
- "message": description of the issue
- "refactor": brief suggestion (optional, empty string if not applicable)

If no issues found, return: []
]]

local enriched_prompt_full = [[
You are an experienced Golang code reviewer with access to MCP tools. Your task is to review Go language source code for correctness, readability, performance, best practices, and style using all available context.

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

When reviewing, reason step-by-step about each aspect of the code before concluding. Be polite, professional, and constructive.

# Audit Categories

1. Code Organization: Misaligned project structure, init function abuse, or getter/setter overkill.
2. Data Types: Octal literals, integer overflows, floating-point inaccuracies, and slice/map header confusion.
3. Control Structures: Range loop pointer copies, using break in switch inside for loops, and map iteration non-determinism.
4. String Handling: Inefficient concatenation, len() vs. rune count, and substring memory leaks.
5. Functions & Methods: Pointer vs. value receivers, named result parameters, and returning nil interfaces.
6. Error Management: Panic/recover abuse, ignoring errors, and failing to wrap errors with %%w.
7. Concurrency: Goroutine leaks, context misuse, data races, and sync vs. channel trade-offs.
8. Standard Library: http body closing, json marshaling pitfalls, and time.After leaks.
9. Testing: Table-driven test errors, race conditions in tests, and external dependency mocking.
10. Optimizations: CPU cache misalignment, false sharing, and stack vs. heap escape analysis.

# Go-Specific Review Dimensions

## Formatting & Naming (Effective Go / Google Style)
- Indentation/Formatting: Check for non-standard layouts (assume gofmt standards).
- Naming: Enforce short, pithy names for local variables (e.g., r for reader) and MixedCaps/Exported naming conventions.
- Interface Names: Ensure one-method interfaces end in an "er" suffix (e.g., Reader, Writer).
- Function/Method Naming: Avoid repeating package name (e.g., yamlconfig.Parse not yamlconfig.ParseYAMLConfig), receiver type, parameter names, or return types in the function name.
- No Get Prefix: Functions returning values should use noun-like names without "Get" prefix (e.g., JobName not GetJobName). Functions doing work should use verb-like names.
- Util Packages: Flag packages named "util", "helper", "common" — names should describe what the package provides.

## Initialization & Control (The "Go Way")
- Redeclaring vs. Reassigning: Identify where := is used correctly vs. where it creates shadowing bugs. Flag shadowing of variables in inner scopes (especially context, error) that silently creates new variables instead of updating the outer one.
- Do not shadow standard package names (e.g., using "url" as a variable name blocks net/url).
- The Switch Power: Look for complex if-else chains that should be simplified into Go's powerful switch (which handles multiple expressions and comparisons).
- Allocation: Differentiate between new (zeroed memory pointer) and make (initialized slice/map/chan).
- Prefer := for non-zero initialization, var for zero-value declarations.
- Signal Boosting: Flag easy-to-miss "err == nil" checks (positive error checks) — these should have a clarifying comment.

## Data Integrity & Memory (100 Go Mistakes)
- Slice/Map Safety: Check for sub-slice memory leaks and map capacity issues.
- Conversions: Ensure string-to-slice conversions are necessary and efficient.
- Backing Arrays: Flag cases where multiple slices share a backing array unintentionally.
- Size Hints: For performance-sensitive code, check if make() should have capacity hints for slices/maps when the size is known.
- Channel Direction: Ensure channel parameters specify direction (<-chan or chan<-) where possible.
- Map Initialization: Flag writes to nil maps (maps must be initialized with make before mutation, though reads are safe).

## Concurrency & Errors
- Communication: "Do not communicate by sharing memory; instead, share memory by communicating." Flag excessive Mutex use where Channels would be cleaner.
- Only sender can close a channel: Flag cases where multiple goroutines might close the same channel, which can cause panics.
- Error Handling: Check for the "Happy Path" (return early on errors to keep the successful logic left-aligned).
- Error Structure: Flag string-matching on error messages — use sentinel errors, errors.Is, or errors.As instead.
- Error Wrapping: Ensure %%w is used (not %%v) when callers need to inspect wrapped errors. Place %%w at the end of the format string. Avoid redundant annotations (e.g., "failed: %%v" adds nothing — just return err). Do not duplicate information the underlying error already provides.
- Panic/Recover: Ensure panic is only used for truly unrecoverable setup errors or API misuse, not for flow control. Panics must never escape package boundaries in libraries — use deferred recover at public API boundaries.
- Do not call log.Fatal or t.Fatal from goroutines other than the main test goroutine.
- Handle error cases first (left-aligned), then the successful path. Avoid deep nesting of if statements for the happy path. Reduce `if err != nil` nesting by returning early.
- Errors should only be handled once — avoid patterns where errors are checked, annotated, and returned in multiple layers.
- Use traceID or context values for cross-cutting concerns instead of passing through multiple layers of error annotations.

## Documentation & API Design (Google Style)
- Context conventions: Do not restate that cancelling ctx stops the function (it is implied). Document only non-obvious context behavior.
- Cleanup: Exported constructors/functions that acquire resources must document how to release them (e.g., "Call Stop to release resources when done").
- Concurrency safety: Document non-obvious concurrency properties. Read-only operations are assumed safe; mutating operations are assumed unsafe. Document exceptions.
- Error documentation: Document significant sentinel errors and error types returned by functions, including whether they are pointer receivers.
- Function argument lists: Flag functions with too many parameters. Recommend option structs or variadic options pattern for complex configuration.

## Testing (Google Style)
- Leave testing to the Test function: Flag assertion helper libraries — prefer returning errors or using cmp.Diff with clear failure messages in the Test function itself.
- Table-driven tests: Use field names in struct literals. Keep setup scoped to tests that need it (no global init for test data).
- t.Fatal usage: Use t.Fatal only for setup failures. In table-driven subtests, use t.Fatal inside t.Run; outside subtests, use t.Error + continue.
- Do not call t.Fatal from separate goroutines — use t.Error and return instead.
- Mocking: Prefer interface-based design for testability. For external dependencies, use in-memory implementations or test servers instead of complex mocking frameworks.
- Logging: Use t.Log for test logs, not global loggers. Logs should be relevant to the test case and not contain sensitive information.
- Test doubles: Follow naming conventions (package suffixed with "test", types named by behavior like AlwaysCharges).

## Global State & Dependencies
- Flag package-level mutable state (global vars, registries, singletons). Prefer instance-based APIs with explicit dependency passing.
- Flag service locator patterns and thick-client singletons.

## String Handling (Google Style)
- Prefer "+" for simple concatenation, fmt.Sprintf for formatting, strings.Builder for piecemeal construction.
- Use backticks for constant multi-line strings.

# Output Instructions

For every critique, provide:
1. The Violation (e.g., "Non-idiomatic naming" or "Slice memory leak").
2. The Principle: Cite if it is an [Effective Go] rule, a [100 Go Mistakes] pitfall, or a [Google Style] convention.
3. A brief refactored code suggestion where applicable.

# Instructions

1. Read the entire Go code provided.
2. Use MCP tools to gather additional context if available (e.g., read related files, check project structure).
3. For each audit category above, check whether any issues apply.
4. For each Go-specific review dimension, check whether any issues apply.
5. Assess functionality and correctness.
6. Evaluate code readability and style against Go conventions.
7. Check for performance or concurrency issues.
8. Review error handling and package usage.
9. Provide only actionable improvements — skip praise or explanations of what is already good.

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
-- stylua: ignore end

--- Build the enriched prompt with diff + semantic context
---@param diff_text string the git diff
---@param semantic_context string gathered MCP context
---@param opts table optional; opts.brief=true selects compact prompt
---@return string the full prompt for AI
local function build_enriched_prompt(diff_text, semantic_context, opts)
  local template = (opts and opts.brief) and enriched_prompt_short or enriched_prompt_full
  return string.format(template, diff_text, semantic_context)
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
    -- Use the NEW function from context.lua
    mcp_context.gather_diff_context(code_text, function(semantic_ctx)
      vim.schedule(function()
        vim.notify('go.nvim [Review]: semantic context ready. Sending to AI...', vim.log.levels.INFO)
        local sys = brief and ai.diff_review_system_prompt_short or ai.diff_review_system_prompt
        send_review(sys, semantic_ctx)
      end)
    end)
  else
    local bufnr = vim.api.nvim_get_current_buf()
    -- Use the NEW function from context.lua
    mcp_context.gather_buffer_context(bufnr, function(semantic_ctx)
      vim.schedule(function()
        vim.notify('go.nvim [Review]: semantic context ready. Sending to AI...', vim.log.levels.INFO)
        local sys = brief and ai.code_review_system_prompt_short or ai.code_review_system_prompt
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
