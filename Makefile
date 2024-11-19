PACKER_DIR = ~/.local/share/nvim/site/pack/vendor/start

test:
	nvim --headless --noplugin -u lua/tests/minimal.vim -c "PlenaryBustedDirectory lua/tests/ {minimal_init = 'lua/tests/minimal.vim'}"
localfailed: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.vim -c "PlenaryBustedDirectory lua/tests/failed {minimal_init = 'lua/tests/init.vim'}"
localtest: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.vim -c "PlenaryBustedDirectory lua/tests/ {minimal_init = 'lua/tests/init.vim'}"
localtestfile: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.vim -c "PlenaryBustedFile lua/tests/go_test_spec.lua"
lint:
	luacheck lua/go

localtestsetup:
	@mkdir -p $(PACKER_DIR)
	@mkdir -p ~/tmp

	@test -d $(PACKER_DIR)/plenary.nvim ||\
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PACKER_DIR)/plenary.nvim

	@test -d $(PACKER_DIR)/nvim-lspconfig ||\
		git clone --depth 1 https://github.com/neovim/nvim-lspconfig $(PACKER_DIR)/nvim-lspconfig

	@test -d $(PACKER_DIR)/guihua ||\
		git clone --depth 1 https://github.com/ray-x/guihua.lua $(PACKER_DIR)/guihua

	@test -d $(PACKER_DIR)/nvim-treesitter ||\
		git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter $(PACKER_DIR)/nvim-treesitter

	@test -d $(PACKER_DIR)/go.nvim || ln -s ${shell pwd} $(PACKER_DIR)

	nvim --headless -u lua/tests/minimal.vim -i NONE -c "TSUpdateSync go" -c "q"
