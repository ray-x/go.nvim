local M = { _client = nil }
local client_mod = require('go.mcp.client')

function M.setup(opts)
  opts = opts or {}
  M._config = {
    gopls_cmd = opts.gopls_cmd or { 'gopls', 'mcp' },
    root_dir = opts.root_dir,
  }
end

function M.get_client()
  if not M._client then
    M._client = client_mod.new(M._config)
  end
  return M._client
end

function M.shutdown()
  if M._client then
    M._client:shutdown()
    M._client = nil
  end
end

return M
