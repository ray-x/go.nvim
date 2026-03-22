-- GoAIChat: AI-powered chat for go.nvim
local M = {}

local provider = require('go.ai.provider')
local macros = require('go.ai.macros')
local ui = require('go.ai.ui')
local session = require('go.ai.session')

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

M.chat_system_prompt = chat_system_prompt

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
function M.run(opts)
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.enable then
    vim.notify(
      'go.nvim [AI]: AI is disabled. Set ai = { enable = true } in go.nvim setup to use GoAIChat',
      vim.log.levels.WARN
    )
    return
  end

  local fargs = (type(opts) == 'table' and opts.fargs) or {}

  -- Use alt_getopt for argument parsing
  local alt_getopt = require('go.alt_getopt')
  local sh_opts = 'ch:' -- c: commitmsg, h: history (with optional arg)
  local long_opts = { commitmsg = 'c', history = 'h' }
  local opts_tbl, optind, unparsed = alt_getopt.get_opts(fargs, sh_opts, long_opts)
  local history_pairs = 0
  local generate_commitmsg = false
  if opts_tbl then
    if opts_tbl.h and type(opts_tbl.h) == 'string' and opts_tbl.h:match('^%d+$') then
      history_pairs = tonumber(opts_tbl.h)
    elseif opts_tbl.h then
      history_pairs = 0
    end
    if opts_tbl.c then
      generate_commitmsg = true
    end
  end
  local question = vim.trim(table.concat(unparsed or {}, ' '))

  local code = nil
  local lang = vim.bo.filetype or 'go'
  local bufnr = vim.api.nvim_get_current_buf()
  local func_name = nil

  -- 1. Visual selection: send selected code
  if type(opts) == 'table' and opts.range and opts.range == 2 then
    local sel_lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
    code = table.concat(sel_lines, '\n')

  -- 2. Cursor inside a function: send the function text
  elseif lang == 'go' then
    local func_text, fname = macros.get_enclosing_func(bufnr)
    if func_text and func_text ~= '' then
      code = func_text
      func_name = fname
    end
  end

  -- Handle commit/PR message generation with -c/--commitmsg flag or "create a commit summary"
  local diff_text
  if generate_commitmsg or question:find('create a commit summary') then
    local branch = question:find('main') and 'main' or 'master'
    local code_text = vim.fn.system({ 'git', 'diff', '-U10', branch, '--', '*.go' })
    if not code_text or #code_text == 0 then
      vim.notify('No code to commit', vim.log.levels.WARN)
      return
    end
    diff_text = code_text
    -- If no explicit question, set a default for commit/PR message
    if question == '' then
      question = 'Generate a commit message for the following diff.'
    end
  end

  -- When /buffer or /file macros are present, skip auto-attaching function code
  local has_context_macro = question:find('/buffer', 1, true) or question:find('/file', 1, true)
  if has_context_macro then
    code = nil
    func_name = nil
  end

  --- Dispatch the question with code context and optional LSP references
  local function dispatch(q)
    if q == '' then
      vim.notify('[GoAIChat]: empty question', vim.log.levels.WARN)
      return
    end
    macros.expand(q, bufnr, function(expanded_q, ctx_attachments)
      local user_msg = build_chat_user_msg(expanded_q, code, lang)
      if ctx_attachments and ctx_attachments ~= '' then
        user_msg = user_msg .. '\n\n' .. ctx_attachments
      end
      -- Build session-aware request options
      local req_opts = { max_tokens = 2000, temperature = 0.2 }
      local prev_id = session.last_response_id('chat')
      if prev_id then
        req_opts.previous_response_id = prev_id
      end
      if history_pairs > 0 then
        req_opts.history = session.recent_messages('chat', history_pairs)
      end

      -- Save user message to session
      session.append({ command = 'chat', role = 'user', content = user_msg })

      vim.notify('[GoAIChat]: thinking …', vim.log.levels.INFO)
      provider.request(chat_system_prompt, user_msg, req_opts, function(resp, response_id)
        -- Save assistant response to session
        session.append({ command = 'chat', role = 'assistant', content = resp, response_id = response_id })
        ui.open_chat_float(resp, q:sub(1, 60))
      end)
    end)
  end

  --- Dispatch with LSP reference context appended to code
  local function dispatch_with_refs(q)
    if not func_name or func_name == '' then
      dispatch(q)
      return
    end

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local mcp_ok, mcp_ctx = pcall(require, 'go.mcp.context')
    if not mcp_ok or not mcp_ctx.get_symbol_context_via_lsp then
      dispatch(q)
      return
    end

    vim.notify('[GoAIChat]: gathering references …', vim.log.levels.INFO)
    mcp_ctx.get_symbol_context_via_lsp(bufnr, row - 1, col, function(ref_text)
      vim.schedule(function()
        if ref_text and ref_text ~= '' and not ref_text:match('^%(no ') then
          code = code .. '\n\n--- References / Callers ---\n' .. ref_text
        end
        dispatch(q)
      end)
    end)
  end

  if diff_text then
    return dispatch(diff_text)
  end

  if question ~= '' then
    if func_name and func_name ~= '' and code and not code:find('create a commit') then
      dispatch_with_refs(question)
    else
      dispatch(question)
    end
  else
    -- Interactive prompt
    local default_q = code and 'explain this code' or ''
    vim.ui.input({
      prompt = 'GoAIChat> ',
      default = default_q,
    }, function(input)
      if input and input ~= '' then
        if input:find('/buffer', 1, true) or input:find('/file', 1, true) then
          code = nil
          func_name = nil
        end
        if func_name and func_name ~= '' then
          dispatch_with_refs(input)
        else
          dispatch(input)
        end
      end
    end)
  end
end

return M
