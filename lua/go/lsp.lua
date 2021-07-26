local vim, api = vim, vim.api
local lsp = require("vim.lsp")

local diagnostic_map = function(bufnr)
  local opts = {noremap = true, silent = true}
  api.nvim_buf_set_keymap(bufnr, "n", "]O", ":lua vim.lsp.diagnostic.set_loclist()<CR>", opts)
end

local on_attach = function(client, bufnr)
  if _GO_NVIM_CFG.lsp_on_attach then
    if type(_GO_NVIM_CFG.lsp_on_attach) == "function" then
      _GO_NVIM_CFG.lsp_on_attach(client, bufnr)
      return
    end
  end
  local function buf_set_keymap(...)
    vim.api.nvim_buf_set_keymap(bufnr, ...)
  end
  local function buf_set_option(...)
    vim.api.nvim_buf_set_option(bufnr, ...)
  end
  local uri = vim.uri_from_bufnr(bufnr)
  if uri == "file://" or uri == "file:///" or #uri < 11 then
    return {error = "invalid file", result = nil}
  end
  diagnostic_map(bufnr)
  -- add highlight for Lspxxx

  api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

  local opts = {noremap = true, silent = true}

  buf_set_keymap('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wl',
                 '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
  buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
  buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
  buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
  buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)

  buf_set_keymap("n", "<space>ff", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)

end

local gopls = {
  -- capabilities = cap,
  filetypes = {"go", "gomod"},
  message_level = vim.lsp.protocol.MessageType.Error,
  cmd = {
    "gopls", -- share the gopls instance if there is one already
    "-remote=auto", --[[ debug options ]] --
    "-remote.debug=:0"
  },

  flags = {allow_incremental_sync = true, debounce_text_changes = 500},
  settings = {
    gopls = {
      -- more settings: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
      -- flags = {allow_incremental_sync = true, debounce_text_changes = 500},
      -- not supported
      analyses = {unusedparams = true, unreachable = false},
      codelenses = {
        generate = true, -- show the `go generate` lens.
        gc_details = true --  // Show a code lens toggling the display of gc's choices.
      },
      usePlaceholders = true,
      completeUnimported = true,
      staticcheck = true,
      matcher = "fuzzy",
      experimentalDiagnosticsDelay = "500ms",
      -- diagnosticsDelay = "500ms",
      -- experimentalWatchedFileDelay = "100ms",
      symbolMatcher = "fuzzy",
      gofumpt = false, -- true, -- turn on for new repos, gofmpt is good but also create code turmoils
      buildFlags = {"-tags", "integration"}
      -- buildFlags = {"-tags", "functional"}
    }
  }
}

if _GO_NVIM_CFG.lsp_on_attach then
  if _GO_NVIM_CFG.lsp_on_attach == true then
    gopls.on_attach = on_attach
  else
    gopls.on_attach = _GO_NVIM_CFG.lsp_on_attach
  end
else
  print("gopls on_attach not set")
end

if _GO_NVIM_CFG.gopls_cmd then
  gopls.cmd = _GO_NVIM_CFG.gopls_cmd
end

if _GO_NVIM_CFG.lsp_gofumpt then
  gopls.settings.gopls.gofumpt = true
end
require'lspconfig'.gopls.setup(gopls)
