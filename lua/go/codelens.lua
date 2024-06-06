local utils = require('go.utils')
local log = utils.log
local codelens = require('vim.lsp.codelens')

local M = {}
local enabled
function M.setup()
  utils.log('enable codelens')
  vim.api.nvim_set_hl(0, 'LspCodeLens', { link = 'WarningMsg', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensText', { link = 'WarningMsg', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensSign', { link = 'WarningMsg', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensSeparator', { link = 'Boolean', default = true })
  enabled = _GO_NVIM_CFG.lsp_codelens
  vim.api.nvim_create_autocmd({ 'BufRead', 'InsertLeave', 'BufWritePre' }, {
    group = vim.api.nvim_create_augroup('gonvim__codelenses', {}),
    pattern = { '*.go', '*.mod' },
    callback = function()
      if enabled then
        log('refresh codelens')
        require('go.codelens').refresh()
      end
    end,
  })
end

function M.run_action()
  local original_select = vim.ui.select

  vim.ui.select = _GO_NVIM_CFG.go_select()

  codelens.run()
  vim.defer_fn(function()
    vim.ui.select = original_select
  end, 1000)
end

function M.toggle()
  if enabled == true then
    log('toggle codelens disable', enabled)
    enabled = false
    vim.lsp.codelens.clear()
  else
    log('toggle codelens enable', enabled)
    enabled = true
    M.refresh()
  end
end

function M.refresh()
  local gopls = require('go.lsp').client()
  log('refresh codelens')
  if not gopls then -- and gopls.server_capabilities.codeLensProvider then
    return
  end
  if _GO_NVIM_CFG.lsp_codelens == true then
    vim.lsp.codelens.refresh({ bufnr = 0 })
  else
    log('refresh codelens')
    vim.lsp.codelens.clear(gopls.id, 0)
  end
end

return M
