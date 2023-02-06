local go = {}

-- go.dbg_complete = function(arglead, cmdline, cursorpos)
go.dbg_complete = function(_, _, _)
  local testopts = {
    "--help",
    "--test",
    "--nearest",
    "--file",
    "--package",
    "--attach",
    "--stop",
    "--restart",
    "--breakpoint",
    "--tag",
  }
  return testopts
end

go.tools_complete = function(_, _, _)
  local gotools = require("go.install").gotools
  table.sort(gotools)
  return gotools
end

go.impl_complete = function(arglead, cmdline, cursorpos)
  return require("go.impl").complete(arglead, cmdline, cursorpos)
end

go.modify_tags_complete = function(_, _, _)
  local opts = {
    "-add-tags",
    "-add-options",
    "-remove-tags",
    "-remove-options",
    "-clear-tags",
    "-clear-options",
  }
  return opts
end

-- how to deal complete https://github.com/vim-scripts/marvim/blob/c159856871aa18fa4f3249c6aa312c52f586d1ef/plugin/marvim.vim#L259

-- go.add_tags_complete = function(arglead, line, pos)
go.add_tags_complete = function(arglead, line, _)
  -- print("lead: ",arglead, "L", line, "p" )
  local transf = { "camelcase", "snakecase", "lispcase", "pascalcase", "titlecase", "keep" }
  local options = {"-transform", "-add-options"}
  local ret = {}
  if #vim.split(line, "%s+") >= 2 then
    if vim.startswith("-transform", arglead) then
      return "-transform"
    end
    table.foreach(transf, function(_, tag)
      if vim.startswith(tag, arglead) then
        ret[#ret + 1] = tag
      end
    end)
    if #ret > 0 then
      return ret
    end
    return transf
  end

  local opts = {
    "json",
    "json.yml",
    "-transform",
  }
  return opts
end

return go
