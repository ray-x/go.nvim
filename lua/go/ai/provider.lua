-- LLM provider backends (Copilot, OpenAI-compatible) for go.nvim AI features
local M = {}

local utils = require('go.utils')
local log = utils.log

-- Cached Copilot API token
local _copilot_token = nil
local _copilot_token_expires = 0

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
--- @param url string
--- @param headers table
--- @param body string
--- @param callback function  Called with response text on success
--- @param on_error function|nil  Optional callback on HTTP error, called with (http_code, detail, error_code)
local function call_chat_api(url, headers, body, callback, on_error)
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
        local detail = resp_body:sub(1, 500)
        local error_code = nil
        -- Try to extract error message and code from JSON response
        local ok_json, err_data = pcall(vim.json.decode, resp_body)
        if ok_json and type(err_data) == 'table' and err_data.error then
          local e = err_data.error
          detail = type(e) == 'table' and (e.message or vim.inspect(e)) or tostring(e)
          error_code = type(e) == 'table' and e.code or nil
        end
        log('go.nvim [AI]: HTTP', http_code, 'body:', resp_body:sub(1, 1000))
        vim.notify('go.nvim [AI]: HTTP ' .. http_code .. ': ' .. detail, vim.log.levels.ERROR)
        if on_error then
          on_error(http_code, detail, error_code)
        end
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

-- Cached list of available Copilot models
local _copilot_models = nil

--- Fetch the list of available models from the Copilot API (cached).
--- @param token string  Copilot API token
--- @param callback function  Called with (models_table) where each entry has .id, .name, etc.
local function get_copilot_models(token, callback)
  if _copilot_models then
    callback(_copilot_models)
    return
  end

  local nvim_ver = string.format('%s.%s.%s', vim.version().major, vim.version().minor, vim.version().patch)
  vim.system({
    'curl', '-s', '--connect-timeout', '10', '--max-time', '15', '-w', '\n%{http_code}',
    '-H', 'Content-Type: application/json',
    '-H', 'Authorization: Bearer ' .. token,
    '-H', 'Copilot-Integration-Id: vscode-chat',
    '-H', 'Editor-Version: Neovim/' .. nvim_ver,
    '-H', 'Editor-Plugin-Version: go.nvim/1.0.0',
    'https://api.githubcopilot.com/models',
  }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil)
        return
      end
      local stdout = result.stdout or ''
      local body, http_code = split_http_response(stdout)
      if http_code ~= '200' then
        callback(nil)
        return
      end
      local ok, data = pcall(vim.json.decode, body)
      if ok and type(data) == 'table' and data.data then
        _copilot_models = data.data
        callback(_copilot_models)
      else
        callback(nil)
      end
    end)
  end)
end

--- Check if a model supports chat completions based on its capabilities.
--- If no capability info is available, assume it does (let the API decide).
local function model_supports_chat(m)
  if not m.capabilities then
    return true
  end
  -- capabilities.type can be 'chat', 'completion', 'embeddings', etc.
  if m.capabilities.type then
    return m.capabilities.type == 'chat'
  end
  -- Some models list supported families/endpoints
  if m.capabilities.family then
    return m.capabilities.family == 'chat' or m.capabilities.family == 'gpt'
  end
  return true
end

--- Resolve the model name: check if the configured model is available via Copilot,
--- fall back to default if not. Only considers models that support chat completions.
--- @param token string  Copilot API token
--- @param requested_model string  The model name from config
--- @param callback function  Called with (model_name)
local function resolve_copilot_model(token, requested_model, callback)
  get_copilot_models(token, function(models)
    if not models then
      -- Can't verify, use as-is and let the API decide
      callback(requested_model)
      return
    end

    -- Build a list of chat-capable models
    local chat_models = {}
    for _, m in ipairs(models) do
      if model_supports_chat(m) then
        table.insert(chat_models, m)
      end
    end

    -- Check if the requested model matches any chat-capable model id or name
    for _, m in ipairs(chat_models) do
      if m.id == requested_model or m.name == requested_model then
        callback(m.id)
        return
      end
    end

    -- Also try version-flexible matching: e.g. 'gpt-4o' matches 'gpt-4o-2024-08-06'
    for _, m in ipairs(chat_models) do
      if m.id and m.id:find(requested_model, 1, true) then
        log('[GoAI]: model "' .. requested_model .. '" resolved to "' .. m.id .. '"')
        callback(m.id)
        return
      end
    end

    -- Check if the model exists but doesn't support chat
    for _, m in ipairs(models) do
      if m.id == requested_model or m.name == requested_model
          or (m.id and m.id:find(requested_model, 1, true)) then
        local available = {}
        for _, cm in ipairs(chat_models) do
          if cm.id then table.insert(available, cm.id) end
        end
        vim.notify(
          string.format(
            'go.nvim [AI]: model "%s" does not support chat completions. Chat-capable models: %s. Falling back to "gpt-4o".',
            requested_model,
            table.concat(available, ', ')
          ),
          vim.log.levels.WARN
        )
        callback('gpt-4o')
        return
      end
    end

    -- Model not found at all — notify and fall back
    local available = {}
    for _, m in ipairs(chat_models) do
      if m.id then
        table.insert(available, m.id)
      end
    end
    vim.notify(
      string.format(
        'go.nvim [AI]: model "%s" not available via Copilot. Chat-capable models: %s. Falling back to "gpt-4o".',
        requested_model,
        table.concat(available, ', ')
      ),
      vim.log.levels.WARN
    )
    callback('gpt-4o')
  end)
