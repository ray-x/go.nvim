local utils = require('go.utils')
local log = utils.log
local codelens = require('vim.lsp.codelens')

-- runs callback if gopls supports codelens
local function with_gopls_codelens(callback)
  -- prevent errors from codelens if lsp is not ready
  if not vim.lsp.buf.server_ready() then
    return
  end
  for _, gopls in pairs(vim.lsp.get_active_clients({ name = 'gopls', bufnr = 0 })) do
    if gopls:supports_method('textDocument/codeLens') then
      callback()
    else
      log('gopls does not support textDocument/codelens method')
    end
    return
  end
  log('gopls lsp client not found')
end

-- refreshes codelens if gopls supports codelens
local function refresh()
  with_gopls_codelens(function()
    log('refresh codelens')
    codelens.refresh()
  end)
end

-- clears codelens if gopls supports codelens
local function clear()
  with_gopls_codelens(function()
    log('clear codelens')
    codelens.clear()
  end)
end

local M = {}
local enabled
function M.setup()
  log('setup codelens, enabled=', _GO_NVIM_CFG.lsp_codelens)
  vim.api.nvim_set_hl(0, 'LspCodeLens', { link = 'WarningMsg', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensText', { link = 'WarningMsg', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensSign', { link = 'WarningMsg', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensSeparator', { link = 'Boolean', default = true })
  enabled = _GO_NVIM_CFG.lsp_codelens
  vim.api.nvim_create_autocmd({ 'BufRead', 'InsertLeave', 'BufWritePre' }, {
    group = vim.api.nvim_create_augroup('gonvim__codelenses', {}),
    pattern = { '*.go', '*.mod' },
    callback = function()
      if enabled then refresh() end
    end,
  })
end

function M.run_action()
  local guihua = utils.load_plugin('guihua.lua', 'guihua.gui')
  local original_select = vim.ui.select

  if guihua then
    vim.ui.select = require('guihua.gui').select
  end

  codelens.run()
  vim.defer_fn(function()
    vim.ui.select = original_select
  end, 1000)
end

function M.toggle()
  log('toggle codelens enabled=', enabled)
  if enabled then
    clear()
  else
    refresh()
  end
  enabled = not enabled
end

return M
