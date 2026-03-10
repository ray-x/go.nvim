-- LLM-powered natural language command dispatcher for go.nvim
-- Usage: :GoAI run unit test for tags test
--        :GoAI  (interactive prompt)

local M = {}

local utils = require('go.utils')
local log = utils.log
local prompts = require('go.prompts')

-- Cached Copilot API token
local _copilot_token = nil
local _copilot_token_expires = 0

-- stylua: ignore start
local valid_cmd_set = {}
for _, c in ipairs({
  'GoTest', 'GoTestFunc', 'GoTestFile', 'GoTestPkg', 'GoTestSubCase', 'GoTestSum', 'GoAddTest',
  'GoAddExpTest', 'GoAddAllTest', 'GoCoverage', 'GoBuild', 'GoRun', 'GoGenerate', 'GoVet',
  'GoLint', 'GoMake', 'GoStop', 'GoFmt', 'GoImports', 'GoIfErr', 'GoFillStruct',
  'GoFillSwitch', 'GoFixPlurals', 'GoCmt', 'GoImpl', 'GoEnum', 'GoGenReturn', 'GoJson2Struct',
  'GoAddTag', 'GoRmTag', 'GoClearTag', 'GoModifyTag', 'GoModTidy', 'GoModVendor', 'GoModDnld',
  'GoModGraph', 'GoModWhy', 'GoModInit', 'GoGet', 'GoWork', 'GoDoc', 'GoDocBrowser',
  'GoAlt', 'GoAltV', 'GoAltS', 'GoImplements', 'GoPkgOutline', 'GoPkgSymbols', 'GoListImports',
  'GoCheat', 'GoCodeAction', 'GoCodeLenAct', 'GoRename', 'GoGCDetails', 'GoDebug', 'GoBreakToggle',
  'GoBreakSave', 'GoBreakLoad', 'GoDbgStop', 'GoDbgContinue', 'GoDbgKeys', 'GoCreateLaunch', 'DapStop',
  'DapRerun', 'BreakCondition', 'LogPoint', 'ReplRun', 'ReplToggle', 'ReplOpen', 'GoInstallBinary',
  'GoUpdateBinary', 'GoInstallBinaries', 'GoUpdateBinaries', 'GoTool', 'GoMockGen', 'GoEnv',
  'GoProject', 'GoToggleInlay', 'GoVulnCheck', 'GoNew', 'Gomvp', 'Ginkgo',
  'GinkgoFunc', 'GinkgoFile', 'GoGopls', 'GoCmtAI', 'GoCodeReview', 'GoDocAI',
}) do
  valid_cmd_set[c] = true
end
-- stylua: ignore end

