local utils = require("go.utils")
local log = utils.log
local runner = require("go.runner")
local curl = "curl"
local run = function(...)
  local query = select(1, ...)
  if query == nil then
    query = vim.fn.expand("<cword>")
  end
  local cmd = string.format("%s cht.sh/go/%s?T", curl, query)
  cmd = vim.split(cmd, " ")
  log(cmd)
  local opts = {
    on_exit = function(code, signal, output)
      if code ~= 0 or signal ~= 0 then
        log(string.format("command exited with code: %s, signal: %s", code, signal))
        return
      end
      vim.schedule(function()
        local data = vim.split(output, "\n")
        data = utils.handle_job_data(data)

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
      end)
    end,
  }

  runner.run(cmd, opts)
end
return { run = run }
