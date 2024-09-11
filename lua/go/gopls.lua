local utils = require('go.utils')
local log = utils.log
local vfn = vim.fn

local M = {}
local cmds = {}
-- https://go.googlesource.com/tools/+/refs/heads/master/gopls/doc/commands.md

local gopls_cmds = {
  'gopls.add_dependency',
  'gopls.add_import',
  'gopls.add_telemetry_counters',
  'gopls.apply_fix',
  'gopls.change_signature',
  'gopls.check_upgrades',
  'gopls.diagnose_files',
  'gopls.edit_go_directive',
  'gopls.fetch_vulncheck_result',
  'gopls.gc_details',
  'gopls.generate',
  'gopls.go_get_package',
  'gopls.list_imports',
  'gopls.list_known_packages',
  'gopls.maybe_prompt_for_telemetry',
  'gopls.mem_stats',
  'gopls.regenerate_cgo',
  'gopls.remove_dependency',
  'gopls.reset_go_mod_diagnostics',
  'gopls.run_go_work_command',
  'gopls.run_govulncheck',
  'gopls.run_tests',
  'gopls.start_debugging',
  'gopls.start_profile',
  'gopls.stop_profile',
  'gopls.test',
  'gopls.tidy',
  'gopls.toggle_gc_details',
  'gopls.update_go_sum',
  'gopls.upgrade_dependency',
  'gopls.vendor',
  'gopls.views',
  'gopls.workspace_stats',
}

local gopls_with_result = {
  'gopls.gc_details',
  'gopls.list_known_packages',
  'gopls.list_imports',
}

local gopls_with_edit = {
  'gopls.add_dependency',
  'gopls.add_import',
  'gopls.check_upgrades',
  'gopls.change_signature',
}
local function check_for_error(msg)
  if msg ~= nil and type(msg[1]) == 'table' then
    for k, v in pairs(msg[1]) do
      if k == 'error' then
        log('LSP error:', v.message)
        vim.notify(vim.inspect(v.message), vim.log.levels.INFO)
        break
      end
    end
  end
end

local function apply_changes(cmd, args)
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local gopls
  for _, c in ipairs(clients) do
    if c.name == 'gopls' then
      gopls = c
      break
    end
  end
  if not gopls then
    vim.notify('gopls not found', vim.log.levels.INFO)
    return
  end
  log('applying changes', cmd, args)
  gopls.request('workspace/executeCommand', {
    command = cmd,
    arguments = args,
  }, function(_err, changes)
    if _err then
      vim.notify(vim.inspect(_err), vim.log.levels.INFO)
      log('error', _err)
    end
    if not changes or not changes.documentChanges then
      log('no resolved changes', changes)
      return
    end
    log('applying changes', changes)
    vim.lsp.util.apply_workspace_edit(changes, gopls.offset_encoding)
  end, bufnr)
end

