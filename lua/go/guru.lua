-- local ts_utils = require 'nvim-treesitter.ts_utils'
local utils = require("go.utils")
local log = utils.log
local pkg = require("go.package")
local fn = vim.fn

local guru = "guru"
local vfn = vim.fn

-- guru_cmd returns a dict that contains the command to execute guru. args
-- is dict with following options:
--  mode        : guru mode, such as 'implements'
--  format      : output format, either 'plain' or 'json'
--  needs_scope : if 1, adds the current package to the scope
--  selected    : if 1, means it's a range of selection, otherwise it picks up the
--                offset under the cursor
-- example output:
--  {'cmd' : ['guru', '-json', 'implements', 'demo/demo.go:#66']}
local guru_cmd = function(args)
  local mode = args.mode
  local format = args.format
  local selected = args.selected
  local postype = vim.fn.get(args, "postype", "cursor")
  local need_scope = args.needs_scope
  local result = {}
  local build_tags = require("go.gotest").get_build_tags()
  require("go.install").install(guru)
  local cmd = { guru }
  if build_tags then
    table.insert(cmd, build_tags)
  end

  if vim.o.modified then
    table.insert(cmd, "-modified")
  end
  if format == "json" then
    table.insert(cmd, "-json")
  end

  local fname = vfn.expand("%:p") -- %:p:h ? %:p
  -- local fpath = vfn.expand("%:p:h") -- %:p:h ? %:p

  if need_scope then
    local scope = pkg.pkg_from_path()
    log(scope)
    if scope then
      table.insert(cmd, "-scope")
      table.insert(cmd, fn.join(scope, ","))
    end
  end
  local pos
  if postype == "balloon" then
    local byte_offset = utils.offset(vim.v.beval_lnum, vim.v.beval_col)
    pos = string.format("#%s", byte_offset)
  else
    if selected ~= -1 then -- visual mode
      local pos1 = utils.offset(fn.line("'<"), fn.col("'<"))
      local pos2 = utils.offset(fn.line("'>"), fn.col("'>"))
      pos = string.format("#%s,#%s", pos1, pos2)
    else
      pos = string.format("#%s", vfn.wordcount().cursor_bytes)
    end
  end

  local filename = fn.fnamemodify(fn.expand("%"), ":p:gs?\\?/?") .. ":" .. pos
  table.insert(cmd, mode)
  table.insert(cmd, filename)
  log(cmd)
  print(vim.inspect(cmd))

  vfn.jobstart(cmd, {
    on_exit = function(status, data, stderr)
      log(status, data)
    end,
    on_stderr = function(e, data)
      log(e, data)
    end,
    on_stdout = function(_, data, _)
      data = utils.handle_job_data(data)
      if not data then
        return
      end
      print(data)
      log(data)
      -- local result = vfn.json_decode(data)
      local res = vim.json.decode(data)
      if res.errors ~= nil or res.lines == nil or result["start"] == nil or res["start"] == 0 then
        vim.notify("failed to run guru" .. vim.inspect(res), vim.lsp.log_levels.ERROR)
      end
      vim.notify("guru  " .. mode, vim.lsp.log_levels.INFO)
    end,
  })
end

local function callstack(selected)
  selected = selected or -1
  guru_cmd({
    mode = "callstack",
    format = "plain",
    needs_scope = 1,
    selected = selected,
  })
end

local function channel_peers(selected)
  selected = selected or -1
  guru_cmd({
    mode = "peers",
    format = "plain",
    needs_scope = 1,
    selected = selected,
  })
end
return { guru_cmd = guru_cmd, callstack = callstack, channel_peers = channel_peers }