local command_catalog = [[
go.nvim Commands Reference:

TESTING:
- GoTest [args] — Run tests. Args: package path, -v (verbose), -tags=xxx, -bench, -run=pattern, -count=N
- GoTestFunc [args] — Run test function under cursor. Args: -v, -tags=xxx
- GoTestFile [args] — Run all tests in current file. Args: -v, -tags=xxx
- GoTestPkg [args] — Run all tests in current package. Args: -v, -tags=xxx
- GoTestSubCase — Run specific table-driven test sub-case under cursor
- GoTestSum [args] — Run tests with gotestsum. Args: -w (watch mode)
- GoAddTest — Generate test for function under cursor
- GoAddExpTest — Generate tests for all exported functions
- GoAddAllTest — Generate tests for all functions
- GoCoverage [args] — Run tests with coverage display. Args: package path, -t (toggle), -f (file)

BUILD & RUN:
- GoBuild [args] — Build project. Args: package path, e.g. ./...
- GoRun [args] — Run the program. Args: any arguments to pass
- GoGenerate [args] — Run go generate. Args: package path
- GoVet [args] — Run go vet. Args: package path
- GoLint [args] — Run golangci-lint. Args: package path
- GoMake — Async make
- GoStop [job] — Stop a running async job

FORMAT & IMPORTS:
- GoFmt [formatter] — Format file. Args: gofmt, goimports, gofumpt, golines
- GoImports [pkg] — Add/remove imports. Args: optional package to import

CODE GENERATION:
- GoIfErr — Generate 'if err != nil' boilerplate at cursor
- GoFillStruct — Fill struct literal with default field values
- GoFillSwitch — Fill switch statement with all type/enum cases
- GoFixPlurals — Merge consecutive same-type function parameters
- GoCmt — Generate doc comment for function/struct under cursor
- GoImpl <receiver> <interface> — Generate interface stubs. E.g. GoImpl f *File io.Reader
- GoEnum [args] — Generate enum helpers
- GoGenReturn — Generate return values for function call under cursor
- GoJson2Struct [name] — Convert JSON to Go struct. Args: struct name

STRUCT TAGS:
- GoAddTag [tags] — Add struct tags. Args: json, xml, yaml, db, etc.
- GoRmTag [tags] — Remove struct tags. Args: tag names
- GoClearTag — Remove all struct tags
- GoModifyTag [tag] [transform] — Modify tag options. Args: tag name, transform (snakecase, camelcase)

MODULE MANAGEMENT:
- GoModTidy — Run go mod tidy
- GoModVendor — Run go mod vendor
- GoModDnld — Run go mod download
- GoModGraph — Show module dependency graph
- GoModWhy [module] — Show why a module is needed
- GoModInit [name] — Initialize new Go module
- GoGet [pkg] — Run go get. Args: package path
- GoWork [cmd] [path] — Go workspace commands. Args: run, use

NAVIGATION & DOCS:
- GoDoc [symbol] — Show documentation. Args: package or symbol name
- GoDocBrowser [symbol] — Open docs in browser
- GoAlt — Switch between test and implementation file
- GoAltV — Switch to alternate file in vertical split
- GoAltS — Switch to alternate file in horizontal split
- GoImplements — Show interface implementations via LSP
- GoPkgOutline [pkg] — Show package outline
- GoPkgSymbols — Show package symbols
- GoListImports — List imports in current file
- GoCheat [topic] — Cheat sheet from cht.sh

CODE ACTIONS & REFACTORING:
- GoCodeAction — Run LSP code actions (visual range supported)
- GoCodeLenAct — Run code lens action
- GoRename — Rename symbol via LSP
- GoGCDetails — Toggle GC optimization details

DEBUGGING (requires nvim-dap):
- GoDebug [args] — Start debugger. Args: -t (test), -r (restart), -n (nearest test), -f (file), -p (package), -s (stop), -b (breakpoint)
- GoBreakToggle — Toggle breakpoint at cursor line
- GoBreakSave — Save breakpoints to file
- GoBreakLoad — Load saved breakpoints
- GoDbgStop — Stop debugger
- GoDbgContinue — Continue execution in debugger
- GoDbgKeys — Show debugger key mappings
- GoCreateLaunch — Create .vscode/launch.json
- DapStop — Stop DAP session
- DapRerun — Rerun last DAP session

TOOLS & INSTALL:
- GoInstallBinary [tool] — Install a Go tool binary
- GoUpdateBinary [tool] — Update a Go tool binary
- GoInstallBinaries — Install all required tool binaries
- GoUpdateBinaries — Update all tool binaries
- GoTool [cmd] — Run go tool sub-command

MOCK:
- GoMockGen [args] — Generate mocks. Args: -p (package), -d (destination), -i (interface), -s (source)

OTHER:
- GoEnv [file] — Load environment variables from file
- GoProject — Setup project configuration
- GoToggleInlay — Toggle LSP inlay hints
- GoVulnCheck — Run govulncheck for vulnerability scanning
- GoNew [template] — Create project from template
- Gomvp [old] [new] — Rename/move packages
- Ginkgo [cmd] — Ginkgo framework. Args: generate, bootstrap, build, labels, run, watch
- GinkgoFunc — Run Ginkgo test for current function
- GinkgoFile — Run Ginkgo tests for current file

GOPLS LSP COMMANDS (via GoGopls <subcommand> [json_args]):
- GoGopls add_dependency {"GoCmdArgs":["pkg@version"]} — Add a module dependency
- GoGopls add_import {"ImportPath":"fmt"} — Add an import to the current file
- GoGopls add_test — Generate a test for the function at cursor
- GoGopls apply_fix — Apply a suggested fix
- GoGopls assembly — Show assembly for a function
- GoGopls change_signature — Refactor a function signature (remove/reorder params)
- GoGopls check_upgrades — Check for module dependency upgrades
- GoGopls diagnose_files — Run diagnostics on specified files
- GoGopls doc — Open Go documentation for symbol at cursor
- GoGopls edit_go_directive — Edit the go directive in go.mod
- GoGopls extract_to_new_file — Extract selected code to a new file
- GoGopls free_symbols — List free symbols in a selection
- GoGopls gc_details — Toggle GC optimization details overlay
- GoGopls generate — Run go generate for the current file/package
- GoGopls go_get_package — Run go get for a package
- GoGopls list_imports — List all imports in the current file
- GoGopls list_known_packages — List all known/importable packages
- GoGopls mem_stats — Show gopls memory statistics
- GoGopls modify_tags — Add/remove/modify struct field tags
- GoGopls modules — List modules in the workspace
- GoGopls package_symbols — List symbols in a package
- GoGopls packages — List packages in the workspace
- GoGopls regenerate_cgo — Regenerate cgo definitions
- GoGopls remove_dependency — Remove a module dependency
- GoGopls reset_go_mod_diagnostics — Reset go.mod diagnostics
- GoGopls run_go_work_command — Run a go work command
- GoGopls run_govulncheck — Run govulncheck via gopls
- GoGopls run_tests — Run tests via gopls
- GoGopls scan_imports — Scan for available imports
- GoGopls split_package — Split a package into multiple packages
- GoGopls tidy — Run go mod tidy
- GoGopls update_go_sum — Update go.sum
- GoGopls upgrade_dependency — Upgrade a module dependency
- GoGopls vendor — Run go mod vendor
- GoGopls vulncheck — Run vulnerability check
- GoGopls workspace_stats — Show workspace statistics

AI-POWERED:
- GoCmtAI — Generate doc comment for the declaration at cursor using AI
- GoCodeReview — Review the current Go file (or visual selection) with AI; outputs findings to the vim quickfix list
- GoDocAI [query] — Find a function/type by vague name and generate rich AI documentation from its source code
]]

