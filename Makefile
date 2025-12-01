PACKER_DIR = ~/.local/share/nvim/site/pack/vendor/start

test:
	nvim --headless --noplugin -u lua/tests/minimal.lua -c "PlenaryBustedDirectory lua/tests/ {minimal_init = 'lua/tests/minimal.lua'}"
localfailed: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.lua -c "PlenaryBustedDirectory lua/tests/failed {minimal_init = 'lua/tests/init.lua'}"
localtest: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.lua -c "PlenaryBustedDirectory lua/tests/ {minimal_init = 'lua/tests/init.lua'}"
localtestfile: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.lua -c "PlenaryBustedFile lua/tests/go_test_spec.lua"
localtestts: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.lua -c "PlenaryBustedFile lua/tests/go_ts_node_spec.lua"
localtesttag: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.lua -c "PlenaryBustedFile lua/tests/go_tags_spec.lua"
localtestmod: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.lua -c "PlenaryBustedFile lua/tests/go_module_spec.lua"
localtestfix: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.lua -c "PlenaryBustedFile lua/tests/go_fixplurals_spec.lua"

localtestgoplsfill: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.lua -c "PlenaryBustedFile lua/tests/go_fillstruct_spec.lua"
localtestgoplsimport: localtestsetup
	nvim --headless --noplugin -u lua/tests/init.lua -c "PlenaryBustedFile lua/tests/go_gopls_imports_spec.lua"
lint:
	luacheck lua/go
clean:
	rm -rf $(PACKER_DIR)

localtestsetup:
	@mkdir -p $(PACKER_DIR)
	@mkdir -p ~/tmp

	@test -d $(PACKER_DIR)/plenary.nvim ||\
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PACKER_DIR)/plenary.nvim

	@test -d $(PACKER_DIR)/nvim-lspconfig ||\
		git clone --depth 1 https://github.com/neovim/nvim-lspconfig $(PACKER_DIR)/nvim-lspconfig

	@test -d $(PACKER_DIR)/guihua.lua ||\
		git clone --depth 1 https://github.com/ray-x/guihua.lua $(PACKER_DIR)/guihua.lua

	@test -d $(PACKER_DIR)/nvim-treesitter ||\
		git clone --depth 1 -b main https://github.com/nvim-treesitter/nvim-treesitter $(PACKER_DIR)/nvim-treesitter

	@test -d $(PACKER_DIR)/go.nvim || ln -s ${shell pwd} $(PACKER_DIR)

	nvim --headless -u lua/tests/minimal.vim -i NONE -c "TSUpdate go" -c "q"
