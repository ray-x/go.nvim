local api = vim.api
local lsp = vim.lsp

local util = require('go.utils')

local log = util.log
local trace = util.trace
-- local trace = log
local M = {}

M.config = {
  enabled = true,
  prefix = '  ',
  prefix_highlight = 'Comment',
  separator = ', ',
  highlight = 'Constant',
  loadfile = true, -- should we load the implementations file and get details
  debounce = 1000, -- delay in ms
  autocmd = { 'BufEnter', 'TextChanged', 'CursorMoved', 'CursorHold' },
}

local function get_document_symbols(client, bufnr, callback)
  local params = vim.lsp.util.make_position_params()
  client.request('textDocument/documentSymbol', params, callback, bufnr)
end

local function get_implementations(client, bufnr, position, callback, ctx)
  local params = vim.lsp.util.make_position_params()
  params.position = position
  log('Getting implementations:', params, ctx)
  client.request('textDocument/implementation', params, callback, bufnr)
end

local function find_potential_implementations(symbols, ctx)
  local potential = {}
  for _, symbol in ipairs(symbols or {}) do
    local kind = vim.lsp.protocol.SymbolKind[symbol.kind]
    trace('Checking symbol:', symbol)
    if kind == 'Interface' or kind == 'Struct' or kind == 'TypeAlias' then
      potential[symbol.name] = symbol
    end
  end
  trace('Potential implementations:', potential)
  log('Potential implementations:', #potential)
  return potential
end

local function show_virtual_text(bufnr, line, implementations)
  log('Showing virtual text:', bufnr, line, implementations)
  if not M.config.enabled or vim.tbl_isempty(implementations) then
    return
  end

  local text = {}
  for _, impl in ipairs(implementations) do
    table.insert(text, impl[1])
  end
  local text = table.concat(text, M.config.separator)
  local virtual_text_opts = {
    virt_text = {
      { M.config.prefix, M.config.prefix_highlight },
      { text, M.config.highlight },
    },
  }

  log('Showing virtual text:', virtual_text_opts, bufnr, line - 1)
  if not M.bufnr or not M.bufnr.ns then
    M.bufnr = { ns = api.nvim_create_namespace('lsp_impl'), ids = {} }
  end
  local id = api.nvim_buf_set_extmark(bufnr, M.bufnr.ns, line - 1, 0, virtual_text_opts)
  table.insert(M.bufnr.ids, id)
end

local update_virtual_text, update_timer = util.debounce(function(bufnr)
  local client = lsp.get_clients({ bufnr = bufnr, name = 'gopls' })[1]
  if not client then
    return
  end
  -- clear extmark first
  if M.bufnr and M.bufnr.ns then
    for id, _ in ipairs(M.bufnr.ids) do
      api.nvim_buf_del_extmark(bufnr, M.bufnr.ns, id)
    end
    M.bufnr.ids = {}
  end

  local function handle_document_symbols(err, result, ctx)
    if err then
      log('Error getting document symbols:', err)
      return
    end -- Handle error
    log('Got document symbols:', ctx, #result)

    local potential_implementations = find_potential_implementations(result, ctx)

    -- Clear existing virtual text

    for symbol_name, symbol in pairs(potential_implementations) do
      local position = symbol.range.start

      local function handle_implementations(err, impl_result, ctx)
        if err then
          log('Error getting implementations:', err)
          return
        end -- Handle error
        trace('Got implementations:', ctx, #impl_result)

        local implementations = {}
        for _, impls in ipairs(impl_result or {}) do
          trace('Checking impl location:', impls)
          local uri = impls.uri
          local filename = vim.uri_to_fname(uri)
          local target_bufnr = vim.uri_to_bufnr(uri)
          local line = impls.range.start.line
          local col = impls.range.start.character
          local text
          -- if not open the file, open it
          if not api.nvim_buf_is_loaded(target_bufnr) and M.config.loadfile then
            vim.fn.bufload(target_bufnr)
            text = api.nvim_buf_get_lines(target_bufnr, line, line + 1, false)[1]
          else
            -- show file name(without path) only
            text = filename
            local parts = vim.split(filename, util.sep())
            if #parts > 0 then
              text = parts[#parts]
            end
          end
          -- sometime the result is `type interfacename interface{`
          -- so we need to remove the `type` and anything after `interface`
          text = text:gsub('^%s*type%s*', ''):gsub('%s*interface.*', '')
          log('Checking impl symbol:', filename, line, col, text)
          table.insert(implementations, { text, filename, line, col })
        end

        if not vim.tbl_isempty(implementations) then
          show_virtual_text(bufnr, position.line + 1, implementations)
        end
      end

      log('Getting implementations for:', symbol_name, position, implementations)
      get_implementations(client, bufnr, position, handle_implementations, ctx)
    end
  end

  get_document_symbols(client, bufnr, handle_document_symbols)
end, M.config.debounce)

local function attach(bufnr)
  vim.api.nvim_create_autocmd(M.config.autocmd, {
    buffer = bufnr,
    callback = function()
      update_virtual_text(bufnr)
    end,
  })
end

M.setup = function(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
      local bufnr = ev.buf
      local client = lsp.get_clients({ bufnr = bufnr, name = 'gopls' })
      if client then
        attach(bufnr)
      end
    end,
  })
end

return M
