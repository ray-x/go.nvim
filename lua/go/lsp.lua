local vim, api = vim, vim.api
local utils = require('go.utils')
local log = utils.log
local trace = utils.trace
local diagnostic_map = function(bufnr)
  local opts = { noremap = true, silent = true }
  api.nvim_buf_set_keymap(bufnr, 'n', ']O', ':lua vim.diagnostic.setloclist()<CR>', opts)
end

if vim.fn.has('nvim-0.8.3') ~= 1 then
  return vim.notify(
    'Please upgrade to neovim 0.8.3 or above',
    vim.log.levels.ERROR,
    { title = 'Error' }
  )
end

local codelens_enabled = false

local on_attach = function(client, bufnr)
  log('go.nvim on_on_attach', bufnr)
  trace('go.nvim gopls info', client)
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
    vim.lsp.codelens.refresh()
  end
  local keymaps
  if _GO_NVIM_CFG.lsp_keymaps == true then
    log('go.nvim lsp_keymaps', bufnr)
    keymaps = {
      { key = 'gd', func = vim.lsp.buf.definition, desc = 'goto definition' },
      { key = 'K', func = vim.lsp.buf.hover, desc = 'hover' },
      { key = 'gi', func = vim.lsp.buf.implementation, desc = 'goto implementation' },
      { key = '<C-k>', func = vim.lsp.buf.signature_help, desc = 'signature help' },
      { key = '<space>wa', func = vim.lsp.buf.add_workspace_folder, desc = 'add workspace' },
      {
        key = '<space>wr',
        func = vim.lsp.buf.remove_workspace_folder,
        desc = 'remove workspace',
      },
      {
        key = '<space>wl',
        func = function()
          print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end,
        desc = 'list workspace',
      },
      { key = 'gD', func = vim.lsp.buf.type_definition, desc = 'goto type definition' },
      { key = '<space>rn', func = require('go.rename').run, desc = 'rename' },
      { key = '<space>ca', func = require('go.codeaction').run_code_action, desc = 'code action' },
      {
        mode = 'v',
        key = '<space>ca',
        func = require('go.codeaction').run_range_code_action,
        desc = 'range code action',
      },
      { key = 'gr', func = vim.lsp.buf.references, desc = 'references' },
      { key = '<space>e', func = vim.diagnostic.open_float, desc = 'diagnostic' },
      { key = '[d', func = vim.diagnostic.goto_prev, desc = 'diagnostic prev' },
      { key = ']d', func = vim.diagnostic.goto_next, desc = 'diagnostic next' },
      { key = '<space>q', func = vim.diagnostic.setloclist, desc = 'diagnostic loclist' },
    }

    if client.server_capabilities.documentFormattingProvider and keymaps then
      table.insert(keymaps, {
        key = '<space>ff',
        func = function()
          vim.lsp.buf.format({ async = _GO_NVIM_CFG.lsp_format_async })
        end,
        desc = 'format',
      })
    end
  elseif type(_GO_NVIM_CFG.lsp_keymaps) == 'function' then
    _GO_NVIM_CFG.lsp_keymaps(bufnr)
  end
  if keymaps then
    opts.buffer = bufnr
    for _, keymap in pairs(keymaps) do
      if keymap.key == nil or keymap.func == nil then
        vim.notify('invalid keymap' .. vim.inspect(keymap), vim.log.levels.WARN)
        return
      end
      vim.keymap.set(keymap.mode or 'n', keymap.key, keymap.func, opts)
    end
  end
  if client.name == 'gopls' then
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
        vim.notify(
          'gopls setup for '
            .. key
            .. ' type:'
            .. type(gopls[key])
            .. ' is not '
            .. type(value)
            .. vim.inspect(value)
        )
      end
      gopls[key] = value
    end
  end
  return gopls
end

local M = {}

function M.client()
  local clients = vim.lsp.get_active_clients({
    bufnr = vim.api.nvim_get_current_buf(),
    name = 'gopls',
  }) or {}
  return clients[1]
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

  if vim_version < 81 then
    vim.notify('LSP: go.nvim requires neovim 0.8.1 or later', vim.log.levels.WARN)
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
-- only gopls
M.codeaction = function(gopls_cmd, only, hdlr)
  hdlr = hdlr or function() end
  local params = vim.lsp.util.make_range_params()
  if not gopls_cmd:find('gopls') then
    gopls_cmd = 'gopls.' .. gopls_cmd
  end
  if only then
    params.context = { only = { only } }
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local gopls = M.client()
  if gopls == nil then
    log('gopls not found')
    return hdlr()
  end

  local ctx = { bufnr = bufnr, client_id = gopls.id }

  local function apply_action(action)
    log('apply_action', action, ctx)
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, gopls.offset_encoding)
    end
    if action.command then
      local command = type(action.command) == 'table' and action.command or action
      local fn = gopls.commands[command.command] or vim.lsp.commands[command.command]
      ctx.client_id = gopls.id
      if fn then
        local enriched_ctx = vim.deepcopy(ctx)
        fn(command, enriched_ctx)
        hdlr()
      else
        gopls.request('workspace/executeCommand', {
          command = command.command,
          arguments = command.arguments,
          workDoneToken = command.workDoneToken,
        }, function(_err, r)
          if _err then
            log('error', _err)
          end
          log('workspace/executeCommand', command.command, r)
          hdlr()
        end, bufnr)
      end
    else
      hdlr()
    end
  end
  local function fallback_imports()
    if only == 'source.organizeImports' then
      require('go.format').goimports('goimports')
    end
  end
  local function ca_hdlr(err, result, hdl_ctx, config)
    trace('codeaction', err, result, hdl_ctx, config)
    if err then
      return log('error', err)
    end
    log('gocodeaction', err, result)
    if not result or next(result) == nil then
      log('nil result for codeaction with parameters', gopls_cmd, only, bufnr, params)
      return hdlr()
    end
    local actions = {}
    for _, res in pairs(result) do
      local act_cmd = res.data and res.data.command or ''
      if res.edit or act_cmd == gopls_cmd then
        table.insert(actions, res)
      end
    end
    if #actions == 0 then
      log('no code actions available')
      vim.notify('No code actions available, fallback goimports', vim.log.levels.INFO)
      -- fallback to gofmt/goimports
      fallback_imports()
      return hdlr()
    end

    local action = actions[1]
    -- resolve
    gopls.request('codeAction/resolve', action, function(_err, resolved_acrtion, ctx, config)
      log('codeAction/resolve', _err, resolved_acrtion, ctx, config)
      if _err then
        log('error', _err)
        if action.command then
          apply_action(action)
        else
          log('resolved', resolved_acrtion)
          vim.notify('No code actions can be resolve fallback goimports', vim.log.levels.INFO)
          fallback_imports()
          hdlr()
        end
      else
        apply_action(resolved_acrtion)
      end
    end, bufnr)
  end

  gopls.request('textDocument/codeAction', params, ca_hdlr, bufnr)
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
  local c = M.client()
  if c ~= nil then
    return c.request_sync(
      'textDocument/documentSymbol',
      params,
      opts.timeout or 1000,
      vim.api.nvim_get_current_buf()
    )
  end
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
