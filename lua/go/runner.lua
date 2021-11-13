local uv, api = vim.loop, vim.api
local util = require('go.utils')
local log = require('go.utils').log
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

local run = function(cmd, opts)
  opts = opts or {}
  local shell_cmd
  log(cmd)
  if type(cmd) == "string" then
    local split_pattern = "%s+"
    cmd = vim.split(cmd, split_pattern)
    log(cmd)
  end
  local job_options = vim.deepcopy(opts or {})
  job_options.args = job_options.args or {}
  local cmdargs = vim.list_slice(cmd, 2, #cmd) or {}

  if cmdargs and cmdargs[1] == 'test' and #cmdargs == 3 then
    table.insert(cmdargs, '.' .. util.sep() .. '...')
    log(cmdargs)
  end
  vim.list_extend(cmdargs, job_options.args)
  job_options.args = cmdargs

  cmd = cmd[1]
  log(cmd, job_options.args)

  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  -- local file = api.nvim_buf_get_name(0)
  local handle = nil
  -- setup output

  api.nvim_command("10new")
  -- assert(cwd and M.path.is_dir(cwd), "sh: Invalid directory")
  local winnr = api.nvim_get_current_win()
  local bufnr = api.nvim_get_current_buf()

  local output_buf = ''
  local function update_chunk(err, chunk)
    if chunk then
      output_buf = output_buf .. chunk
      local lines = vim.split(output_buf, '\n', true)
      api.nvim_buf_set_option(bufnr, "modifiable", true)
      api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      api.nvim_buf_set_option(bufnr, "modifiable", false)
      api.nvim_buf_set_option(bufnr, "modified", false)
      if api.nvim_win_is_valid(winnr) then
        api.nvim_win_set_cursor(winnr, {#lines, 0})
      end
    end
  end
  update_chunk = vim.schedule_wrap(update_chunk)

  log("job:", cmd, job_options)
  handle, pid = uv.spawn(cmd, {stdio = {stdin, stdout, stderr}, args = job_options.args},
                         function(code, signal) -- on exit
    update_chunk(nil, "Process exited with code " .. code .. " / signal " .. signal)
    stdin:read_stop()
    stdin:close()

    stdout:read_stop()
    stdout:close()
    handle:close()

  end)

  api.nvim_buf_attach(bufnr, false, {
    on_detach = function()
      if not handle:is_closing() then
        handle:kill(15)
      end
    end
  })

  -- uv.read_start(stdout, vim.schedule_wrap(on_stdout))

  uv.read_start(stderr, function(err, data)
    assert(not err, err)
    if data then
      print("stderr chunk", stderr, data)
    end
  end)
  stdout:read_start(update_chunk)
  stderr:read_start(update_chunk)

end

local function make(...)
  local makeprg = vim.api.nvim_buf_get_option(0, "makeprg")
  local args = {...}
  local setup = {}
  if #args > 0 then
    for i, v in ipairs(args) do
      table.insert(setup, v)
    end
  end
  local opts = {}
  opts.args = setup
  run(makeprg, opts)
end

return {run = run, make = make}
