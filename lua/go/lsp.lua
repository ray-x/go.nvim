local vim, api = vim, vim.api
local utils = require('go.utils')
local log = utils.log
local trace = utils.trace
local diagnostic_map = function(bufnr)
  local opts = { noremap = true, silent = true }
  api.nvim_buf_set_keymap(bufnr, 'n', ']O', ':lua vim.diagnostic.setloclist()<CR>', opts)
end

if vim.lsp.buf.format == nil then
  -- neovim < 0.8 only
  vim.lsp.buf.format = function(options)
    if options.async then
      vim.lsp.buf.formatting()
    else
      vim.lsp.buf.formatting_sync()
    end
  end
end

local codelens_enabled = false

local on_attach = function(client, bufnr)
  log('go.nvim on_on_attach', client, bufnr)
  local function buf_set_keymap(...)
    vim.api.nvim_buf_set_keymap(bufnr, ...)
  end
  local uri = vim.uri_from_bufnr(bufnr)
  if uri == 'file://' or uri == 'file:///' or #uri < 11 then
    return { error = 'invalid file', result = nil }
  end
  diagnostic_map(bufnr)
  -- add highlight for Lspxxx

  api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  local opts = { noremap = true, silent = true }
  if _GO_NVIM_CFG.lsp_document_formatting == false then
    -- client.resolved_capabilities.document_formatting = false
    client.server_capabilities.documentFormattingProvider = false
  end

  if _GO_NVIM_CFG.lsp_codelens then
    codelens_enabled = (client.server_capabilities.codeLensProvider ~= false)
    if not codelens_enabled then
      vim.notify('codelens not support by your gopls', vim.log.levels.WARN)
    end
    vim.lsp.codelens.refresh()
  end

  if _GO_NVIM_CFG.lsp_keymaps == true then
    log('go.nvim lsp_keymaps', client, bufnr)
    buf_set_keymap('n', '<Leader>ff', '<Cmd>lua vim.lsp.buf.format({async = true}))<CR>', opts)
    buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
    buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
    buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
    buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
    buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
    buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
    buf_set_keymap(
      'n',
      '<space>wl',
      '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>',
      opts
    )
    buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
    buf_set_keymap('n', '<space>rn', "<cmd>lua require('go.rename').run()<CR>", opts)
    buf_set_keymap(
      'n',
      '<space>ca',
      "<cmd>lua require('go.codeaction').run_code_action()<CR>",
      opts
    )
    buf_set_keymap(
      'v',
      '<space>ca',
      "<cmd>lua require('go.codeaction').run_range_code_action()<CR>",
      opts
    )
    buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
    buf_set_keymap('n', '<space>e', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
    buf_set_keymap('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
    buf_set_keymap('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
    buf_set_keymap('n', '<space>q', '<cmd>lua vim.diagnostic.setloclist()<CR>', opts)

    if client.server_capabilities.documentFormattingProvider then
      buf_set_keymap('n', '<space>ff', '<cmd>lua vim.lsp.buf.format({async = true})<CR>', opts)
    end

    -- local vim_version = vim.version().major * 100 + vim.version().minor * 10 + vim.version().patch
  elseif type(_GO_NVIM_CFG.lsp_keymaps) == 'function' then
    _GO_NVIM_CFG.lsp_keymaps(bufnr)
  end
  if client.name == 'gopls' and vim.fn.has('nvim-0.8.3') == 1 then
    local semantic = client.config.capabilities.textDocument.semanticTokens
    local provider = client.server_capabilities.semanticTokensProvider
    if semantic then
      client.server_capabilities.semanticTokensProvider =
        vim.tbl_deep_extend('force', provider or {}, {
          full = true,
          legend = {
            tokenTypes = {
              'namespace',
              'type',
              'class',
              'enum',
              'interface',
              'struct',
              'typeParameter',
              'parameter',
              'variable',
              'property',
              'enumMember',
              'event',
              'function',
              'method',
              'macro',
              'keyword',
              'modifier',
              'comment',
              'string',
              'number',
              'regexp',
              'operator',
            },
            tokenModifiers = {
              'declaration',
              'definition',
              'readonly',
              'static',
              'deprecated',
              'abstract',
              'async',
              'modification',
              'documentation',
              'defaultLibrary',
            },
          },
          range = true,
        })
    end
  end
end

local extend_config = function(gopls, opts)
  if next(opts) == nil or gopls == nil then
    return gopls
  end
  for key, value in pairs(opts) do
    if type(gopls[key]) == 'table' and type(value) == 'table' then
      gopls[key] = vim.tbl_deep_extend('force', gopls[key], value)
    else
      if type(gopls[key]) ~= type(value) and key ~= 'handlers' then
        vim.notify('gopls setup for ' .. key .. ' is not ' .. type(value))
      end
      gopls[key] = value
    end
  end
  return gopls
end

local M = {}

function M.client()
  local clients = vim.lsp.get_active_clients()
  for _, cl in pairs(clients) do
    if cl.name == 'gopls' then
      return cl
    end
  end
end

function M.config()
  local gopls = require('go.gopls').setups()
  if gopls == nil then
    return {}
  end
  if _GO_NVIM_CFG == nil then
    return vim.notify('please setup go.nvim', vim.log.levels.WARN)
  end
  gopls.on_attach = on_attach
  if type(_GO_NVIM_CFG.lsp_on_attach) == 'function' then
    gopls.on_attach = _GO_NVIM_CFG.lsp_on_attach
  end
  if _GO_NVIM_CFG.lsp_on_client_start and type(_GO_NVIM_CFG.lsp_on_client_start) == 'function' then
    gopls.on_attach = function(client, bufnr)
      on_attach(client, bufnr)
      _GO_NVIM_CFG.lsp_on_client_start(client, bufnr)
    end
  end

  if _GO_NVIM_CFG.gopls_cmd then
    gopls.cmd = _GO_NVIM_CFG.gopls_cmd
  else
    gopls.cmd = { 'gopls' }
    require('go.install').install('gopls')
  end

  if _GO_NVIM_CFG.lsp_gofumpt then
    gopls.settings.gopls.gofumpt = true
  end

  if _GO_NVIM_CFG.gopls_remote_auto then
    table.insert(gopls.cmd, '-remote=auto')
  end

  if type(_GO_NVIM_CFG.lsp_cfg) == 'table' then
    return extend_config(gopls, _GO_NVIM_CFG.lsp_cfg)
  end
  return gopls
end

function M.setup()
  local goplscfg = M.config()
  local lspconfig = utils.load_plugin('nvim-lspconfig', 'lspconfig')
  if lspconfig == nil then
    vim.notify('failed to load lspconfig', vim.log.levels.WARN)
    return
  end

  local vim_version = vim.version().major * 100 + vim.version().minor * 10 + vim.version().patch

  if vim_version < 61 then
    vim.notify('LSP: go.nvim requires neovim 0.6.1 or later', vim.log.levels.WARN)
  end
  log(goplscfg)
  lspconfig.gopls.setup(goplscfg)
end

--[[
	FillStruct      = "fill_struct"
	UndeclaredName  = "undeclared_name"
	ExtractVariable = "extract_variable"
	ExtractFunction = "extract_function"
	ExtractMethod   = "extract_method"
valueSet = { "", "Empty", "QuickFix", "Refactor", "RefactorExtract", "RefactorInline", "RefactorRewrite", "Source", "SourceOrganizeImports", "quickfix", "refactor", "refactor.extract", "refactor.inline", "refactor.re
write", "source", "source.organizeImports" }
]]

-- action / fix to take
-- only this action   'refactor.rewrite' source.organizeImports
M.codeaction = function(action, only, hdlr)
  local params = vim.lsp.util.make_range_params()
  log(action, only)
  if only then
    params.context = { only = { only } }
  end
  local result = vim.lsp.buf_request_all(0, 'textDocument/codeAction', params, function(result)
    if not result or next(result) == nil then
      log('nil result')
      return
    end
    log('code action result', result)
    local c = M.client()
    for _, res in pairs(result) do
      for _, r in pairs(res.result or {}) do
        if r.edit and not vim.tbl_isempty(r.edit) then
          local re = vim.lsp.util.apply_workspace_edit(r.edit, c.offset_encoding)
          log('workspace edit', r, re)
        end
        if type(r.command) == 'table' then
          if type(r.command) == 'table' and r.command.arguments then
            for _, arg in pairs(r.command.arguments) do
              if action == nil or arg['Fix'] == action then
                vim.lsp.buf.execute_command(r.command)
                return
              end
            end
          end
        end
      end
    end
    if hdlr then
      hdlr(result)
    end
  end)
end

M.gopls_on_attach = on_attach
M.codelens_enabled = function()
  return codelens_enabled
end

local function request(method, params, handler)
  return vim.lsp.buf_request(0, method, params, handler)
end

local function request_sync(method, params, timeout_ms)
  return vim.lsp.buf_request_sync(0, method, params, timeout_ms)
end

function M.gen_return(lsp_result)
  if not lsp_result or not lsp_result.contents then
    return
  end
  local contents = vim.split(lsp_result.contents.value, '\n')
  local func
  for _, line in ipairs(contents) do
    if line:match('^func') then
      func = line
      break
    end
  end
  if not func then
    return
  end
  local ret_list, err = M.find_ret(func)
  if ret_list == nil or next(ret_list) == nil then
    return
  end
  local header = ret_list[1]
  for i = 2, #ret_list do
    header = header .. ', ' .. ret_list[i]
  end
  local current_line = vim.api.nvim_get_current_line()
  local ss, se = string.find(current_line, '%s+')
  local leading_space = ''
  if ss then
    leading_space = current_line:sub(ss, se)
  end
  header = leading_space .. header .. ' := ' .. vim.trim(current_line)

  local row, col = unpack(api.nvim_win_get_cursor(0))
  vim.api.nvim_buf_set_lines(0, row - 1, row, true, { header })
  vim.cmd('write')
  if err then
    require('go.iferr').run()
  end
  return header
end

local name_map = {
  error = 'err',
  int = 'i',
  int64 = 'i',
  uint = 'i',
  uint64 = 'i',
  float = 'f',
  float64 = 'f',
  string = 's',
  rune = 'r',
  bool = 'b',
  channel = 'ch',
  byte = 'b',
}

local function gen_name(types)
  local rets = {}
  local used = {}
  for _, t in pairs(types) do
    if name_map[t] then
      if not used[name_map[t]] then
        rets[#rets + 1] = name_map[t]
        used[name_map[t]] = 1
      else
        rets[#rets + 1] = name_map[t] .. tostring(used[name_map[t]])
        used[name_map[t]] = used[name_map[t]] + 1
      end
    else
      local f = t:sub(1, 1)
      if f == f:upper() then
        name_map[t] = f:lower() .. t:sub(2)
        table.insert(rets, name_map[t])
        used[name_map[t]] = (used[name_map[t]] or 0) + 1
      else
        name_map[t] = f
        table.insert(rets, name_map[t])
        used[name_map[t]] = (used[name_map[t]] or 0) + 1
      end
    end
  end
  log(rets)
  return rets
end

function M.find_ret(str)
  str = vim.trim(str)
  local pat = [[\v^func\s+%(\w|\.|\*|\)|\()+\(%(\w|\_s|[*\.\[\],{}<>-])*\)\s+]]
  local regex = vim.regex(pat)
  local start, endpos = regex:match_str(str)
  if start == nil then
    return
  end

  local ret = vim.trim(str:sub(endpos + 1))
  if ret == '' then
    return
  end
  pat = [[\v\(%(\w|\_s|[*\.\[\],{}<>-])*\)]]
  regex = vim.regex(pat)

  start, endpos = regex:match_str(ret)
  -- handle return type in bracket
  local retlist = {}
  if start ~= nil then
    ret = ret:sub(2, #ret - 1) -- remove ( and )
    local ret_types = vim.split(ret, ',%s*')
    local need_convert = true
    for _, t in pairs(ret_types) do
      t = vim.trim(t)
      local m = vim.split(t, '%s+')
      if #m > 1 then
        need_convert = false
      end
      table.insert(retlist, m[1])
    end
    if need_convert then
      retlist = gen_name(ret_types)
    end
  else
    retlist = gen_name({ ret })
  end
  local includes_err = vim.tbl_contains(retlist, 'err')
  return retlist, includes_err
end

function M.hover_returns()
  local util = require('vim.lsp.util')

  local current_line = vim.api.nvim_get_current_line()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  local pat = [[\w\+(]]
  local r = vim.regex(pat)
  local s, e = r:match_str(current_line)
  log(s, e)
  if s == nil then
    return
  end

  local params = util.make_position_params()
  params.position.character = e - 1
  log(params)
  request('textDocument/hover', params, function(err, result, ctx)
    if err ~= nil then
      log(err)
      return
    end
    if result == nil then
      return
    end
    M.gen_return(result)
  end)
end

function M.document_symbols(opts)
  opts = opts or {}

  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }
  params.query = opts.prompt or ''
  local symbols
  vim.lsp.for_each_buffer_client(bufnr, function(client, _, _bufnr)
    if client.name == 'gopls' then
      symbols =
        client.request_sync('textDocument/documentSymbol', params, opts.timeout or 1000, _bufnr)
      return symbols
    end
  end)
  return symbols
end

local change_type = {
  Created = 1,
  Changed = 2,
  Deleted = 3,
}

function M.watchFileChanged(fname, params)
  params = params or vim.lsp.util.make_workspace_params()
  fname = fname or vim.api.nvim_buf_get_name(0)
  -- \ 'method': 'workspace/didChangeWatchedFiles',
  params.changes = params.changes
    or {
      { uri = params.uri or vim.uri_from_fname(fname), type = params.type or change_type.Changed },
    }
  vim.lsp.buf_request(
    vim.api.nvim_get_current_buf(),
    'workspace/didChangeWatchedFiles',
    params,
    function(err, result, ctx)
      vim.defer_fn(function()
        -- log(err, result, ctx)
        if err then
          -- the request was send to all clients and some may not support
          log(
            'failed to workspace reloaded:'
              .. vim.inspect(err)
              .. vim.inspect(ctx)
              .. vim.inspect(result)
          )
        else
          vim.notify('workspace reloaded')
        end
      end, 200)
    end
  )
end

return M
