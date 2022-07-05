local uv, api = vim.loop, vim.api
local util = require("go.utils")
local log = require("go.utils").log

-- run command with loop
local run = function(cmd, opts)
  opts = opts or {}
  log(cmd)
  if type(cmd) == "string" then
    local split_pattern = "%s+"
    cmd = vim.split(cmd, split_pattern)
    log(cmd)
  end
  local cmd_str = vim.inspect(cmd)
  local job_options = vim.deepcopy(opts or {})
  job_options.args = job_options.args or {}
  local cmdargs = vim.list_slice(cmd, 2, #cmd) or {}

  if cmdargs and cmdargs[1] == "test" and #cmdargs == 3 then
    table.insert(cmdargs, "." .. util.sep() .. "...")
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

  local output_buf = ""
  local function update_chunk_fn(err, chunk)
    if err then
      vim.schedule(function()
        vim.notify("error " .. tostring(err) .. vim.inspect(chunk or ""), vim.lsp.log_levels.WARN)
      end)
    end
    if chunk then
      output_buf = output_buf .. chunk
    end
    log(err, chunk)
  end
  local update_chunk = opts.update_chunk or update_chunk_fn

  log("job:", cmd, job_options)
  handle, _ = uv.spawn(
    cmd,
    { stdio = { stdin, stdout, stderr }, args = job_options.args },
    function(code, signal) -- on exit
      stdin:close()

      stdout:read_stop()
      stdout:close()

      stderr:read_stop()
      stderr:close()

      handle:close()
      log(output_buf)
      if opts and opts.on_exit then
        -- if on_exit hook is on the hook output is what we want to show in loc
        -- this avoid show samething in both on_exit and loc
        output_buf = opts.on_exit(code, signal, output_buf)
        if not output_buf then
          return
        end
      end
      if code ~= 0 then
        log("failed to run", code, output_buf)

        output_buf = output_buf or ""
        vim.notify(cmd_str .. " failed exit code " .. tostring(code) .. output_buf, vim.lsp.log_levels.WARN)
      end
      if output_buf ~= "" then
        local lines = vim.split(output_buf, "\n", true)
        lines = util.handle_job_data(lines)
        local locopts = {
          title = vim.inspect(cmd),
          lines = lines,
        }
        if opts.efm then
          locopts.efm = opts.efm
        end
        log(locopts)
        if #lines > 0 then
          vim.schedule(function()
            vim.fn.setloclist(0, {}, " ", locopts)
            vim.cmd("lopen")
          end)
        end
      end
    end
  )

  uv.read_start(stderr, function(err, data)
    if data ~= nil then
      update_chunk("stderr: " .. tostring(err), data)
    end
  end)
  stdout:read_start(update_chunk)
  -- stderr:read_start(update_chunk)
end

local function make(...)
  local makeprg = vim.api.nvim_buf_get_option(0, "makeprg")
  local args = { ... }
  local setup = {}
  if #args > 0 then
    for _, v in ipairs(args) do
      table.insert(setup, v)
    end
  end
  local opts = {}
  opts.args = setup
  run(makeprg, opts)
end

return { run = run, make = make }
