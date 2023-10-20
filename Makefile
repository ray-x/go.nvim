test:
	nvim --headless --noplugin -u lua/tests/minimal.vim -c "PlenaryBustedDirectory lua/tests/ {minimal_init = 'lua/tests/minimal.vim'}"
localfailed:
	nvim --headless --noplugin -u lua/tests/init.vim -c "PlenaryBustedDirectory lua/tests/failed {minimal_init = 'lua/tests/init.vim'}"
localtest:
	nvim --headless --noplugin -u lua/tests/init.vim -c "PlenaryBustedDirectory lua/tests/ {minimal_init = 'lua/tests/init.vim'}"
localtestfile:
	nvim --headless --noplugin -u lua/tests/init.vim -c "PlenaryBustedFile lua/tests/go_comment_spec.lua"
lint:
	luacheck lua/go
