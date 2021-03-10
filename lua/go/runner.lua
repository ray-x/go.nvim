local uv, api = vim.loop, vim.api

local check_same = function(tbl1, tbl2)
  if #tbl1 ~= #tbl2 then
    return
  end
  for k, v in ipairs(tbl1) do
    if v ~= tbl2[k] then
      return true
    end
  end
  return false
end

local run = function(cmd, args, on_stdout, stdin_data, buf)
  buf = buf or false
  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local file = api.nvim_buf_get_name(0)
  local handle, pid =
    uv.spawn(
    cmd,
    {
      stdio = {stdin, stdout, stderr},
      args = args
    },
    function(code, signal) -- on exit
    end
  )

  uv.read_start(stdout, vim.schedule_wrap(on_stdout))

  uv.read_start(
    stderr,
    function(err, data)
      assert(not err, err)
      if data then
        print("stderr chunk", stderr, data)
      end
    end
  )
  if buf then
    for i = 1, #stdin_data do
      print("sending " .. stdin_data[i])
      stdin:write(stdin_data[i])
    end
    if not stdin:is_closing() then
      stdin:close()
    end
  end

  uv.shutdown(
    stdin,
    function()
      uv.close(
        handle,
        function()
        end
      )
    end
  )
end

return {golines_format = golines_format, run = run}
