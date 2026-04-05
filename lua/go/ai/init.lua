-- GoAI dispatcher and public API surface for go.nvim AI features
-- Re-exports from submodules for backward compatibility.
local M = {}

local utils = require('go.utils')
local log = utils.log
local provider = require('go.ai.provider')
local macros = require('go.ai.macros')
local ui = require('go.ai.ui')
local review_mod = require('go.ai.review')
local chat_mod = require('go.ai.chat')
local edit_mod = require('go.ai.edit')
local session_mod = require('go.ai.session')

-- ─── Command catalog & validation ──────────────────────────────────────────

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
  'GinkgoFunc', 'GinkgoFile', 'GoGopls', 'GoCmtAI', 'GoCodeReview', 'GoDocAI', 'GoAIEdit', 'GoAISession',
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
- GoFmt [formatter] — Format file. Args: gofmt, goimports, gofumpt
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
- GoCodeReview — Review the current Go file (or visual selection) with AI; outputs findings to the vim quickfix list. Args: -d [branch] (diff mode), -b (brief), -e [branch] (explain mode — summarize the PR in markdown), -m <message> (change description)
- GoDocAI [query] — Find a function/type by vague name and generate rich AI documentation from its source code
- GoAIEdit [instruction] — Edit code with AI. Sends visual selection or enclosing function to the LLM with your instruction, shows a diff preview. Accept with <CR>/ga, reject with q/<Esc>
- GoAISession [info|delete|trim [days]|list] — Manage AI session data. info: show session details, delete: remove session for current workspace, trim [days]: remove entries older than N days, list: show all session files
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

-- ─── Command helpers ────────────────────────────────────────────────────────

--- Build the user message with workspace context
local function build_user_message(request)
  local file = vim.fn.expand('%:t') or ''
  local ft = vim.bo.filetype or ''
  return string.format('Current file: %s (filetype: %s)\nRequest: %s', file, ft, request)
end

--- Validate that the LLM response is a known go.nvim command
local function validate_response(cmd_str)
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
  cmd_str = cmd_str:gsub('^```%w*\n?', ''):gsub('\n?```$', '')
  cmd_str = vim.trim(cmd_str)
  cmd_str = cmd_str:match('^([^\n]+)') or cmd_str

  log('go.nvim [AI]: LLM response:', cmd_str)

  if not validate_response(cmd_str) then
    log('go.nvim [AI]: unrecognised command:', cmd_str)
    vim.notify('go.nvim [AI]: unrecognised command: ' .. cmd_str, vim.log.levels.WARN)
    return
  end

  if cmd_str:match('^echo ') then
    vim.cmd(cmd_str)
    return
  end

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

-- ─── GoAI entry points ─────────────────────────────────────────────────────

--- Entry point for :GoAI 'run unit test for tags test'
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
    local filtered = {}
    for _, arg in ipairs(fargs) do
      if arg == '-f' then
        full_catalog = true
      else
        table.insert(filtered, arg)
      end
    end
    prompt = table.concat(filtered, ' ')
    if opts.range and opts.range == 2 then
      range_prefix = string.format('%d,%d', opts.line1, opts.line2)
    end
  else
    prompt = opts or ''
  end

  local source_bufnr = vim.api.nvim_get_current_buf()

  if prompt == '' then
    vim.ui.input({ prompt = 'go.nvim AI> ' }, function(input)
      if input and input ~= '' then
        M._dispatch(input, range_prefix, full_catalog, source_bufnr)
      end
    end)
    return
  end

  M._dispatch(prompt, range_prefix, full_catalog, source_bufnr)
end

--- Dispatch the natural language request to the configured LLM provider
function M._dispatch(prompt, range_prefix, full_catalog, source_bufnr)
  local cfg = _GO_NVIM_CFG.ai or {}
  local prov = cfg.provider or 'copilot'
  local confirm = cfg.confirm ~= false -- default true

  macros.expand(prompt, source_bufnr or vim.api.nvim_get_current_buf(), function(expanded, ctx_attachments)
    vim.notify('go.nvim [AI]: thinking …', vim.log.levels.INFO)

    local sys_prompt = full_catalog and system_prompt or system_prompt_base
    local user_msg = build_user_message(expanded)
    if ctx_attachments and ctx_attachments ~= '' then
      user_msg = user_msg .. '\n\n' .. ctx_attachments
    end

    local function on_resp(resp)
      handle_response(resp, confirm, range_prefix)
    end

    if prov == 'copilot' then
      provider.send_copilot(sys_prompt, user_msg, {}, on_resp)
    elseif prov == 'openai' then
      provider.send_openai(sys_prompt, user_msg, {}, on_resp)
    else
      vim.notify('go.nvim [AI]: unknown provider "' .. prov .. '"', vim.log.levels.ERROR)
    end
  end)
end

-- ─── Re-exports for backward compatibility ──────────────────────────────────

-- provider
M.request = provider.request
M.send_copilot = provider.send_copilot
M.send_openai = provider.send_openai
M.build_body = provider.build_body

-- macros
M.expand_macros = macros.expand
M.has_macros = macros.has_macros
M.get_enclosing_func = macros.get_enclosing_func

-- ui
M.show_markdown_float = ui.show_markdown_float
M.open_chat_float = ui.open_chat_float

-- review
M.code_review = review_mod.run
M.handle_review_response = review_mod.handle_response
M.detect_default_branch = review_mod.detect_default_branch
M.code_review_system_prompt = review_mod.code_review_system_prompt
M.code_review_system_prompt_short = review_mod.code_review_system_prompt_short
M.diff_review_system_prompt = review_mod.diff_review_system_prompt
M.diff_review_system_prompt_short = review_mod.diff_review_system_prompt_short
M.explain_system_prompt = review_mod.explain_system_prompt

-- chat
M.chat = chat_mod.run
M.chat_system_prompt = chat_mod.chat_system_prompt

-- edit
M.edit = edit_mod.run

-- session
M.session = session_mod

-- Auto-trim old session entries on module load
session_mod.auto_trim()

return M
