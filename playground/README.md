A sample go project with minium config for go.nvim

Start with (may need to restart nvim after the first time)

```shell
cd sampleApp
nvim -u ../init.lua main.go

```

To start debugging, run the following commands
```vim
:10
:GoBreakToggle
:GoDebug
```

To unit test, run the following commands
```vim
:pkg/findAllSubStr_test.go
:10
:GoTestFunc
```