local system_prompt_base = [[You are a command translator for go.nvim, a Neovim plugin for Go development.
Your job is to translate natural language requests into the correct go.nvim Vim command.

Rules:
1. Return ONLY the Vim command to execute. No explanation, no markdown, no backticks, no extra text.
2. The command must start with one of the go.nvim commands from the reference below.
3. Include any necessary arguments exactly as they would be typed in the Vim command line.
4. If the request is ambiguous, choose the most likely command.
5. If the request cannot be mapped to any go.nvim command, return exactly: echo "No matching go.nvim command found"

]]

local system_prompt = system_prompt_base .. command_catalog

--- Read Copilot OAuth token from the config files written by copilot.vim / copilot.lua
local function get_copilot_oauth_token()
  local paths = {
    vim.fn.expand('~/.config/github-copilot/hosts.json'),
    vim.fn.expand('~/.config/github-copilot/apps.json'),
  }

  for _, path in ipairs(paths) do
    local f = io.open(path, 'r')
    if f then
      local content = f:read('*a')
      f:close()
      local ok, data = pcall(vim.json.decode, content)
      if ok and type(data) == 'table' then
        for _, v in pairs(data) do
          if type(v) == 'table' and v.oauth_token then
            return v.oauth_token
          end
        end
      end
    end
  end
  return nil
end

--- Parse a curl exit code into a human-readable error message
local function parse_curl_error(exit_code, stderr)
  local curl_errors = {
    [6] = 'DNS resolution failed - check your network connection',
    [7] = 'connection refused - API server may be down',
    [28] = 'request timed out - network may be slow or unreachable',
    [35] = 'SSL/TLS handshake failed',
    [51] = 'SSL certificate verification failed',
    [52] = 'server returned empty response',
    [56] = 'network data receive error - connection may have been reset',
  }
  local msg = curl_errors[exit_code]
  if msg then
    return msg
  end
  return string.format('curl error %d: %s', exit_code, (stderr or ''):gsub('%s+$', ''))
