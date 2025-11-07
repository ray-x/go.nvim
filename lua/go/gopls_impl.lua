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
  loadfile = true,     -- should we load the implementations file and get details
  debounce = 1000,     -- delay in ms
  virt_text_pos = nil, -- default to eol
  autocmd = { 'BufEnter', 'TextChanged', 'CursorMoved', 'CursorHold' },
}

local finding_impls = false

local function get_document_symbols(client, bufnr, callback)
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  client:request('textDocument/documentSymbol', params, callback, bufnr)
end

local function get_implementations(client, bufnr, position, callback, ctx)
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  params.position = position
  trace('Getting implementations:', params, ctx)
  client:request('textDocument/implementation', params, callback, bufnr)
  util.yield_for(100)
end

local function find_potential_implementations(symbols, ctx)
  local potential = {}
  for _, symbol in ipairs(symbols or {}) do
    -- if symbol is not in current screen ignore
    local line = symbol.range.start.line
    local cur_line = api.nvim_win_get_cursor(0)[1]
    -- no need to check if the symbol is not in the current screen
    if line < cur_line - 60 or line > cur_line + 60 then -- 60 lines above and below is my best guess
      trace('Ignoring symbol:', symbol, line, cur_line)
      goto continue
    end

    trace('Checking symbol:', symbol)
    local kind = vim.lsp.protocol.SymbolKind[symbol.kind]
    if kind == 'Interface' or kind == 'Struct' or kind == 'TypeAlias' then
      potential[symbol.name] = symbol
    end
    ::continue::
  end
  trace('Potential implementations:', potential)
  return potential
end

local function show_virtual_text(bufnr, line, implementations)
  trace('Showing virtual text:', bufnr, line, implementations)
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
      { text,            M.config.highlight },
    },
  }
  if M.config.virt_text_pos then
    virtual_text_opts.virt_text_pos = M.config.virt_text_pos
  end

  if not M.bufnr or not M.bufnr.ns then
    M.bufnr = { ns = api.nvim_create_namespace('lsp_impl'), ids = {}, text = {} }
  end
  -- check if the virtual text is already shown
  if M.bufnr.text[line] == text and text then
    trace('Virtual text already shown:', bufnr, line, text)
    return
  end
  local deleted = api.nvim_buf_del_extmark(bufnr, M.bufnr.ns, M.bufnr.ids[line] or 0)
  if not deleted then
    log('Failed delete extmark', bufnr, M.bufnr.ns, M.bufnr.ids, line)
  end
  local id = api.nvim_buf_set_extmark(bufnr, M.bufnr.ns, line - 1, 0, virtual_text_opts)

  log('Showing virtual text:', virtual_text_opts, bufnr, line - 1)
  table.insert(M.bufnr.ids, id)
  M.bufnr.text[line] = text
  M.bufnr.ids[line] = id
end

local update_virtual_text, update_timer = util.debounce(function(bufnr)
  local client = lsp.get_clients({ bufnr = bufnr, name = 'gopls' })[1]
  if not client then
    return
  end

  if finding_impls then
    return
  end
  local function handle_document_symbols(err, result, ctx)
    if err then
      log('Error getting document symbols:', err)
      return
    end -- Handle error

    local potential_implementations = find_potential_implementations(result, ctx)

    for symbol_name, symbol in pairs(potential_implementations) do
      local position = symbol.range.start

      local function handle_implementations(err, impl_result, ctx)
        if err then
          log('Error getting implementations:', err)
          return
        end -- Handle error
        if vim.fn.empty(impl_result) == 1 then
          return
        end
        trace('Got implementations:', ctx, impl_result)

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
          if api.nvim_buf_is_loaded(target_bufnr) or M.config.loadfile then
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
          text = text:gsub('^%s*type%s*', ''):gsub('%s*interface.*', ''):gsub('%s*struct.*', '')
          trace('Checking impl symbol:', filename, line, col, text)
          table.insert(implementations, { text, filename, line, col })
        end

        if not vim.tbl_isempty(implementations) then
          show_virtual_text(bufnr, position.line + 1, implementations)
        end
      end

      trace('Getting implementations for:', symbol_name, position, potential_implementations)
      coroutine.wrap(get_implementations)(client, bufnr, position, handle_implementations, ctx)
    end

    finding_impls = false
  end

  get_document_symbols(client, bufnr, handle_document_symbols)
end, M.config.debounce)

local function attach(bufnr)
  vim.api.nvim_create_autocmd(M.config.autocmd, {
    buffer = bufnr,
    callback = function(ev)
      if ev.event == 'BufWritePost' then
        finding_impls = false -- enforce to find implementations
      end
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