for _, gopls_cmd in ipairs(gopls_cmds) do
  local gopls_cmd_name = string.sub(gopls_cmd, #'gopls.' + 1)
  cmds[gopls_cmd_name] = function(arg, callback)
    -- get gopls client

    local b = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients({ bufnr = b })
    local gopls
    for _, c in ipairs(clients) do
      if c.name == 'gopls' then
        gopls = c
        break
      end
    end
    if gopls == nil then
      vim.notify('gopls not found', vim.log.levels.INFO)
      return
    end
    local uri = vim.uri_from_bufnr(b)
    local arguments = { { URI = uri } }

    local ft = vim.bo.filetype
    if
      ft == 'gomod'
      or ft == 'gosum'
      or gopls_cmd_name == 'tidy'
      or gopls_cmd_name == 'update_go_sum'
    then
      arguments[1].URIs = { uri }
      arguments[1].URI = nil
    end
    arguments = { vim.tbl_extend('keep', arguments[1], arg or {}) }

    log(gopls_cmd_name, arguments)
    if vim.tbl_contains(gopls_with_result, gopls_cmd) then
      local resp = gopls.request_sync('workspace/executeCommand', {
        command = gopls_cmd,
        arguments = arguments,
      }, 2000, b)

      check_for_error(resp)
      log(resp)
      return resp
    end

    if vim.tbl_contains(gopls_with_edit, gopls_cmd) then
      apply_changes(gopls_cmd, arguments)
    else
      vim.schedule(function()
        -- it likely to be a edit command
        -- but execute_command may not working in the way gppls want
        local resp = gopls.request('workspace/executeCommand', {
          command = gopls_cmd,
          arguments = arguments,
        }, function(err, result)
          if err then
            log('error', err)
            vim.notify(vim.inspect(err), vim.log.levels.INFO)
            return
          end

          check_for_error(result)
          if callback then
            callback(result)
          end
        end, b)
      end)
    end
  end
end

M.cmds = cmds
M.import = function(path)
  cmds.add_import({
    ImportPath = path,
  }, require('go.format').gofmt)
end

M.change_signature = function()
  local params = vim.lsp.util.make_range_params()

  if params.range['start'].character == params.range['end'].character then
    log('please select a function signature', params.range)
    -- return
  end
  local lsp_params = {
    RemoveParameter = {
      uri = params.textDocument.uri,
      range = params.range,
    },
    ResolveEdits = true,
  }

  log(lsp_params)
  cmds.change_signature(lsp_params)
end

M.list_imports = function(path)
  path = path or vim.fn.expand('%:p')
  local resp = cmds.list_imports({
    URI = path,
  })
  local result = {}
  for _, v in pairs(resp) do
    if v.result then
      for k, val in pairs(v.result) do
        result[k] = {}
        for _, imp in ipairs(val) do
          if imp.Name and imp.Name ~= '' then
            table.insert(result[k], imp.Name .. ':' .. imp.Path)
          else
            table.insert(result[k], imp.Path)
          end
        end
      end
    end
  end
  return result, resp
end

M.list_pkgs = function()
  local resp = cmds.list_known_packages() or {}

  local pkgs = {}
  for _, response in pairs(resp) do
    if response.result ~= nil then
      pkgs = response.result.Packages
      break
    end
  end
  return pkgs
end

M.tidy = function()
  cmds.tidy()
end

-- check_for_upgrades({Modules = {'package'}})
function M.version()
  local cache_dir = vfn.stdpath('cache')
  local path = string.format('%s%sversion.txt', cache_dir, utils.sep())
  local cfg = _GO_NVIM_CFG or {}
  local gopls = cfg.gopls_cmd or { 'gopls' }

  if vfn.executable(gopls[1]) == 0 then
    vim.notify('gopls not found', vim.log.levels.WARN)
    return
  end
  vfn.jobstart({ gopls[1], 'version' }, {
    on_stdout = function(_, data, _)
      local msg = ''
      if type(data) == 'table' and #data > 0 then
        data = table.concat(data, ' ')
      end
      if #data > 1 then
        msg = msg .. data
      end
      log(msg)

      local version = string.match(msg, '%s+v([%d%.]+)%s+')
      if version == nil then
        log(version, msg)
        return
      end

      local f = io.open(path, 'w+')
      if f == nil then
        return
      end
      f:write(version)
      f:close()
      log(version)
    end,
  })

  local f = io.open(path, 'r')
  if f == nil then
    local version_cmd = gopls[1] .. ' version'
    return vfn.system(version_cmd):match('%s+v([%d%.]+)%s+')
  end
  local version = f:read('*l')
  f:close()
  log(version)
  return version
end

local get_current_gomod = function()
  local file = io.open('go.mod', 'r')
  if file == nil then
    return nil
  end

  local first_line = file:read()
  local mod_name = first_line:gsub('module ', '')
  file:close()
  return mod_name
end

local function get_build_flags()
  local get_build_tags = require('go.gotest').get_build_tags
  local tags = get_build_tags()
  if tags then
    log(vim.inspect(tags))
    return tags
  else
    return nil
  end
end
local range_format = 'textDocument/rangeFormatting'
local formatting = 'textDocument/formatting'
M.setups = function()
  local update_in_insert = _GO_NVIM_CFG.diagnostic and _GO_NVIM_CFG.diagnostic.update_in_insert
    or false
  local diagTrigger = update_in_insert and 'Edit' or 'Save'
  local diagDelay = update_in_insert and '1s' or '250ms'
  local setups = {
    capabilities = {
      textDocument = {
        completion = {
          completionItem = {
            commitCharactersSupport = true,
            deprecatedSupport = true,
            documentationFormat = { 'markdown', 'plaintext' },
            preselectSupport = true,
            insertReplaceSupport = true,
            labelDetailsSupport = true,
            snippetSupport = vim.snippet and true or false,
            resolveSupport = {
              properties = {
                'edit',
                'documentation',
                'details',
                'additionalTextEdits',
              },
            },
          },
          completionList = {
            itemDefaults = {
              'editRange',
              'insertTextFormat',
              'insertTextMode',
              'data',
            },
          },
          contextSupport = true,
          dynamicRegistration = true,
        },
      },
    },
    filetypes = { 'go', 'gomod', 'gosum', 'gotmpl', 'gohtmltmpl', 'gotexttmpl' },
    message_level = vim.lsp.protocol.MessageType.Error,
    cmd = {
      'gopls', -- share the gopls instance if there is one already
      '-remote.debug=:0',
    },
    root_dir = function(fname)
      local has_lsp, lspconfig = pcall(require, 'lspconfig')
      if has_lsp then
        local util = lspconfig.util
        return util.root_pattern('go.work', 'go.mod', '.git')(fname) or util.path.dirname(fname)
      end
    end,
    flags = { allow_incremental_sync = true, debounce_text_changes = 500 },
    settings = {
      gopls = {
        -- more settings: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
        -- https://github.com/golang/tools/blob/master/gopls/doc/analyzers.md
        -- not supported
        analyses = {
          -- check analyzers for default values
          -- leeave most of them to default
          -- shadow = true,
          -- unusedvariable = true,
          useany = true,
        },
        codelenses = {
          generate = true, -- show the `go generate` lens.
          gc_details = true, -- Show a code lens toggling the display of gc's choices.
          test = true,
          tidy = true,
          vendor = true,
          regenerate_cgo = true,
          upgrade_dependency = true,
        },
        hints = vim.empty_dict(),
        usePlaceholders = true,
        completeUnimported = true,
        staticcheck = true,
        matcher = 'Fuzzy',
        -- check if diagnostic update_in_insert is set
        diagnosticsDelay = diagDelay,
        diagnosticsTrigger = diagTrigger,
        symbolMatcher = 'FastFuzzy',
        semanticTokens = true,
        noSemanticString = true, -- disable semantic string tokens so we can use treesitter highlight injection
        vulncheck = 'Imports',
        ['local'] = get_current_gomod(),
        gofumpt = _GO_NVIM_CFG.lsp_gofumpt or false, -- true|false, -- turn on for new repos, gofmpt is good but also create code turmoils
        buildFlags = { '-tags', 'integration' },
      },
    },
    -- NOTE: it is important to add handler to formatting handlers
    -- the async formatter will call these handlers when gopls respond
    -- without these handlers, the file will not be saved
    handlers = {
      [range_format] = function(...)
        vim.lsp.handlers[range_format](...)
        if vfn.getbufinfo('%')[1].changed == 1 then
          vim.cmd('noautocmd write')
        end
      end,
      [formatting] = function(...)
        vim.lsp.handlers[formatting](...)
        if vfn.getbufinfo('%')[1].changed == 1 then
          vim.cmd('noautocmd write')
        end
      end,
    },
  }

  local tags = get_build_flags()
  if tags and tags ~= '' then
    setups.settings.gopls.buildFlags = { tags }
  end

  if _GO_NVIM_CFG.lsp_inlay_hints.enable and vim.fn.has('nvim-0.10') then
    setups.settings.gopls = vim.tbl_deep_extend('keep', setups.settings.gopls, {
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    })
  end
  return setups
end

return M

--[[
as of 2024-03-01
     codeActionProvider = {
        codeActionKinds = { "quickfix", "refactor.extract", "refactor.inline", "refactor.rewrite", "source.fixAll", "source.organizeImports" },
        resolveProvider = true
      },
      executeCommandProvider = {
        commands = { "gopls.add_dependency", "gopls.add_import", "gopls.add_telemetry_counters", "gopls.apply_fix", "gopls.change_signature", "gopls.check_upgrades", "gopls.diagnose_files", "gopls.edit_go_directive", "gopls.fetch_vulncheck_result", "gopls.
gc_details", "gopls.generate", "gopls.go_get_package", "gopls.list_imports", "gopls.list_known_packages", "gopls.maybe_prompt_for_telemetry", "gopls.mem_stats", "gopls.regenerate_cgo", "gopls.remove_dependency", "gopls.reset_go_mod_diagnostics", "gopls.run
_go_work_command", "gopls.run_govulncheck", "gopls.run_tests", "gopls.start_debugging", "gopls.start_profile", "gopls.stop_profile", "gopls.test", "gopls.tidy", "gopls.toggle_gc_details", "gopls.update_go_sum", "gopls.upgrade_dependency", "gopls.vendor", "
gopls.views", "gopls.workspace_stats" }
      },
]]
--
