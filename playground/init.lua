vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

local package_root = "/tmp/nvim/site/pack"
local install_path = package_root .. "/packer/start/packer.nvim"

local function load_plugins()
  require("packer").startup({
    function(use)
      use({ "wbthomason/packer.nvim" })
      use({ "ray-x/guihua.lua" })
      use({
        "nvim-treesitter/nvim-treesitter",
        config = function()
          require("nvim-treesitter.configs").setup({
            ensure_installed = { "python", "go", "javascript" },
            highlight = { enable = true },
          })
        end,
        run = ":TSUpdate",
      })
      use({ "neovim/nvim-lspconfig" })
      use({
        "ray-x/go.nvim",
        config = function()
          require("go").setup({
            -- verbose = false,
            run_in_floaterm = true,
          })
        end,
      })
    end,
    config = {
      package_root = package_root,
      compile_path = install_path .. "/plugin/packer_compiled.lua",
    },
  })
end

if vim.fn.isdirectory(install_path) == 0 then
  vim.fn.system({
    "git",
    "clone",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  })
  load_plugins()
  require("packer").sync()
else
  load_plugins()
end

vim.cmd("colorscheme murphy")
