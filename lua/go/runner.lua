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

  -- reset loclist
  local output_buf = ''
  local output_stderr = ''
  local function update_chunk_fn(err, chunk)
    if err then
      vim.schedule(function()
        util.error('error ' .. tostring(err) .. vim.inspect(chunk or ''), vim.log.levels.WARN)
      end)
    end

    local lines = {}
    if chunk then
      for s in chunk:gmatch('[^\r\n]+') do
        table.insert(lines, s)
      end
      output_buf = output_buf .. '\n' .. table.concat(lines, '\n')
      log(lines, output_buf)

      local cfixlines = vim.split(output_buf, '\n')
      local locopts = {
        title = vim.inspect(cmd),
        lines = cfixlines,
      }
      if opts.efm then
        locopts.efm = opts.efm
      end
      log(locopts)
      if opts.setloclist ~= false then
        vim.schedule(function()
          vim.fn.setloclist(0, {}, 'a', locopts)
          vim.notify('run lopen to see output', vim.log.levels.INFO)
        end)
      end
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
    if opts.on_chunk then
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
  else
    if vim.fn.expand('%:t'):find('go.mod') or vim.fn.expand('%:t'):find('go.work') then
      opts.cwd = vim.fn.expand('%:p:h')
    end
  end

  output_stderr = ''
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
        log('stderr', output_stderr)
        vim.schedule(function()
          vim.notify(output_stderr)
        end)
      end
      if code ~= 0 then
        log('failed to run', code, output_buf, output_stderr)
        vim.schedule(function()
          util.info(
            cmd_str .. ' exit with code: ' .. tostring(code or 0) .. (output_buf or '') .. (output_stderr or '')
          )
        end)
      end

      local combine_output = ''
      if output_buf ~= '' or output_stderr ~= '' then
        -- some commands may output to stderr instead of stdout
        combine_output = (output_buf or '') .. '\n' .. (output_stderr or '')
        combine_output = util.remove_ansi_escape(combine_output)
        combine_output = vim.trim(combine_output)
      end
      if opts and opts.on_exit then
        local onexit_output = opts.on_exit(code, signal, combine_output)
        if not onexit_output then
          return
        else
          combine_output = onexit_output
        end
      end

      if code ~= 0 or signal ~= 0 or output_stderr ~= '' then
        local lines = util.handle_job_data(vim.split(combine_output, '\n'))
        local locopts = {
          title = vim.inspect(cmd),
          lines = lines,
        }
        if opts.efm then
          locopts.efm = opts.efm
        end
        log('command finished: ', locopts, lines)
        if #lines > 0 then
          vim.schedule(function()
            vim.fn.setloclist(0, {}, ' ', locopts)
            util.info('run lopen to see output')
          end)
        end
      end

      combine_output = output_buf .. '\n' .. output_stderr
      if opts and opts.on_exit then
        local onexit_output = opts.on_exit(code, signal, combine_output)
        log('on_exit returned ', onexit_output)
      end

      if code ~= 0 or signal ~= 0 or output_stderr ~= '' then
        log('command finished with error code: ', code, signal)
      end

      _GO_NVIM_CFG.on_exit(code, signal, combine_output)
    end
  )
  _GO_NVIM_CFG.on_jobstart(cmd)

  uv.read_start(stderr, function(err, data)
    if err then
      util.error(tostring(err) .. tostring(data or ''))
    end
    if data ~= nil then
      log('stderr read handler', data)
      output_stderr = output_stderr .. util.remove_ansi_escape(tostring(data))
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
