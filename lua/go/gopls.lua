local utils = require("go.utils")
local log = utils.log

local M = {}
-- https://go.googlesource.com/tools/+/refs/heads/master/gopls/doc/commands.md
-- "executeCommandProvider":{"commands":["gopls.add_dependency","gopls.add_import","gopls.apply_fix","gopls.check_upgrades","gopls.gc_details","gopls.generate","gopls.generate_gopls_mod","gopls.go_get_package","gopls.list_known_packages","gopls.regenerate_cgo","gopls.remove_dependency","gopls.run_tests","gopls.start_debugging","gopls.test","gopls.tidy","gopls.toggle_gc_details","gopls.update_go_sum","gopls.upgrade_dependency","gopls.vendor","gopls.workspace_metadata"]}

local gopls_cmds = {
  "gopls.add_dependency",
  "gopls.add_import",
  "gopls.apply_fix",
  "gopls.check_upgrades",
  "gopls.gc_details",
  "gopls.generate",
  "gopls.generate_gopls_mod",
  "gopls.go_get_package",
  "gopls.list_known_packages",
  "gopls.regenerate_cgo",
  "gopls.remove_dependency",
  "gopls.run_tests",
  "gopls.start_debugging",
  "gopls.test",
  "gopls.tidy",
  "gopls.toggle_gc_details",
  "gopls.update_go_sum",
  "gopls.upgrade_dependency",
  "gopls.vendor",
  "gopls.workspace_metadata",
}

local function check_for_error(msg)
  if msg ~= nil and type(msg[1]) == "table" then
    for k, v in pairs(msg[1]) do
      if k == "error" then
        log.error("LSP", v.message)
        break
      end
    end
  end
end

for _, value in ipairs(gopls_cmds) do
  local fname = string.sub(value, #"gopls." + 1)
  M[fname] = function(arg)
    log(fname)
    local b = vim.api.nvim_get_current_buf()
    local uri = vim.uri_from_bufnr(b)
    local arguments = { { URI = uri, URIs = { uri } } }
    arguments = vim.tbl_extend("keep", arguments, arg or {})

    local resp = vim.lsp.buf_request_sync(b, "workspace/executeCommand", {
      command = value,
      arguments = arguments,
    })
    check_for_error(resp)
    log(resp)
    return resp
  end
end

M.list_pkgs = function()
  local resp = M.list_known_packages()

  local pkgs = {}
  for _, response in pairs(resp) do
    if response.result ~= nil then
      pkgs = response.result.Packages
      break
    end
  end
  return pkgs
end

-- check_for_upgrades({Modules = {'package'}})
function M.version()

  local cache_dir = vim.fn.stdpath("cache")
  local path = string.format("%s%sversion.txt", cache_dir, utils.sep())

  vim.fn.jobstart({ "gopls", "version" }, {
    on_stdout = function(c, data, name)
      local msg = ""
      if type(data) == "table" and #data > 0 then
        data = table.concat(data, " ")
      end
      if #data > 1 then
        msg = msg .. data
      end
      log(msg)

      local version = string.match(msg, "%s+v([%d%.]+)%s+")
      if version == nil then
        log(version, msg)
        return
      end

      local f = io.open(path, "w+")
      if f == nil then
        return
      end
      f:write(version)
      f:close()
      log(version)
    end,
  })

  local f = io.open(path, "r")
  if f == nil then
    return vim.fn.system("gopls version"):match("%s+v([%d%.]+)%s+")
  end
  local version = f:read("*l")
  f:close()
  log(version)
  return version
end

local setups = {
  -- capabilities = cap,
  filetypes = { "go", "gomod", "gohtmltmpl", "gotexttmpl" },
  message_level = vim.lsp.protocol.MessageType.Error,
  cmd = {
    "gopls", -- share the gopls instance if there is one already
    "-remote.debug=:0",
  },
  root_dir = function(fname)
    local has_lsp, lspconfig = pcall(require, "lspconfig")
    if has_lsp then
      local util = lspconfig.util
      return util.root_pattern("go.mod", ".git")(fname) or util.path.dirname(fname)
    end
  end,
  flags = { allow_incremental_sync = true, debounce_text_changes = 500 },
  settings = {
    gopls = {
      -- more settings: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
      -- flags = {allow_incremental_sync = true, debounce_text_changes = 500},
      -- not supported
      analyses = { unusedparams = true, unreachable = false },
      codelenses = {
        generate = true, -- show the `go generate` lens.
        gc_details = true, --  // Show a code lens toggling the display of gc's choices.
        test = true,
        tidy = true,
      },
      usePlaceholders = true,
      completeUnimported = true,
      staticcheck = true,
      matcher = "Fuzzy",
      diagnosticsDelay = "500ms",
      experimentalWatchedFileDelay = "100ms",
      symbolMatcher = "fuzzy",
      ["local"] = "",
      gofumpt = false, -- true, -- turn on for new repos, gofmpt is good but also create code turmoils
      buildFlags = { "-tags", "integration" },
      -- buildFlags = {"-tags", "functional"}
    },
  },
}

M.setups = function()
  local v = M.version()
  if v > "0.7" then
    setups.settings = vim.tbl_deep_extend("force", setups.settings, {
      experimentalPostfixCompletions = true,
      experimentalUseInvalidMetadata = true,
      hoverKind = "Structured",
    })
  end
  return setups
end

return M