end

--- Split curl output (with -w '\n%%{http_code}') into body and status code
local function split_http_response(stdout)
  local code = stdout:match('(%d+)%s*$')
  local body = code and stdout:sub(1, -(#code + 2)) or stdout
  return body, code or '0'
end

--- Exchange OAuth token for short-lived Copilot API token (cached)
local function get_copilot_api_token(oauth_token, callback)
  if _copilot_token and os.time() < _copilot_token_expires then
    callback(_copilot_token)
    return
  end

  -- stylua: ignore start
  vim.system({
    'curl', '-s', '--connect-timeout', '10',
    '--max-time', '15', '-w', '\n%{http_code}',
    '-H', 'Authorization: token ' .. oauth_token, '-H', 'Accept: application/json',
    'https://api.github.com/copilot_internal/v2/token',
  }, { text = true }, function(result)
    -- stylua: ignore end
    vim.schedule(function()
      if result.code ~= 0 then
        local msg = parse_curl_error(result.code, result.stderr)
        vim.notify('go.nvim [AI]: Copilot token request failed: ' .. msg, vim.log.levels.ERROR)
        return
      end
      local stdout = result.stdout or ''
      local body, http_code = split_http_response(stdout)
      if http_code ~= '200' then
        vim.notify(
          'go.nvim [AI]: Copilot token request returned HTTP ' .. http_code .. ': ' .. body:sub(1, 200),
          vim.log.levels.ERROR
        )
        return
      end
      local ok, data = pcall(vim.json.decode, body)
      if ok and data and data.token then
        _copilot_token = data.token
        _copilot_token_expires = (data.expires_at or 0) - 60 -- refresh 60s early
        callback(data.token)
      else
        vim.notify('go.nvim [AI]: unexpected Copilot token response', vim.log.levels.ERROR)
      end
    end)
  end)
end

--- Generic helper: POST a chat completion request via curl
local function call_chat_api(url, headers, body, callback)
  local cmd = { 'curl', '-s', '--connect-timeout', '10', '--max-time', '30', '-w', '\n%{http_code}', '-X', 'POST' }
  for _, h in ipairs(headers) do
    table.insert(cmd, '-H')
    table.insert(cmd, h)
  end
  table.insert(cmd, '-d')
  table.insert(cmd, '@-') -- read body from stdin
  table.insert(cmd, url)

  vim.system(cmd, { text = true, stdin = body }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local msg = parse_curl_error(result.code, result.stderr)
        vim.notify('go.nvim [AI]: API request failed: ' .. msg, vim.log.levels.ERROR)
        return
      end
      local stdout = result.stdout or ''
      local resp_body, http_code = split_http_response(stdout)
      if http_code ~= '200' then
        local detail = resp_body:sub(1, 200)
        -- Try to extract error message from JSON response
        local ok_json, err_data = pcall(vim.json.decode, resp_body)
        if ok_json and type(err_data) == 'table' and err_data.error then
          local e = err_data.error
          detail = type(e) == 'table' and (e.message or vim.inspect(e)) or tostring(e)
        end
        vim.notify('go.nvim [AI]: HTTP ' .. http_code .. ': ' .. detail, vim.log.levels.ERROR)
        return
      end
      local ok, data = pcall(vim.json.decode, resp_body)
      if ok and data and data.choices and data.choices[1] and data.choices[1].message then
        callback(vim.trim(data.choices[1].message.content))
      else
        vim.notify('go.nvim [AI]: unexpected API response: ' .. resp_body:sub(1, 200), vim.log.levels.ERROR)
      end
    end)
  end)
end

--- Build the user message with workspace context
local function build_user_message(request)
  local file = vim.fn.expand('%:t') or ''
  local ft = vim.bo.filetype or ''
  return string.format('Current file: %s (filetype: %s)\nRequest: %s', file, ft, request)
end

--- Build the JSON body for a chat completion
local function build_body(model, sys_prompt, user_msg, opts)
  opts = opts or {}
  return vim.json.encode({
    model = model,
    messages = {
      { role = 'system', content = sys_prompt },
      { role = 'user', content = user_msg },
    },
    temperature = opts.temperature or 0,
    max_tokens = opts.max_tokens or 200,
  })
end

--- Validate that the LLM response is a known go.nvim command
local function validate_response(cmd_str)
  -- Allow echo for "no match" responses
  if cmd_str:match('^echo ') then
    return true
  end
  local cmd_name = cmd_str:match('^:?(%S+)')
  return cmd_name and valid_cmd_set[cmd_name] == true
end

-- Commands that accept a visual range
local range_commands = {
  GoCodeAction = true,
  GoJson2Struct = true,
}

--- Process the LLM response: validate, confirm, execute
local function handle_response(cmd_str, confirm, range_prefix)
  -- Strip markdown fences if the LLM wrapped the answer
  cmd_str = cmd_str:gsub('^```%w*\n?', ''):gsub('\n?```$', '')
  cmd_str = vim.trim(cmd_str)
  -- take only the first line
  cmd_str = cmd_str:match('^([^\n]+)') or cmd_str

  log('go.nvim [AI]: LLM response:', cmd_str)

  if not validate_response(cmd_str) then
    log('go.nvim [AI]: unrecognised command:', cmd_str)
    vim.notify('go.nvim [AI]: unrecognised command: ' .. cmd_str, vim.log.levels.WARN)
    return
  end

  -- echo is informational, just show it
  if cmd_str:match('^echo ') then
    vim.cmd(cmd_str)
    return
  end

  -- Prepend range prefix for commands that support visual ranges
  if range_prefix and range_prefix ~= '' then
    local cmd_name = cmd_str:match('^:?(%S+)')
    if cmd_name and range_commands[cmd_name] then
      cmd_str = range_prefix .. cmd_str
    end
  end

  log('go.nvim [AI]: executing:', cmd_str)

  if not confirm then
    vim.cmd(cmd_str)
    return
  end

  vim.ui.select({ 'Yes', 'Edit', 'No' }, {
    prompt = string.format('Run  %s  ?', cmd_str),
  }, function(choice)
    if choice == 'Yes' then
      vim.cmd(cmd_str)
    elseif choice == 'Edit' then
      vim.api.nvim_feedkeys(':' .. cmd_str, 'n', false)
    end
  end)
end

--- Send request via GitHub Copilot Chat API (generic)
local function send_copilot_raw(sys_prompt, user_msg, opts, callback)
  local oauth = get_copilot_oauth_token()
  if not oauth then
    vim.notify(
      'go.nvim [AI]: Copilot OAuth token not found. Please install copilot.vim or copilot.lua and run :Copilot auth',
      vim.log.levels.ERROR
    )
    return
  end

  get_copilot_api_token(oauth, function(token)
    local cfg = _GO_NVIM_CFG.ai or {}
    local model = cfg.model or 'gpt-4o'
    log('build_body with model', model, 'sys_prompt ', sys_prompt, 'user_msg', user_msg, 'opts', opts)
    local body = build_body(model, sys_prompt, user_msg, opts)
    local nvim_ver = string.format('%s.%s.%s', vim.version().major, vim.version().minor, vim.version().patch)
    local headers = {
      'Content-Type: application/json',
      'Authorization: Bearer ' .. token,
      'Copilot-Integration-Id: vscode-chat',
      'Editor-Version: Neovim/' .. nvim_ver,
      'Editor-Plugin-Version: go.nvim/1.0.0',
      'User-Agent: go.nvim/1.0.0',
    }
    call_chat_api('https://api.githubcopilot.com/chat/completions', headers, body, callback)
  end)
end

--- Send request via OpenAI-compatible API (generic)
local function send_openai_raw(sys_prompt, user_msg, opts, callback)
  local cfg = _GO_NVIM_CFG.ai or {}
  local env_name = cfg.api_key_env or 'OPENAI_API_KEY'
  local api_key = os.getenv(env_name)
  local base_url = cfg.base_url or 'https://api.openai.com/v1'
  local model = cfg.model or 'gpt-4o-mini'

  if not api_key or api_key == '' then
    vim.notify('go.nvim [AI]: API key not found. Set the ' .. env_name .. ' environment variable', vim.log.levels.ERROR)
    return
  end

  local body = build_body(model, sys_prompt, user_msg, opts)
  local headers = {
    'Content-Type: application/json',
    'Authorization: Bearer ' .. api_key,
  }
  call_chat_api(base_url .. '/chat/completions', headers, body, callback)
end

--- Entry point: :GoAI run unit test for tags test
function M.run(opts)
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.enable then
    vim.notify(
      'go.nvim [AI]: AI is disabled. Set ai = { enable = true } in go.nvim setup to use GoAI',
      vim.log.levels.WARN
    )
    return
  end

  local prompt
  local range_prefix = ''

  local full_catalog = false

  if type(opts) == 'table' then
    local fargs = opts.fargs or {}
    -- Check for -f flag to include full command catalog
    local filtered = {}
    for _, arg in ipairs(fargs) do
      if arg == '-f' then
        full_catalog = true
      else
        table.insert(filtered, arg)
      end
    end
    prompt = table.concat(filtered, ' ')
    -- Capture visual range if the command was called with one
    if opts.range and opts.range == 2 then
      range_prefix = string.format('%d,%d', opts.line1, opts.line2)
    end
  else
    -- Legacy: called with varargs
    prompt = opts or ''
  end

  if prompt == '' then
    vim.ui.input({ prompt = 'go.nvim AI> ' }, function(input)
      if input and input ~= '' then
        M._dispatch(input, range_prefix, full_catalog)
      end
    end)
    return
  end

  M._dispatch(prompt, range_prefix, full_catalog)
end

--- Dispatch the natural language request to the configured LLM provider
function M._dispatch(prompt, range_prefix, full_catalog)
  local cfg = _GO_NVIM_CFG.ai or {}
  local provider = cfg.provider or 'copilot'
  local confirm = cfg.confirm ~= false -- default true

  vim.notify('go.nvim [AI]: thinking …', vim.log.levels.INFO)

  local sys_prompt = full_catalog and system_prompt or system_prompt_base
  local user_msg = build_user_message(prompt)

  local function on_resp(resp)
    handle_response(resp, confirm, range_prefix)
  end

  if provider == 'copilot' then
    send_copilot_raw(sys_prompt, user_msg, {}, on_resp)
  elseif provider == 'openai' then
    send_openai_raw(sys_prompt, user_msg, {}, on_resp)
  else
    vim.notify('go.nvim [AI]: unknown provider "' .. provider .. '"', vim.log.levels.ERROR)
  end
end

-- ─── GoCodeReview ────────────────────────────────────────────────────────────

--- Detect the default branch ofnd.
--- @return string
local function detect_default_branch()
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

--- Parse quickfix lines from the LLM response and open the quickfix list.
--- Lines not matching the format are silently skipped.
--- @param response string  Raw LLM output
--- @param filename string  Absolute path to the reviewed file
local function handle_review_response(response, filename)
  response = vim.trim(response)

  -- Strip accidental markdown fences
  response = response:gsub('^```%w*\n?', ''):gsub('\n?```$', '')
  response = vim.trim(response)

  local lines = vim.split(response, '\n', { plain = true })

  -- Detect "no issues" case: single non-quickfix line
  if #lines == 1 and not lines[1]:match('^[^:]+:%d+:') then
    vim.notify('go.nvim [CodeReview]: ' .. lines[1], vim.log.levels.INFO)
    return
  end

  local qflist = {}
  for _, line in ipairs(lines) do
    line = vim.trim(line)
    if line ~= '' then
      -- Try to parse:  filename:lnum:col: type: text
      --            or  filename:lnum: type: text  (col optional)
      local fname, lnum, col, text = line:match('^([^:]+):(%d+):(%d+):%s*(.+)$')
      if not fname then
        fname, lnum, text = line:match('^([^:]+):(%d+):%s*(.+)$')
        col = 1
      end
      if fname and lnum and text then
        -- Derive type (E/W/I) from leading severity word
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
        -- Fallback: treat unrecognised line as a general warning at line 1
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

--- Entry point for :GoCodeReview [-d [branch]]
--- Reviews the current buffer, visual selection, or diff against a branch.
---   :GoCodeReview           — review entire file
---   :'<,'>GoCodeReview      — review visual selection
---   :GoCodeReview -d        — review only changes vs main/master (auto-detected)
---   :GoCodeReview -d develop — review only changes vs 'develop'
--- @param opts table  Standard nvim command opts (range, line1, line2, fargs)
function M.code_review(opts)
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.enable then
    vim.notify(
      'go.nvim [AI]: AI is disabled. Set ai = { enable = true } in go.nvim setup to use GoCodeReview',
      vim.log.levels.WARN
    )
    return
  end

  local fargs = (type(opts) == 'table' and opts.fargs) or {}

  -- Parse flags: -d [branch], -b/--brief
  local diff_mode = false
  local diff_branch = nil
  local brief = false
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
    end
    i = i + 1
  end

  local filename = vim.fn.expand('%:p')

  if diff_mode then
    local branch = diff_branch or detect_default_branch()
    vim.notify('[GoCodeReview]: diffing against ' .. branch .. ' …', vim.log.levels.INFO)
    get_git_diff(filename, branch, function(diff, err)
      if err then
        vim.notify('[GoCodeReview]: ' .. err, vim.log.levels.WARN)
        return
      end
      local short_name = vim.fn.expand('%:t')
      local user_msg = string.format('File: %s\nBase branch: %s\n\n```diff\n%s\n```', short_name, branch, diff)
      local sys = brief and diff_review_system_prompt_short or diff_review_system_prompt
      M.request(sys, user_msg, { max_tokens = 1500, temperature = 0 }, function(resp)
        handle_review_response(resp, filename)
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

  if #lines == 0 then
    vim.notify('[GoCodeReview]: buffer is empty', vim.log.levels.WARN)
    return
  end

  -- Prefix each line with its file line number so the LLM references exact positions
  local numbered = {}
  for i_line, line in ipairs(lines) do
    table.insert(numbered, string.format('L%d| %s', start_line + i_line - 1, line))
  end
  local code = table.concat(numbered, '\n')
  local short_name = vim.fn.expand('%:t')
  local user_msg = string.format('File: %s\n\n```go\n%s\n```', short_name, code)

  vim.notify('[GoCodeReview]: reviewing …', vim.log.levels.INFO)

  local sys = brief and code_review_system_prompt_short or code_review_system_prompt
  M.request(sys, user_msg, { max_tokens = 1500, temperature = 0 }, function(resp)
    handle_review_response(resp, filename)
  end)
end

-- ---------------------------------------------------------------------------
-- GoAIChat
-- ---------------------------------------------------------------------------

local chat_system_prompt = [[You are an expert Go developer and code assistant embedded in Neovim via go.nvim.
The user may ask you to explain, examine, refactor, check, or otherwise discuss Go code or general Go questions.

Guidelines:
- Be concise but thorough. Prefer short paragraphs over long walls of text.
- When showing code, use plain fenced Go blocks (no extra commentary outside the block unless needed).
- When refactoring, show only the changed/relevant portion, not the entire file.
- When explaining, prefer bullet points for lists of properties or steps.
- Get straight to the answer.
- If the user provides a code snippet, treat it as the subject of the question.
- Always assume Go unless the user says otherwise.
]]

--- Render the chat response in a floating scratch window
--- @param response string
--- @param title string|nil
local function open_chat_float(response, title)
  local lines = vim.split(response, '\n', { plain = true })

  -- Add a blank leading line for padding
  table.insert(lines, 1, '')
  table.insert(lines, '')

  local width = math.min(math.max(60, vim.o.columns - 20), 120)
  local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.7))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf })

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. (title or 'GoAIChat') .. ' ',
    title_pos = 'center',
  })
  vim.api.nvim_set_option_value('wrap', true, { win = win })
  vim.api.nvim_set_option_value('linebreak', true, { win = win })

  -- Close keymaps
  for _, key in ipairs({ 'q', '<Esc>', '<CR>' }) do
    vim.keymap.set('n', key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, silent = true })
  end
