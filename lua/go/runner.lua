local uv, api = vim.loop, vim.api
local util = require('go.utils')
local log = require('go.utils').log

-- run command with loop
local run = function(cmd, opts, uvopts)
  uvopts = uvopts or {}
  opts = opts or {}
  log(cmd)
  if type(cmd) == 'string' then
    local split_pattern = '%s+'
    cmd = vim.split(cmd, split_pattern)
    log(cmd)
  end
  local cmd_str = vim.inspect(cmd)
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

  local output_buf = ''
  local output_stderr = ''
  local function update_chunk_fn(err, chunk)
    if err then
      vim.schedule(function()
        vim.notify('error ' .. tostring(err) .. vim.inspect(chunk or ''), vim.log.levels.WARN)
      end)
    end

    local lines = {}
    if chunk then
      for s in chunk:gmatch('[^\r\n]+') do
        table.insert(lines, s)
      end
      output_buf = output_buf .. '\n' .. table.concat(lines, '\n')
      log(lines)

      local cfixlines = vim.split(output_buf, '\n')
      local locopts = {
        title = vim.inspect(cmd),
        lines = cfixlines,
      }
      if opts.efm then
        locopts.efm = opts.efm
      end
      log(locopts)
      vim.schedule(function()
        vim.fn.setloclist(0, {}, 'r', locopts)
        vim.notify('run lopen to see output', vim.log.levels.INFO)
      end)
    end
    return lines
  end
  local update_chunk = function(err, chunk)
    local lines
    if opts.update_chunk then
      lines = opts.update_chunk(err, chunk)
    else
      lines = update_chunk_fn(err, chunk)
    end
    if opts.on_chunk and lines then
      opts.on_chunk(err, lines)
    end
    _GO_NVIM_CFG.on_stdout(err, chunk)
  end
  log('job:', cmd, job_options)

  local Sprite = util.load_plugin('guihua.lua', 'guihua.sprite')
  local sprite
  if Sprite then
    sprite = Sprite:new({
      loc = 'top_center',
      syntax = 'lua',
      rect = { height = 1, width = 30 },
      data = { 'Running ' .. vim.inspect(cmd) },
      timeout = 30000,
      hl_line = 1,
    })
  else
    sprite = { on_close = function() end }
  end
  if uvopts.cwd then
    log('cwd', opts.cwd)
    if uvopts.cwd == '%:h' then
      uvopts.cwd = vim.fn.expand(opts.cwd)
    end
  end
  handle, _ = uv.spawn(
    cmd,
    { stdio = { stdin, stdout, stderr }, cwd = uvopts.cwd, args = job_options.args },
    function(code, signal) -- on exit()
      stdin:close()

      stdout:read_stop()
      stdout:close()

      stderr:read_stop()
      stderr:close()

      handle:close()
      log('spawn finished', code, signal)
      sprite.on_close()

      if output_stderr ~= '' then
        vim.schedule(function()
          vim.notify(output_stderr)
        end)
      end
      if opts and opts.on_exit then
        -- if on_exit hook is on the hook output is what we want to show in loc
        -- this avoid show samething in both on_exit and loc
        output_buf = opts.on_exit(code, signal, output_buf)
        if not output_buf then
          return
        end
      end
      if code ~= 0 then
        log('failed to run', code, output_buf)

        output_buf = output_buf or ''
        vim.schedule(function()
          vim.notify(
            cmd_str .. ' failed exit code ' .. tostring(code) .. output_buf,
            vim.log.levels.WARN
          )
        end)
      end

      if output_buf ~= '' or output_stderr ~= '' then
        local l = (output_buf or '') .. '\n' .. (output_stderr or '')
        l = util.remove_ansi_escape(l)
        local lines = vim.split(vim.trim(l), '\n')
        lines = util.handle_job_data(lines)
        local locopts = {
          title = vim.inspect(cmd),
          lines = lines,
        }
        if opts.efm then
          locopts.efm = opts.efm
        end
        log(locopts, lines)
        if #lines > 0 then
          vim.schedule(function()
            vim.fn.setloclist(0, {}, ' ', locopts)
            util.quickfix('lopen')
          end)
        end
      end
      _GO_NVIM_CFG.on_exit(code, signal, output_buf)
    end
  )
  _GO_NVIM_CFG.on_jobstart(cmd)

  uv.read_start(stderr, function(err, data)
    if err then
      vim.notify('error ' .. tostring(err) .. tostring(data or ''), vim.log.levels.WARN)
    end
    if data ~= nil then
      log(data)
      output_stderr = output_stderr ..  util.remove_ansi_escape(tostring(data))
    end
    _GO_NVIM_CFG.on_stderr(err, data)
  end)
  stdout:read_start(update_chunk)
  return stdin, stdout, stderr
end

local function make(...)
  local makeprg = vim.api.nvim_buf_get_option(0, 'makeprg')
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