end

--- Build the JSON body for a chat completion.
--- Adapts parameters based on model family for compatibility.
--- @param model string
--- @param sys_prompt string
--- @param user_msg string
--- @param opts table|nil  { temperature, max_tokens, copilot_proxy }
function M.build_body(model, sys_prompt, user_msg, opts)
  opts = opts or {}

  local body = {
    model = model,
    messages = {
      { role = 'system', content = sys_prompt },
      { role = 'user', content = user_msg },
    },
  }

  -- Detect model family for parameter compatibility
  local m = (model or ''):lower()
  local is_o_series = m:match('^o%d') ~= nil -- o1, o3, o4-mini, etc.

  -- Temperature: o-series models only accept temperature=1 (or omit it)
  if not is_o_series then
    body.temperature = opts.temperature or 0
  end

  -- When routing through the Copilot proxy, omit token limit parameters —
  -- the proxy enforces its own limits and rejects unknown parameters for
  -- non-OpenAI models (Claude, Gemini, etc.).
  if not opts.copilot_proxy then
    local token_limit = opts.max_tokens or 200
    local is_new_gpt = m:match('^gpt%-5') or m:match('^gpt%-4%.1')
    if is_o_series or is_new_gpt then
      body.max_completion_tokens = token_limit
    else
      body.max_tokens = token_limit
    end
  end
  log('[GoAI]: request body for model', model, vim.inspect(body))

  return vim.json.encode(body)
end

--- Build a request body for the OpenAI Responses API format.
--- Used for newer models that don't support /chat/completions.
function M.build_responses_body(model, sys_prompt, user_msg, opts)
  opts = opts or {}
  local body = {
    model = model,
    instructions = sys_prompt,
    input = user_msg,
  }

  local m = (model or ''):lower()
  local is_o_series = m:match('^o%d') ~= nil
  if not is_o_series then
    body.temperature = opts.temperature or 0
  end

  log('[GoAI]: request body for Responses API, model', model, vim.inspect(body))
  return vim.json.encode(body)
end

--- Parse a Responses API result into text content.
--- The Responses API returns output as an array of items.
local function parse_responses_result(resp_body)
  local ok, data = pcall(vim.json.decode, resp_body)
  if not ok or type(data) ~= 'table' then
    return nil
  end

  -- Check for error
  if data.error then
    return nil
  end

  -- Responses API format: { output: [ { type: "message", content: [ { type: "output_text", text: "..." } ] } ] }
  if data.output and type(data.output) == 'table' then
    local texts = {}
    for _, item in ipairs(data.output) do
      if item.type == 'message' and item.content then
        for _, part in ipairs(item.content) do
          if part.type == 'output_text' and part.text then
            table.insert(texts, part.text)
          end
        end
      end
    end
    if #texts > 0 then
      return vim.trim(table.concat(texts, '\n'))
    end
  end

  -- Fallback: some responses may have output_text directly
  if data.output_text then
    return vim.trim(data.output_text)
  end

  return nil
end