end

--- Build a user message for GoAIChat, optionally embedding a code snippet
--- @param question string
--- @param code string|nil  selected or surrounding code, may be nil
--- @param lang string|nil  filetype / language hint
--- @return string
local function build_chat_user_msg(question, code, lang)
  lang = lang or 'go'
  if code and code ~= '' then
    return string.format('%s\n\n```%s\n%s\n```', question, lang, code)
  end
  return question
end

--- Entry point for :GoAIChat
--- @param opts table  Standard nvim command opts
function M.chat(opts)
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.enable then
    vim.notify(
      'go.nvim [AI]: AI is disabled. Set ai = { enable = true } in go.nvim setup to use GoAIChat',
      vim.log.levels.WARN
    )
    return
  end

  local fargs = (type(opts) == 'table' and opts.fargs) or {}
  local question = vim.trim(table.concat(fargs, ' '))

  -- Collect visual selection or surrounding function context
  local code = nil
  local lang = vim.bo.filetype or 'go'

  if type(opts) == 'table' and opts.range and opts.range == 2 then
    -- Visual selection
    local sel_lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
    code = table.concat(sel_lines, '\n')
  end

  local diff_text
  -- create git comments require git diff context
  if string.find(question, 'create a commit summary') then
    -- get diff against master/main
    local branch = 'master'
    if string.find(question, 'main') then
      branch = 'main'
    end

    local code_text = vim.fn.system({ 'git', 'diff', '-U10', branch, '--', '*.go' })

    if not code_text or #code_text == 0 then
      vim.notify('No code to commit', vim.log.levels.WARN)
      return
    end
    diff_text = code_text
  end

  local function dispatch(q)
    if q == '' then
      vim.notify('[GoAIChat]: empty question', vim.log.levels.WARN)
      return
    end
    local user_msg = build_chat_user_msg(q, code, lang)
    vim.notify('[GoAIChat]: thinking …', vim.log.levels.INFO)
    M.request(chat_system_prompt, user_msg, { max_tokens = 2000, temperature = 0.2 }, function(resp)
      open_chat_float(resp, q:sub(1, 60))
    end)
  end

  if diff_text then
    return dispatch(diff_text)
  end
  if question ~= '' then
    dispatch(question)
  else
    -- Interactive prompt
    vim.ui.input({
      prompt = 'GoAIChat> ',
      default = code and 'explain this code' or '',
    }, function(input)
      if input and input ~= '' then
        dispatch(input)
      end
    end)
  end
end

-- ─── Public request helper ─────────
--- @param opts table|nil  Optional: { temperature, max_tokens }
--- @param callback function  Called with the response text string
function M.request(sys_prompt, user_msg, opts, callback)
  opts = opts or {}
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.enable then
    vim.notify('[GoCodeReview]: AI is disabled. Set ai = { enable = true } in go.nvim setup', vim.log.levels.WARN)
    return
  end
  local provider = cfg.provider or 'copilot'

  if provider == 'copilot' then
    send_copilot_raw(sys_prompt, user_msg, opts, callback)
  elseif provider == 'openai' then
    send_openai_raw(sys_prompt, user_msg, opts, callback)
  else
    vim.notify('[GoCodeReview]: unknown provider "' .. provider .. '"', vim.log.levels.ERROR)
  end
end

M.code_review_system_prompt = code_review_system_prompt
M.code_review_system_prompt_short = code_review_system_prompt_short
M.diff_review_system_prompt = diff_review_system_prompt
M.diff_review_system_prompt_short = diff_review_system_prompt_short
M.chat_system_prompt = chat_system_prompt

return M
