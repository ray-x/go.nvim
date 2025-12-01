-- NOTE: this setup should work for both Mac and Linux
-- change the slash to backslash in PATH for Windows
vim.cmd([[set runtimepath=$VIMRUNTIME]])
local tmpdir = vim.loop.os_tmpdir() .. '/nvim'
local packpath = tmpdir .. '/lazy'
vim.cmd([[set packpath=]] .. packpath)
-- print(packpath)

local package_root = packpath
local plugin_folder = function()
  local host = os.getenv('HOST_NAME')
  if host and (host:find('Ray') or host:find('ray')) then
    return [[~/github/ray-x]] -- vim.fn.expand("$HOME") .. '/github/'
  else
    return ''
  end
end

local lazypath = package_root .. '/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
local function load_plugins()
  return {
    {
      'nvim-treesitter/nvim-treesitter',
      lazy = false,
      branch = 'main',
      build = ':TSUpdate',
      config = function()
        require('nvim-treesitter').setup({
          -- Directory to install parsers and queries to
          install_dir = vim.fn.stdpath('data') .. '/site',
        })
        require('nvim-treesitter').install({ 'go' }):wait(3000)
      end,
    },
    { 'neovim/nvim-lspconfig' },
    {
      'ray-x/go.nvim',
      dev = (plugin_folder() ~= ''),
      ft = { 'go', 'gomod', 'gosum', 'gotmpl', 'gohtmltmpl', 'gotexttmpl' },
      dependencies = {
        'mfussenegger/nvim-dap', -- Debug Adapter Protocol
        'rcarriga/nvim-dap-ui',
        'theHamsta/nvim-dap-virtual-text',
        'ray-x/guihua.lua',
      },
      config = true,
      opts = {
        verbose = true,
        -- log_path = '~/tmp/gonvim.log',
        lsp_cfg = true,
        goimports = 'gopls',
        gofmt = 'gopls',
        max_line_len = 120,
      },
    },
  }
end

local opts = {
  root = package_root, -- directory where plugins will be installed
  default = { lazy = true },
  dev = {
    -- directory where you store your local plugin projects
    path = plugin_folder(),
  },
}

require('lazy').setup(load_plugins(), opts)

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'go' },
  callback = function()
    vim.treesitter.start()
  end,
})
