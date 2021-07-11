-- some of commands extracted from gopher.vim
local go = {}
_GO_NVIM_CFG = {
  goimport = 'gofumports', -- if set to 'gopls' will use gopls format
  gofmt = 'gofumpt', -- if set to gopls will use gopls format
  max_line_line = 120,
  tag_transform = false,
  test_dir = '',
  comment_placeholder = '   ',
  verbose = false,
  log_path = vim.fn.expand("$HOME") .. "/tmp/gonvim.log",
  lsp_cfg = false, -- true: apply go.nvim non-default gopls setup
  lsp_gofumpt = false, -- true: set default gofmt in gopls format to gofumpt
  lsp_on_attach = nil, -- provides a on_attach function to gopls, will use go.nvim on_attach if nil
  dap_debug = false,
  dap_debug_gui = false,
  dap_vt = true -- false, true and 'all frames'
}

local dap_config = function()
  vim.fn.sign_define('DapBreakpoint', {text = '🧘', texthl = '', linehl = '', numhl = ''})
  vim.fn.sign_define('DapStopped', {text = '🏃', texthl = '', linehl = '', numhl = ''})
  vim.cmd(
      [[command! BreakCondition lua require"dap".set_breakpoint(vim.fn.input("Breakpoint condition: "))]])

  vim.cmd([[command! ReplRun lua require"dap".repl.run_last()]])
  vim.cmd([[command! ReplToggle lua require"dap".repl.toggle()]])
  vim.cmd([[command! ReplOpen  lua require"dap".repl.open(), 'split']])
  vim.cmd(
      [[command! DapRerun require'dap'.disconnect();require'dap'.stop();require'dap'.run_last()]])

  vim.cmd([[command! DapStop require'go.dap'.stop()]])
  vim.g.dap_virtual_text = true
end

function go.setup(cfg)
  cfg = cfg or {}
  if cfg.max_len then
    print('go.nvim max_len renamed to max_line_len')
  end
  _GO_NVIM_CFG = vim.tbl_extend("force", _GO_NVIM_CFG, cfg)

  vim.cmd([[command! Gmake silent lua require'go.asyncmake'.make()]])

  vim.cmd([[command! Gofmt lua require("go.format").gofmt()]])
  vim.cmd([[command! Goimport lua require("go.format").goimport()]])

  vim.cmd([[command! GoBuild        :setl makeprg=go\ build | :Gmake]])
  vim.cmd([[command! GoGenerate     :setl makeprg=go\ generate | :Gmake]])
  vim.cmd([[command! GoRun          :setl makeprg=go\ run | :Gmake]])

  vim.cmd([[command! GoTest         :setl makeprg=go\ test\ -v\ ./... | :Gmake]])
  vim.cmd([[command! GoTestCompile  :setl makeprg=go\ build | :Gmake]])
  vim.cmd([[command! GoLint         :setl makeprg=golangci-lint\ run\ --out-format\ tab | :Gmake]])

  vim.cmd([[command! GoTestFunc     lua require('go.gotest').test_fun()]])
  vim.cmd([[command! GoAddTest      lua require("go.gotests").fun_test()]])
  vim.cmd([[command! GoAddExpTest   lua require("go.gotests").exported_test()]])
  vim.cmd([[command! GoAddAllTest   lua require("go.gotests").all_test()]])

  vim.cmd([[command! -nargs=* GoAddTag lua require("go.tags").add(<f-args>)]])
  vim.cmd([[command! -nargs=* GoRmTag lua require("go.tags").rm(<f-args>)]])
  vim.cmd([[command!          GoClearTag lua require("go.tags").clear()]])
  vim.cmd([[command!          GoCmt lua require("go.comment").gen()]])
  vim.cmd([[command!          GoRename lua require("go.rename").run()]])
  vim.cmd([[command!          Giferr lua require("go.iferr").run()]])
  vim.cmd([[command!          Gfstruct lua require("go.reftool").fillstruct()]])
  vim.cmd([[command!          Gfswitch lua require("go.reftool").fillswitch()]])

  vim.cmd("au FileType go au QuickFixCmdPost  [^l]* nested cwindow")
  vim.cmd("au FileType go au QuickFixCmdPost    l* nested lwindow")

  if _GO_NVIM_CFG.dap_debug then
    dap_config()
    vim.cmd([[command! -nargs=*  GoDebug lua require"go.dap".run(<f-args>)]])
    vim.cmd([[command!           GoBreakToggle lua require"go.dap".breakpt()]])
    vim.cmd(
        [[command! BreakCondition lua require"dap".set_breakpoint(vim.fn.input("Breakpoint condition: "))]])

    vim.cmd([[command! ReplRun lua require"dap".repl.run_last()]])
    vim.cmd([[command! ReplToggle lua require"dap".repl.toggle()]])
    vim.cmd([[command! ReplOpen  lua require"dap".repl.open(), 'split']])
    vim.cmd(
        [[command! DapRerun require'dap'.disconnect();require'dap'.stop();require'dap'.run_last()]])
  end

  if _GO_NVIM_CFG.lsp_cfg then
    require 'go.lsp'
  end
end
return go