--- Generic helper: POST to the Responses API and parse the result
local function call_responses_api(url, headers, body, callback, on_error)
  local cmd = { 'curl', '-s', '--connect-timeout', '10', '--max-time', '60', '-w', '\n%{http_code}', '-X', 'POST' }
  for _, h in ipairs(headers) do
    table.insert(cmd, '-H')
    table.insert(cmd, h)
  end
  table.insert(cmd, '-d')
  table.insert(cmd, '@-')
  table.insert(cmd, url)

  vim.system(cmd, { text = true, stdin = body }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local msg = parse_curl_error(result.code, result.stderr)
        vim.notify('go.nvim [AI]: Responses API request failed: ' .. msg, vim.log.levels.ERROR)
        return
      end
      local stdout = result.stdout or ''
      local resp_body, http_code = split_http_response(stdout)
      if http_code ~= '200' then
        local detail = resp_body:sub(1, 500)
        local error_code = nil
        local ok_json, err_data = pcall(vim.json.decode, resp_body)
        if ok_json and type(err_data) == 'table' and err_data.error then
          local e = err_data.error
          detail = type(e) == 'table' and (e.message or vim.inspect(e)) or tostring(e)
          error_code = type(e) == 'table' and e.code or nil
        end
        log('go.nvim [AI]: Responses API HTTP', http_code, 'body:', resp_body:sub(1, 1000))
        vim.notify('go.nvim [AI]: HTTP ' .. http_code .. ': ' .. detail, vim.log.levels.ERROR)
        if on_error then
          on_error(http_code, detail, error_code)
        end
        return
      end
      local text = parse_responses_result(resp_body)
      if text then
        callback(text)
      else
        log('go.nvim [AI]: unexpected Responses API response:', resp_body:sub(1, 500))
        vim.notify('go.nvim [AI]: unexpected Responses API response: ' .. resp_body:sub(1, 200), vim.log.levels.ERROR)
      end
    end)
  end)
end

--- Send request via GitHub Copilot API using the Responses API endpoint.
function M.send_copilot(sys_prompt, user_msg, opts, callback)
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
    local requested_model = cfg.model or 'gpt-4o'
    resolve_copilot_model(token, requested_model, function(model)
      local body_opts = vim.tbl_extend('force', opts or {}, { copilot_proxy = true })
      local body = M.build_responses_body(model, sys_prompt, user_msg, body_opts)
      log('[GoAI]: sending to Responses API, model:', model)
      local nvim_ver = string.format('%s.%s.%s', vim.version().major, vim.version().minor, vim.version().patch)
      local headers = {
        'Content-Type: application/json',
        'Authorization: Bearer ' .. token,
        'Copilot-Integration-Id: vscode-chat',
        'Editor-Version: Neovim/' .. nvim_ver,
        'Editor-Plugin-Version: go.nvim/1.0.0',
        'User-Agent: go.nvim/1.0.0',
      }
      call_responses_api('https://api.githubcopilot.com/responses', headers, body, callback, function(_http_code, _detail, _error_code)
        -- On error, list available chat-capable models to help the user
        _copilot_models = nil
        get_copilot_models(token, function(models)
          if not models then
            return
          end
          local names = {}
          for _, m in ipairs(models) do
            if m.id and model_supports_chat(m) then
              table.insert(names, m.id)
            end
          end
          if #names > 0 then
            vim.notify(
              'go.nvim [AI]: available models: ' .. table.concat(names, ', '),
              vim.log.levels.INFO
            )
          end
        end)
      end)
    end)
  end)
end

--- Send request via OpenAI-compatible API (generic)
function M.send_openai(sys_prompt, user_msg, opts, callback)
  local cfg = _GO_NVIM_CFG.ai or {}
  local env_name = cfg.api_key_env or 'OPENAI_API_KEY'
  local api_key = os.getenv(env_name)
  local base_url = cfg.base_url or 'https://api.openai.com/v1'
  local model = cfg.model or 'gpt-4o-mini'

  if not api_key or api_key == '' then
    vim.notify('go.nvim [AI]: API key not found. Set the ' .. env_name .. ' environment variable', vim.log.levels.ERROR)
    return
  end

  local body = M.build_body(model, sys_prompt, user_msg, opts)
  local headers = {
    'Content-Type: application/json',
    'Authorization: Bearer ' .. api_key,
  }
  call_chat_api(base_url .. '/chat/completions', headers, body, callback)
end

--- Dispatch a request to the configured provider
--- @param sys_prompt string
--- @param user_msg string
--- @param opts table|nil  Optional: { temperature, max_tokens }
--- @param callback function  Called with the response text string
function M.request(sys_prompt, user_msg, opts, callback)
  opts = opts or {}
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.enable then
    vim.notify('[go.nvim AI]: AI is disabled. Set ai = { enable = true } in go.nvim setup', vim.log.levels.WARN)
    return
  end
  local provider = cfg.provider or 'copilot'

  if provider == 'copilot' then
    M.send_copilot(sys_prompt, user_msg, opts, callback)
  elseif provider == 'openai' then
    M.send_openai(sys_prompt, user_msg, opts, callback)
  else
    vim.notify('[go.nvim AI]: unknown provider "' .. provider .. '"', vim.log.levels.ERROR)
  end
end

return M
