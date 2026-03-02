-- LLM-powered natural language command dispatcher for go.nvim
-- Usage: :GoAI run unit test for tags test
--        :GoAI  (interactive prompt)

local M = {}

local utils = require('go.utils')
local log = utils.log

-- Cached Copilot API token
local _copilot_token = nil
local _copilot_token_expires = 0

-- stylua: ignore
local valid_cmd_set = {}
for _, c in ipairs({
  'GoTest', 'GoTestFunc', 'GoTestFile', 'GoTestPkg', 'GoTestSubCase', 'GoTestSum',
  'GoAddTest', 'GoAddExpTest', 'GoAddAllTest', 'GoCoverage',
  'GoBuild', 'GoRun', 'GoGenerate', 'GoVet', 'GoLint', 'GoMake', 'GoStop',
  'GoFmt', 'GoImports',
  'GoIfErr', 'GoFillStruct', 'GoFillSwitch', 'GoFixPlurals', 'GoCmt',
  'GoImpl', 'GoEnum', 'GoGenReturn', 'GoJson2Struct',
  'GoAddTag', 'GoRmTag', 'GoClearTag', 'GoModifyTag',
  'GoModTidy', 'GoModVendor', 'GoModDnld', 'GoModGraph', 'GoModWhy', 'GoModInit',
  'GoGet', 'GoWork',
  'GoDoc', 'GoDocBrowser', 'GoAlt', 'GoAltV', 'GoAltS',
  'GoImplements', 'GoPkgOutline', 'GoPkgSymbols', 'GoListImports', 'GoCheat',
  'GoCodeAction', 'GoCodeLenAct', 'GoRename', 'GoGCDetails',
  'GoDebug', 'GoBreakToggle', 'GoBreakSave', 'GoBreakLoad',
  'GoDbgStop', 'GoDbgContinue', 'GoDbgKeys', 'GoCreateLaunch',
  'DapStop', 'DapRerun', 'BreakCondition', 'LogPoint', 'ReplRun', 'ReplToggle', 'ReplOpen',
  'GoInstallBinary', 'GoUpdateBinary', 'GoInstallBinaries', 'GoUpdateBinaries', 'GoTool',
  'GoMockGen',
  'GoEnv', 'GoProject', 'GoToggleInlay', 'GoVulnCheck',
  'GoNew', 'Gomvp', 'Ginkgo', 'GinkgoFunc', 'GinkgoFile',
  'GoGopls', 'GoCmtAI',
}) do
  valid_cmd_set[c] = true
end

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
]]

local system_prompt = [[You are a command translator for go.nvim, a Neovim plugin for Go development.
Your job is to translate natural language requests into the correct go.nvim Vim command.

Rules:
1. Return ONLY the Vim command to execute. No explanation, no markdown, no backticks, no extra text.
2. The command must start with one of the go.nvim commands from the reference below.
3. Include any necessary arguments exactly as they would be typed in the Vim command line.
4. If the request is ambiguous, choose the most likely command.
5. If the request cannot be mapped to any go.nvim command, return exactly: echo "No matching go.nvim command found"

]] .. command_catalog

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

  vim.system(
    {
      'curl', '-s',
      '--connect-timeout', '10',
      '--max-time', '15',
      '-w', '\n%{http_code}',
      '-H', 'Authorization: token ' .. oauth_token,
      '-H', 'Accept: application/json',
      'https://api.github.com/copilot_internal/v2/token',
    },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          local msg = parse_curl_error(result.code, result.stderr)
          vim.notify('go.nvim [AI]: Copilot token request failed: ' .. msg, vim.log.levels.ERROR)
          return
        end
        local stdout = result.stdout or ''
        local body, http_code = split_http_response(stdout)
        if http_code ~= '200' then
          vim.notify('go.nvim [AI]: Copilot token request returned HTTP ' .. http_code .. ': ' .. body:sub(1, 200), vim.log.levels.ERROR)
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
    end
  )
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
    vim.notify(
      'go.nvim [AI]: API key not found. Set the ' .. env_name .. ' environment variable',
      vim.log.levels.ERROR
    )
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
    vim.notify('go.nvim [AI]: AI is disabled. Set ai = { enable = true } in go.nvim setup to use GoAI', vim.log.levels.WARN)
    return
  end

  local prompt
  local range_prefix = ''

  if type(opts) == 'table' then
    prompt = table.concat(opts.fargs or {}, ' ')
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
        M._dispatch(input, range_prefix)
      end
    end)
    return
  end

  M._dispatch(prompt, range_prefix)
end

--- Dispatch the natural language request to the configured LLM provider
function M._dispatch(prompt, range_prefix)
  local cfg = _GO_NVIM_CFG.ai or {}
  local provider = cfg.provider or 'copilot'
  local confirm = cfg.confirm ~= false -- default true

  vim.notify('go.nvim [AI]: thinking …', vim.log.levels.INFO)

  local user_msg = build_user_message(prompt)

  local function on_resp(resp)
    handle_response(resp, confirm, range_prefix)
  end

  if provider == 'copilot' then
    send_copilot_raw(system_prompt, user_msg, {}, on_resp)
  elseif provider == 'openai' then
    send_openai_raw(system_prompt, user_msg, {}, on_resp)
  else
    vim.notify('go.nvim [AI]: unknown provider "' .. provider .. '"', vim.log.levels.ERROR)
  end
end

--- Generic LLM request for use by other modules.
--- @param sys_prompt string  The system prompt
--- @param user_msg string  The user message
--- @param opts table|nil  Optional: { temperature, max_tokens }
--- @param callback function  Called with the response text string
function M.request(sys_prompt, user_msg, opts, callback)
  opts = opts or {}
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.enable then
    vim.notify('go.nvim [AI]: AI is disabled. Set ai = { enable = true } in go.nvim setup', vim.log.levels.WARN)
    return
  end
  local provider = cfg.provider or 'copilot'

  if provider == 'copilot' then
    send_copilot_raw(sys_prompt, user_msg, opts, callback)
  elseif provider == 'openai' then
    send_openai_raw(sys_prompt, user_msg, opts, callback)
  else
    vim.notify('go.nvim [AI]: unknown provider "' .. provider .. '"', vim.log.levels.ERROR)
  end
end

return M
