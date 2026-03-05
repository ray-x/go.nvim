local M = {}
local uv = vim.uv or vim.loop
local log = require('go.utils').log
local json = vim.json

---@class McpClient
---@field handle uv_process_t
---@field stdin uv_pipe_t
---@field stdout uv_pipe_t
---@field pending table<number, function>
---@field next_id number
---@field buffer string
local McpClient = {}
McpClient.__index = McpClient

function M.new(opts)
  local self = setmetatable({}, McpClient)
  self.pending = {}
  self.next_id = 1
  self.buffer = ''
  self.ready = false
  self:_start(opts)
  return self
end

function McpClient:_start(opts)
  local cmd = opts.cmd or { 'gopls', 'mcp' }
  self.stdin = uv.new_pipe(false)
  self.stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local args = {}
  for i = 2, #cmd do
    args[i - 1] = cmd[i]
  end

  self.handle = uv.spawn(cmd[1], {
    args = args,
    stdio = { self.stdin, self.stdout, stderr },
    cwd = opts.root_dir or vim.fn.getcwd(),
  }, function(code, signal)
    log('gopls mcp exited', code, signal)
  end)

  if not self.handle then
    error('Failed to start gopls mcp: ' .. cmd[1])
  end

  -- Read stdout for JSON-RPC responses
  self.stdout:read_start(function(err, data)
    if err then
      log('mcp read error:', err)
      return
    end
    if data then
      self:_on_data(data)
    end
  end)

  stderr:read_start(function(_, data)
    if data then
      log('mcp stderr:', data)
    end
  end)

  -- Send MCP initialize
  self:request('initialize', {
    protocolVersion = '2025-03-26',
    capabilities = {},
    clientInfo = { name = 'go.nvim', version = '1.0.0' },
  }, function(err, result)
    if not err then
      self.ready = true
      -- Send initialized notification
      self:notify('notifications/initialized', {})
      log('MCP initialized, server:', result)
    else
      log('MCP init error:', err)
    end
  end)
end

--- Parse MCP JSON-RPC messages (newline-delimited JSON)
function McpClient:_on_data(data)
  self.buffer = self.buffer .. data
  while true do
    local nl = self.buffer:find('\n')
    if not nl then
      break
    end
    local line = self.buffer:sub(1, nl - 1)
    self.buffer = self.buffer:sub(nl + 1)

    if #line > 0 then
      local ok, msg = pcall(json.decode, line)
      if ok and msg then
        self:_handle_message(msg)
      end
    end
  end
end

function McpClient:_handle_message(msg)
  if msg.id and self.pending[msg.id] then
    local cb = self.pending[msg.id]
    self.pending[msg.id] = nil
    if msg.error then
      cb(msg.error, nil)
    else
      cb(nil, msg.result)
    end
  end
end

function McpClient:request(method, params, callback)
  local id = self.next_id
  self.next_id = self.next_id + 1
  self.pending[id] = callback

  local msg = json.encode({
    jsonrpc = '2.0',
    id = id,
    method = method,
    params = params,
  }) .. '\n'

  self.stdin:write(msg)
end

function McpClient:notify(method, params)
  local msg = json.encode({
    jsonrpc = '2.0',
    method = method,
    params = params,
  }) .. '\n'
  self.stdin:write(msg)
end

--- Call an MCP tool
---@param tool_name string
---@param arguments table
---@param callback function(err, result)
function McpClient:call_tool(tool_name, arguments, callback)
  self:request('tools/call', {
    name = tool_name,
    arguments = arguments,
  }, callback)
end

function McpClient:list_tools(callback)
  self:request('tools/list', {}, callback)
end

function McpClient:shutdown()
  if self.handle then
    self.stdin:close()
    self.stdout:close()
    self.handle:kill('sigterm')
  end
end

return M