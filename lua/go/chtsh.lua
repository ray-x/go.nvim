local utils = require("go.utils")
local log = utils.log
local curl = "curl"
local run = function(...)
  local query = select(1, ...)
  if query == nil then
    query = vim.fn.expand("<cword>")
  end
  local cmd = string.format("%s cht.sh/go/%s?T", curl, query)
  cmd = vim.split(cmd, " ")
  log(cmd)

  local data = vim.fn.systemlist(cmd, vim.fn.bufnr("%"))

  data = utils.handle_job_data(data)
  if not data then
    return
  end
  -- log(data)
  if #data > 4 then
    data = vim.list_slice(data, 4, #data)
    local TextView = utils.load_plugin("guihua.lua", "guihua.textview")
    if TextView then
      local win = TextView:new({
        loc = "top_center",
        syntax = "go",
        rect = { height = #data, pos_x = 0, pos_y = 4 },
        data = data,
        enter = true,
      })
      log("draw data", data)
      win:on_draw(data)
    else
      local name = vim.fn.tempname() .. ".go"
      vim.fn.writefile(data, name)
      cmd = " silent exe 'e " .. name .. "'"
      vim.cmd(cmd)
      vim.cmd("e")
    end
  else
    vim.notify("No result " .. vim.inspect(data))
  end
end
return { run = run }
