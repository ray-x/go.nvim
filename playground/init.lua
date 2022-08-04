vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

local package_root = '/tmp/nvim/site/pack'
local install_path = package_root .. '/packer/start/packer.nvim'
local plugin_folder = function()
  local host = os.getenv('HOST_NAME')
  if host and (host:find('Ray') or host:find('ray')) then
    return [[~/github/]] -- vim.fn.expand("$HOME") .. '/github/'
  else
    return ''
  end
end
local function load_plugins()
  require('packer').startup({
    function(use)
      use({ 'wbthomason/packer.nvim' })
      use({
        'nvim-treesitter/nvim-treesitter',
        config = function()
          require('nvim-treesitter.configs').setup({
            ensure_installed = { 'go' },
            highlight = { enable = true },
          })
        end,
        run = ':TSUpdate',
      })
      use({ 'neovim/nvim-lspconfig' })
      use({
        plugin_folder() .. 'ray-x/go.nvim',
        requires = {
          'mfussenegger/nvim-dap', -- Debug Adapter Protocol
          'rcarriga/nvim-dap-ui',
          'theHamsta/nvim-dap-virtual-text',
          'ray-x/guihua.lua',
        },
        config = function()
          require('go').setup({
            verbose = true,
            goimport = 'gopls',
            lsp_cfg = {
              handlers = {
                ['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'double' }),
                ['textDocument/signatureHelp'] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = 'round' }),
              },
            }, -- false: do nothing
            run_in_floaterm = true,
          })
        end,
      })
    end,
    config = {
      package_root = package_root,
      compile_path = install_path .. '/plugin/packer_compiled.lua',
    },
  })
end

if vim.fn.isdirectory(install_path) == 0 then
  vim.fn.system({
    'git',
    'clone',
    'https://github.com/wbthomason/packer.nvim',
    install_path,
  })
  load_plugins()
  require('packer').sync()
else
  load_plugins()
end

vim.cmd('colorscheme murphy')
