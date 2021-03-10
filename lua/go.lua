-- some of commands extracted from gopher.vim

local go = {}

function go.setup(cfg)
  vim.g.go_nvim_goimport = cfg.goimport or 'gofumports' -- g:go_nvim_goimport
  vim.g.go_nvim_gofmt = cfg.gofmt or 'gofumpt' --g:go_nvim_gofmt,
  vim.g.go_nvim_max_len = cfg.max_len or 100 -- g:go_nvim_max_len
  vim.g.go_nvim_transform = cfg.transform or false -- vim.g.go_nvim_tag_transfer  check gomodifytags for details
  vim.g.go_nvim_test_dir = cfg.test_dir or '' -- default to current dir. g:go_nvim_tests_dir  check gotests for details
  vim.g.go_nvim_comment_placeholder = cfg.comment_placeholder or '   '   -- vim.g.go_nvim_comment_placeholder your cool placeholder e.g. ﳑ       
  vim.g.go_nvim_verbose = cfg.verbose or false  -- output loginf in messages


  vim.cmd('command Gofmt lua require("go.format").gofmt()')
  vim.cmd('command Goimport lua require("go.format").goimport()')

  vim.cmd([[command GoBuild :setl makeprg=go\ build | :make]])
  vim.cmd([[command GoGenerate  :setl makeprg=go\ generate | :make]])
  vim.cmd([[command GoRun       :setl makeprg=go\ run | :make]])
  vim.cmd([[command GoTestFunc  :make -run ..]])

  vim.cmd([[command GoTest :compiler gotest | :make]])
  vim.cmd([[command GoTestCompile  setl makeprg=go\ build | :make]])
  vim.cmd([[command GoTest setl makeprg=go\ build | :make]])


  vim.cmd([[command GoAddTest lua require("go.gotests").fun_test()]])
  vim.cmd([[command GoAddExpTest lua require("go.gotests").exported_test()]])
  vim.cmd([[command GoAddAllTest lua require("go.gotests").all_test()]])

  vim.cmd([[command! -nargs=* GoAddTag lua require("go.tags").add(<f-args>)]])
  vim.cmd([[command! -nargs=* GoRmTag lua require("go.tags").rm(<f-args>)]])
  vim.cmd([[command           GoClearTag lua require("go.tags").clear()]])

  vim.cmd([[command GoLint :compiler golangci-lint | :make]])

end
return go
