-- AI session management for go.nvim
-- Persists conversation history per workspace in stdpath('cache')/go_nvim_ai/
-- Session files are JSON, organized by workspace folder name, with append-mode entries.
local M = {}

local utils = require('go.utils')
local log = utils.log

--- Get the session directory under stdpath('cache')
--- @return string
local function session_dir()
  return vim.fn.stdpath('cache') .. '/go_nvim_ai'
end

--- Derive a safe filename from the current workspace/folder path.
--- Uses the cwd (or first workspace folder) and converts path separators to underscores.
--- @return string  Session file basename (without extension)
local function workspace_key()
  local cwd = vim.fn.getcwd()
  -- Strip trailing slash, replace path separators and colons with underscores
  local key = cwd:gsub('[/\\:]+$', ''):gsub('[/\\:]', '_'):gsub('^_+', '')
  if key == '' then
    key = 'default'
  end
  return key
end

--- Get the full path to the session file for the current workspace.
--- @return string
function M.session_file()
  return session_dir() .. '/' .. workspace_key() .. '.json'
end

--- Ensure the session directory exists.
local function ensure_dir()
  local dir = session_dir()
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end
end

--- Read the session file and return the full session data table.
--- @return table  { entries = { ... } }
local function read_session()
  local path = M.session_file()
  local f = io.open(path, 'r')
  if not f then
    return { entries = {} }
  end
  local content = f:read('*a')
  f:close()
  if content == '' then
    return { entries = {} }
  end
  local ok, data = pcall(vim.json.decode, content)
  if ok and type(data) == 'table' and type(data.entries) == 'table' then
    return data
  end
  log('[GoAI session]: corrupt session file, resetting:', path)
  return { entries = {} }
end

--- Write session data to disk (overwrite).
--- @param data table
local function write_session(data)
  ensure_dir()
  local path = M.session_file()
  local ok, json = pcall(vim.json.encode, data)
  if not ok then
    log('[GoAI session]: failed to encode session data')
    return
  end
  local f = io.open(path, 'w')
  if not f then
    log('[GoAI session]: failed to open session file for writing:', path)
    return
  end
  f:write(json)
  f:close()
end

--- Append a conversation entry to the session.
--- Each entry records: timestamp, command (chat/edit/review), role, content, and optional response_id.
--- @param entry table  { command, role, content, response_id?, model? }
function M.append(entry)
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.session or not cfg.session.enable then
    return
  end
  local data = read_session()
  entry.timestamp = os.time()
  entry.workspace = vim.fn.getcwd()
  table.insert(data.entries, entry)
  write_session(data)
  log('[GoAI session]: appended entry, command:', entry.command, 'total:', #data.entries)
end

--- Get the last response_id for a given command type (for Copilot Responses API chaining).
--- @param command string|nil  Filter by command type ('chat', 'edit', 'review'), or nil for any
--- @return string|nil
function M.last_response_id(command)
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.session or not cfg.session.enable then
    return nil
  end
  local data = read_session()
  for i = #data.entries, 1, -1 do
    local e = data.entries[i]
    if e.response_id and e.response_id ~= '' then
      if not command or e.command == command then
        return e.response_id
      end
    end
  end
  return nil
end

--- Get recent conversation messages for building multi-turn context.
--- Returns the last N user+assistant message pairs for the given command type.
--- @param command string|nil  Filter by command type, or nil for all
--- @param max_pairs number|nil  Max number of pairs to return (default: 5)
--- @return table  Array of { role = 'user'|'assistant', content = string }
function M.recent_messages(command, max_pairs)
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.session or not cfg.session.enable then
    return {}
  end
  max_pairs = max_pairs or 5
  local data = read_session()
  local messages = {}
  -- Collect entries matching the command, newest first
  local matching = {}
  for i = #data.entries, 1, -1 do
    local e = data.entries[i]
    if (not command or e.command == command) and e.role and e.content then
      table.insert(matching, e)
    end
  end
  -- Reverse to chronological order, limit to last max_pairs * 2 entries
  local limit = max_pairs * 2
  local start = math.max(1, #matching - limit + 1)
  for i = #matching, start, -1 do
    table.insert(messages, { role = matching[i].role, content = matching[i].content })
  end
  return messages
end

--- Trim session entries older than `days` days.
--- @param days number|nil  Number of days to keep (default: from config, or 30)
function M.trim(days)
  local cfg = _GO_NVIM_CFG.ai or {}
  days = days or (cfg.session and cfg.session.trim_days) or 30
  local cutoff = os.time() - (days * 86400)
  local data = read_session()
  local kept = {}
  for _, e in ipairs(data.entries) do
    if (e.timestamp or 0) >= cutoff then
      table.insert(kept, e)
    end
  end
  local removed = #data.entries - #kept
  data.entries = kept
  write_session(data)
  return removed
end

--- Delete the session file for the current workspace.
function M.delete()
  local path = M.session_file()
  if vim.fn.filereadable(path) == 1 then
    os.remove(path)
    return true
  end
  return false
end

--- Get session info (for display).
--- @return table  { file, workspace, entry_count, first_ts, last_ts, commands }
function M.info()
  local path = M.session_file()
  local data = read_session()
  local entries = data.entries
  local info = {
    file = path,
    workspace = vim.fn.getcwd(),
    entry_count = #entries,
    first_ts = entries[1] and entries[1].timestamp or nil,
    last_ts = entries[#entries] and entries[#entries].timestamp or nil,
    commands = {},
  }
  -- Count by command type
  local cmd_counts = {}
  for _, e in ipairs(entries) do
    local c = e.command or 'unknown'
    cmd_counts[c] = (cmd_counts[c] or 0) + 1
  end
  info.commands = cmd_counts
  return info
end

--- List all session files across workspaces.
--- @return table  Array of { file, workspace_key, size_bytes }
function M.list_all()
  local dir = session_dir()
  if vim.fn.isdirectory(dir) == 0 then
    return {}
  end
  local files = vim.fn.glob(dir .. '/*.json', false, true)
  local result = {}
  for _, f in ipairs(files) do
    local key = vim.fn.fnamemodify(f, ':t:r')
    local size = vim.fn.getfsize(f)
    table.insert(result, { file = f, workspace_key = key, size_bytes = size })
  end
  return result
end

--- Auto-trim on load if configured.
function M.auto_trim()
  local cfg = _GO_NVIM_CFG.ai or {}
  if not cfg.session or not cfg.session.enable then
    return
  end
  local days = cfg.session.trim_days
  if days and days > 0 then
    local removed = M.trim(days)
    if removed > 0 then
      log('[GoAI session]: auto-trimmed', removed, 'entries older than', days, 'days')
    end
  end
end

--- Get the last assistant response, optionally filtered by command type.
--- @param command string|nil  Filter by command type ('chat', 'edit', 'review', 'explain'), or nil for any
--- @return table|nil  { command, content, timestamp, response_id } or nil
function M.last_response(command)
  local data = read_session()
  for i = #data.entries, 1, -1 do
    local e = data.entries[i]
    if e.role == 'assistant' and e.content and e.content ~= '' then
      if not command or e.command == command then
        return e
      end
    end
  end
  return nil
end

return M
