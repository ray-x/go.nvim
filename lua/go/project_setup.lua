-- this file allow a setup load per project
--[[
-- sample cfg
return  {
  go = "go", -- set to go1.18beta1 if necessary
  goimport = "gopls", -- if set to 'gopls' will use gopls format, also goimport
  fillstruct = "gopls",
  gofmt = "gofumpt", -- if set to gopls will use gopls format
  max_line_len = 120,
  tag_transform = false,
  test_dir = "",
  comment_placeholder = "   ",
  icons = { breakpoint = "🧘", currentpos = "🏃" }, -- set to false to disable icons setup
  verbose = false,
  log_path = vim.fn.expand("$HOME") .. "/tmp/gonvim.log",
  lsp_cfg = false, -- false: do nothing
  -- true: apply non-default gopls setup defined in go/lsp.lua
  -- if lsp_cfg is a table, merge table with with non-default gopls setup in go/lsp.lua, e.g.
  lsp_gofumpt = false, -- true: set default gofmt in gopls format to gofumpt
  lsp_on_attach = nil, -- nil: use on_attach function defined in go/lsp.lua for gopls,
  --      when lsp_cfg is true
  -- if lsp_on_attach is a function: use this function as on_attach function for gopls,
  --                                 when lsp_cfg is true
  lsp_format_on_save = 1,
  lsp_document_formatting = true,
  -- set to true: use gopls to format
  -- false if you want to use other formatter tool(e.g. efm, nulls)

  lsp_keymaps = true, -- true: use default keymaps defined in go/lsp.lua
  lsp_codelens = true,
  lsp_diag_hdlr = true, -- hook lsp diag handler
  -- virtual text setup
  lsp_diag_virtual_text = { space = 0, prefix = "" },
  lsp_diag_signs = true,
  lsp_diag_update_in_insert = false,
  go_boilplater_url = "https://github.com/thockin/go-build-template.git",
  gopls_cmd = nil, --- you can provide gopls path and cmd if it not in PATH, e.g. cmd = {  "/home/ray/.local/nvim/data/lspinstall/go/gopls" }
  gopls_remote_auto = true,
  gocoverage_sign = "█",
  gocoverage_sign_priority = 5,
  launch_json = nil, -- the launch.json file path, default to .vscode/launch.json
  -- launch_json = vim.fn.getcwd() .. "/.vscode/launch.json",
  dap_debug = true,
  dap_debug_gui = true,
  dap_debug_keymap = true, -- true: use keymap for debugger defined in go/dap.lua
  -- false: do not use keymap in go/dap.lua.  you must define your own.
  dap_vt = true, -- false, true and 'all frames'
  dap_port = 38697, -- can be set to a number or `-1` so go.nvim will pickup a random port
  build_tags = "", --- you can provide extra build tags for tests or debugger
  textobjects = true, -- treesitter binding for text objects
  test_runner = "go", -- richgo, go test, richgo, dlv, ginkgo
  verbose_tests = true, -- set to add verbose flag to tests
  run_in_floaterm = false, -- set to true to run in float window.
}

]]

-- if the file existed, load it into config

local util = require("go.utils")
local log = util.log
local M = {}
local sep = require("go.utils").sep()

function M.setup_project()
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vim.fn.getcwd()
  local gocfg = workfolder .. sep .. ".gonvim"

  if vim.fn.filereadable(gocfg) == 1 then
    return gocfg
  else
    local f = io.open(gocfg, "w")
    f:write("return {}")
    f:close()
  end
end

function M.load_project()
  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vim.fn.getcwd()
  local gocfg = workfolder .. sep .. ".gonvim"
  if vim.fn.filereadable(gocfg) == 1 then
    local f = assert(loadfile(gocfg))
    _GO_NVIM_CFG = vim.tbl_deep_extend("force", _GO_NVIM_CFG, f())
  else
    return false
  end
end

M.load_project()

return M
