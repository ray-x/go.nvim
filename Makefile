test:
	nvim --headless --noplugin -u lua/tests/minimal.vim -c "PlenaryBustedDirectory lua/tests/ {minimal_init = 'lua/tests/minimal.vim'}"
