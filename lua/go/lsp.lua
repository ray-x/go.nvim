local vim, api = vim, vim.api
local utils = require("go.utils")
local log = utils.log
local diagnostic_map = function(bufnr)
  local opts = { noremap = true, silent = true }
  api.nvim_buf_set_keymap(bufnr, "n", "]O", ":lua vim.lsp.diagnostic.set_loclist()<CR>", opts)
end
local codelens_enabled = false
local on_attach = function(client, bufnr)
  local function buf_set_keymap(...)
    vim.api.nvim_buf_set_keymap(bufnr, ...)
  end
  local uri = vim.uri_from_bufnr(bufnr)
  if uri == "file://" or uri == "file:///" or #uri < 11 then
    return { error = "invalid file", result = nil }
  end
  diagnostic_map(bufnr)
  -- add highlight for Lspxxx

  api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

  local opts = { noremap = true, silent = true }
  if _GO_NVIM_CFG.lsp_document_formatting == false then
    -- client.resolved_capabilities.document_formatting = false
    client.server_capabilities.documentFormattingProvider = false
  end

  if _GO_NVIM_CFG.lsp_codelens then
    -- codelens_enabled = client.resolved_capabilities["code_lens"]
    codelens_enabled = client.server_capabilities.codeLensProvider
    if not codelens_enabled then
      vim.notify("codelens not support by your gopls", vim.lsp.log_levels.WARN)
    end
  end
  if _GO_NVIM_CFG.lsp_keymaps == true then
    buf_set_keymap("n", "gD", ":lua vim.lsp.buf.formatting()<CR>", opts)
    buf_set_keymap("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts)
    buf_set_keymap("n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
    buf_set_keymap("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
    buf_set_keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
    buf_set_keymap("n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
    buf_set_keymap("n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
    buf_set_keymap("n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
    buf_set_keymap("n", "<space>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
    buf_set_keymap("n", "<space>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
    buf_set_keymap("n", "<space>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
    buf_set_keymap("n", "<space>ca", '<cmd>lua require"go.lsp".telescope_code_actions()<CR>', opts)
    buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
    buf_set_keymap("n", "<space>e", "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", opts)
    buf_set_keymap("n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", opts)
    buf_set_keymap("n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", opts)
    buf_set_keymap("n", "<space>q", "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", opts)

    if client.server_capabilities.documentFormattingProvider then
      buf_set_keymap("n", "<space>ff", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
    end
    if client.resolved_capabilities.document_formatting then
      buf_set_keymap("n", "<space>ff", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
    end
  elseif type(_GO_NVIM_CFG.lsp_keymaps) == "function" then
    _GO_NVIM_CFG.lsp_keymaps(bufnr)
  end
end

local gopls = require("go.gopls").setups()

local extend_config = function(opts)
  opts = opts or {}
  if next(opts) == nil or gopls == nil then
    return gopls
  end
  for key, value in pairs(opts) do
    if type(gopls[key]) == "table" then
      for k, v in pairs(value) do
        gopls[key][k] = v
      end
    else
      gopls[key] = value
    end
  end
end

local M = {}

function M.client()
  local clients = vim.lsp.get_active_clients()
  for _, cl in pairs(clients) do
    if cl.name == "gopls" then
      return cl
    end
  end
end

function M.config()
  if gopls == nil then
    return
  end
  gopls.on_attach = on_attach
  if type(_GO_NVIM_CFG.lsp_on_attach) == "function" then
    gopls.on_attach = _GO_NVIM_CFG.lsp_on_attach
  end

  if _GO_NVIM_CFG.gopls_cmd then
    gopls.cmd = _GO_NVIM_CFG.gopls_cmd
  else
    gopls.cmd = { "gopls" }
    require("go.install").install("gopls")
  end

  if _GO_NVIM_CFG.lsp_gofumpt then
    gopls.settings.gopls.gofumpt = true
  end

  if _GO_NVIM_CFG.gopls_remote_auto then
    table.insert(gopls.cmd, "-remote=auto")
  end

  if type(_GO_NVIM_CFG.lsp_cfg) == "table" then
    extend_config(_GO_NVIM_CFG.lsp_cfg)
  end
  return gopls
end

function M.setup()
  local gopls = M.config()
  local lspconfig = utils.load_plugin("nvim-lspconfig", "lspconfig")
  if lspconfig == nil then
    vim.notify("failed to load lspconfig", vim.lsp.log_levels.WARN)
    return
  end
  lspconfig.gopls.setup(gopls)
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
M.codeaction = function(action, only, wait_ms)
  wait_ms = wait_ms or 1000
  local params = vim.lsp.util.make_range_params()
  log(action, only)
  if only then
    params.context = { only = { only } }
  end
  local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, wait_ms)
  if not result or next(result) == nil then
    log("nil result")
    return
  end
  log("code action result", result)
  local c = M.client()
  for _, res in pairs(result) do
    for _, r in pairs(res.result or {}) do
      if r.edit and not vim.tbl_isempty(r.edit) then
        local re = vim.lsp.util.apply_workspace_edit(r.edit, c.offset_encoding)
        log("workspace edit", r, re)
      end
      if type(r.command) == "table" then
        if type(r.command) == "table" and r.command.arguments then
          for _, arg in pairs(r.command.arguments) do
            if action == nil or arg["Fix"] == action then
              vim.lsp.buf.execute_command(r.command)
              return
            end
          end
        end
      end
    end
  end
end

function M.telescope_code_actions()
  local ok, _ = utils.load_plugin("telescope.nvim", "telescope.builtin")
  if ok then
    local themes = require("telescope.themes")
    local opts = themes.get_dropdown({
      winblend = 10,
      border = true,
      previewer = false,
      shorten_path = false,
    })
    require("telescope.builtin").lsp_code_actions(opts)
  else
    vim.lsp.buf.code_action()
  end
end

M.gopls_cfg = gopls
M.gopls_on_attach = on_attach
M.codelens_enabled = function()
  return codelens_enabled
end

return M
