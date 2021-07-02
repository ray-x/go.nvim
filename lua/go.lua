-- some of commands extracted from gopher.vim
local go = {}

function go.setup(cfg)
  cfg = cfg or {}
  vim.g.go_nvim_goimport = cfg.goimport or 'gofumports' -- g:go_nvim_goimport
  vim.g.go_nvim_gofmt = cfg.gofmt or 'gofumpt' -- g:go_nvim_gofmt,
  vim.g.go_nvim_max_len = cfg.max_len or 120 -- g:go_nvim_max_len
  vim.g.go_nvim_transform = cfg.transform or false -- vim.g.go_nvim_tag_transfer  check gomodifytags for details
  vim.g.go_nvim_test_dir = cfg.test_dir or '' -- default to current dir. g:go_nvim_tests_dir  check gotests for details
  vim.g.go_nvim_comment_placeholder = cfg.comment_placeholder or '   ' -- vim.g.go_nvim_comment_placeholder your cool placeholder e.g. ﳑ       
  vim.g.go_nvim_verbose = cfg.verbose or false -- output loginf in messages
  vim.cmd("command! Gmake silent lua require'go.asyncmake'.make()")

  vim.cmd('command! Gofmt lua require("go.format").gofmt()')
  vim.cmd('command! Goimport lua require("go.format").goimport()')


  local cmds = vim.api.nvim_get_commands({})

  if cmds["GoBuild"]       == nil then vim.cmd([[command GoBuild        :setl makeprg=go\ build | :Gmake]]) end
  if cmds["GoGenerate"]    == nil then vim.cmd([[command GoGenerate     :setl makeprg=go\ generate | :Gmake]]) end
  if cmds["GoRun"]         == nil then vim.cmd([[command GoRun          :setl makeprg=go\ run | :Gmake]]) end
  if cmds["GoTestFunc"]    == nil then vim.cmd([[command GoTestFunc     :Gmake -run ..]]) end

  if cmds["GoTest"]        == nil then vim.cmd([[command GoTest         :setl makeprg=go\ test\ ./... | :Gmake]]) end
  if cmds["GoTestCompile"] == nil then vim.cmd([[command GoTestCompile  :setl makeprg=go\ build | :Gmake]]) end

  vim.cmd([[command! GoAddTest lua require("go.gotests").fun_test()]])
  vim.cmd([[command! GoAddExpTest lua require("go.gotests").exported_test()]])
  vim.cmd([[command! GoAddAllTest lua require("go.gotests").all_test()]])

  vim.cmd([[command! -nargs=* GoAddTag lua require("go.tags").add(<f-args>)]])
  vim.cmd([[command! -nargs=* GoRmTag lua require("go.tags").rm(<f-args>)]])
  vim.cmd([[command!          GoClearTag lua require("go.tags").clear()]])
  vim.cmd([[command!          GoCmt lua require("go.comment").gen()]])
  vim.cmd([[command!          GoRename lua require("go.rename").run()]])
  vim.cmd([[command!          Giferr lua require("go.iferr").run()]])
  vim.cmd([[command!          Gfstruct lua require("go.reftool").fillstruct()]])
  vim.cmd([[command!          Gfswitch lua require("go.reftool").fillswitch()]])

  -- vim.cmd([[command GoLint :compiler golangci-lint run | :Gmake]])
  vim.cmd([[command! GoLint :setl makeprg=golangci-lint\ run\ --out-format\ tab | :Gmake]])
  vim.cmd("au FileType go au QuickFixCmdPost  [^l]* nested cwindow")
  vim.cmd("au FileType go au QuickFixCmdPost    l* nested lwindow")

end
return go
