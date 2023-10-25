-- inspired by https://phelipetls.github.io/posts/async-make-in-nvim-with-lua/
local M = {}
local util = require('go.utils')
local log = util.log
local trace = util.log
local getopt = require('go.alt_getopt')

local os_name = vim.loop.os_uname().sysname
local is_windows = os_name == 'Windows' or os_name == 'Windows_NT'
local is_git_shell = is_windows
  and (vim.fn.exists('$SHELL') and vim.fn.expand('$SHELL'):find('bash.exe') ~= nil)

local function compile_efm()
  local efm = [[%-G#\ %.%#]]
  efm = efm .. [[,%-G%.%#panic:\ %m]]
  efm = efm .. [[,%Ecan\'t\ load\ package:\ %m]]
  efm = efm .. [[,%A%\\%%\(%[%^:]%\\+:\ %\\)%\\?%f:%l:%c:\ %m]]
  efm = efm .. [[,%A%\\%%\(%[%^:]%\\+:\ %\\)%\\?%f:%l:\ %m]]
  efm = efm .. [[,%C%*\\s%m]]
  efm = efm .. [[,%-G%.%#]]
  return efm
end

local extract_filepath = util.extract_filepath

local long_opts = {
  verbose = 'v',
  compile = 'c',
  debug = 'g', -- build for debugging
  coverprofile = 'C',
  tags = 't',
  args = 'a',
  count = 'n',
  build = 'b',
  run = 'r',
  floaterm = 'F',
  fuzz = 'f',
}

local short_opts = 'a:ct:b:Fg'
local bench_opts = { '-benchmem', '-cpuprofile', 'profile.out' }

function M.make(...)
  local args = { ... }
  local winnr = vim.fn.win_getid()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local makeprg = vim.api.nvim_buf_get_option(bufnr, 'makeprg')

  local optarg, _, reminder = getopt.get_opts(args, short_opts, long_opts)
  log(makeprg, args, short_opts, optarg, reminder)
  if reminder and #reminder > 0 then
    -- expand % to current file
    for i, arg in ipairs(reminder) do
      if arg:find('%%') then
        if arg == '%' then
          reminder[i] = vim.fn.expand('%')
        elseif arg == '%:h' then
          reminder[i] = './' .. vim.fn.expand('%:h') .. '/...'
        else
          reminder[i] = vim.fn.expand(arg)
        end

        -- reminder[i] = arg:gsub("%%", vim.fn.expand("%"))
      end
    end
  end
  if vim.fn.empty(makeprg) == 0 and args[1] == 'go' then
    vim.notify(
      'makeprg is already set to ' .. makeprg .. ' args: ' .. vim.inspect(args),
      vim.log.levels.WARN
    )
  end
  -- local indent = "%\\%(    %\\)"
  if not makeprg then
    log('makeprog not setup')
    return
  end

  local runner = vim.split(makeprg, ' ')[1]

  if not require('go.install').install(runner) then
    util.warn('please wait for ' .. runner .. ' to be installed and re-run the command')
    return
  end

  local efm = [[%-G#\ %.%#]]
  if makeprg:find('go build') then
    vim.cmd([[setl errorformat=%-G#\ %.%#]])
    -- if makeprg:find("go build") then
    efm = compile_efm()
    if optarg['g'] then
      makeprg = makeprg .. ' -gcflags="all=-N -l"'
    end
  end
  -- end

  local runner = 'golangci-lint'
  if makeprg:find('golangci%-lint') then
    -- lint
    efm = efm .. [[,%A%\\%%(%[%^:]%\\+:\ %\\)%\\?%f:%l:%c:\ %m]]
    efm = efm .. [[,%A%\\%%(%[%^:]%\\+:\ %\\)%\\?%f:%l:\ %m]]

    local pwd = util.work_path()
    local cfg = pwd .. '.golangci.yml'

    if util.file_exists(cfg) then
      makeprg = makeprg .. [[\ -c\ ]] .. cfg
      -- vim.api.nvim_buf_set_option(bufnr, "makeprg", makeprg)
    end
  end
  local compile_test = false

  if makeprg:find('go run') then
    runner = 'go run'
    if args == nil or #args == 0 or (#args == 1 and args[1] == '-F') then
      makeprg = makeprg .. ' .'
    end
    efm = efm .. [[,%A%\\t%#%f:%l\ +0x%[0-9A-Fa-f]%\\+]]

    log('go run', makeprg)
  end

  if makeprg:find('go vet') then
    runner = 'go vet'
    if args == nil or #args == 0 then
      makeprg = makeprg .. ' .'
    end

    efm = compile_efm()
    efm = efm .. [[,%-Gexit\ status\ %\\d%\\+]]
  end

  if makeprg:find('generate') then
    if args == nil or #args == 0 then
      makeprg = makeprg .. ' ' .. vim.fn.expand('%')
    end
  end

  local cmd = vim.fn.split(makeprg, ' ')
  if optarg['t'] then
    local tag = optarg['t']
    local f = tag:find('=')
    if not f then
      table.insert(cmd, '-tags=' .. tag)
    else
      table.insert(cmd, '-tags=' .. tag:sub(f + 1))
    end
  end

  local bench = false
  if makeprg:find('go test') then
    -- log('go test')
    -- runner = 'go test'
    -- efm = compile_efm()
    -- if optarg['c'] then
    --   log('compile test')
    --   compile_test = true
    -- end
    -- for _, arg in ipairs(args) do
    --   --check if it is bench test
    --   if arg:find('-bench') then
    --     bench = true
    --   end
    -- end

    -- if optarg['v'] then
    --   table.insert(cmd, '-v')
    -- end

    -- if optarg['C'] then
    --   table.insert(cmd, '-coverprofile=' .. optarg['C'])
    -- end
    -- if optarg['f'] then
    --   log('fuzz test')
    --   table.insert(cmd, '-fuzz')
    -- end
    -- if optarg['n'] then
    --   table.insert(cmd, '-count=' .. optarg['n'])
    -- end
    -- if not bench and compile_test then
    --   table.insert(cmd, '-c')
    -- end
    -- if optarg['r'] then
    --   log('run test', optarg['r'])
    --   table.insert(cmd, '-run')
    --   table.insert(cmd, optarg['r'])
    -- end
    -- if optarg['b'] then
    --   log('build test flags', optarg['b'])
    --   table.insert(cmd, optarg['b'])
    -- end
  end

  if bench then
    cmd = vim.list_extend(cmd, args)
  elseif args and #args > 0 then
    cmd = vim.list_extend(cmd, reminder)
  end

  if optarg['a'] then
    if runner == 'go run' then
      table.insert(cmd, optarg['a'])
    else
      table.insert(cmd, '-args')
      table.insert(cmd, optarg['a'])
    end
  end

  if _GO_NVIM_CFG.run_in_floaterm or optarg['F'] then
    local term = require('go.term').run
    cmd = table.concat(cmd, ' ')
    term({ cmd = cmd, autoclose = false })
    return
  end
  return M.runjob(cmd, runner, efm, args)
end

local function handle_color(line)
  if tonumber(vim.fn.match(line, '\\%x1b\\[[0-9;]\\+')) < 0 then
    return line
  end
  if type(line) ~= 'string' then
    return line
  end
  line = vim.fn.substitute(line, '\\%x1b\\[[0-9;]\\+[mK]', '', 'g')
  log(line)
  return line
end

M.runjob = function(cmd, runner, args, efm)
  efm = efm or compile_efm()
  local failed = false
  local itemn = 1
  local lines = {}
  local errorlines = {}
  local cmdstr = vim.fn.join(cmd, ' ') -- cmd list run without shell, cmd string run with shell

  local package_path = (cmd[#cmd] or '')
  if package_path ~= nil then
    package_path = package_path .. util.sep()
    if vim.fn.isdirectory(package_path) == 1 then
      package_path = package_path .. '...'
    else
      package_path = ''
    end
  else
    package_path = ''
  end
  local Sprite = util.load_plugin('guihua.lua', 'guihua.sprite')
  local sprite
  if Sprite then
    sprite = Sprite:new({
      loc = 'top_center',
      syntax = 'lua',
      rect = { height = 1, width = 30 },
      data = { 'Running ' .. cmdstr },
      timeout = 20000,
      hl_line = 1,
    })
  else
    sprite = { on_close = function() end }
  end

  local function on_event(job_id, data, event)
    -- log("stdout", data, event)
    if event == 'stdout' then
      if data then
        for _, value in ipairs(data) do
          if value ~= '' then
            if value:find('=== RUN') or value:find('no test file') then
              goto continue
            end

            value = handle_color(value)
            if value:find('FAIL') then
              failed = true
              if value == 'FAIL' then
                goto continue
              end
            end
            local changed = false
            if vim.fn.empty(vim.fn.glob(args[#args])) == 0 then -- pkg name in args
              changed = true
              if value:find('FAIL') == nil then
                local p, _, _ = extract_filepath(value, package_path)
                if p == true then -- path existed, but need to attach the pkg name
                  -- log(fn, ln, package_path, package_path:gsub('%.%.%.', ''))
                  -- remove ... in package path
                  value = package_path:gsub('%.%.%.', '') .. util.ltrim(value)
                end
              end
            else
              local p, n = extract_filepath(value)

              log(p, n, #lines)
              if p == true then
                failed = true
                value = vim.fs.dirname(n) .. '/' .. util.ltrim(value)
                changed = true
                log(value)
              end
            end
            table.insert(lines, value)
            log(value, #lines)
            if itemn == 1 and failed and changed then
              itemn = #lines
            end
          end
          ::continue::
        end
      end
      _GO_NVIM_CFG.on_stdout(event, data)
    end

    if event == 'stderr' then
      if data then
        for _, value in ipairs(data) do
          if value ~= '' then
            table.insert(errorlines, value)
          end
        end
      end
      if next(errorlines) ~= nil and runner == 'golangci-lint' then
        efm =
          [[level=%tarning\ msg="%m:\ [%f:%l:%c:\ %.%#]",level=%tarning\ msg="%m",level=%trror\ msg="%m:\ [%f:%l:%c:\ %.%#]",level=%trror\ msg="%m",%f:%l:%c:\ %m,%f:%l:\ %m,%f:%l\ %m]]
      end

      sprite.on_close()

      _GO_NVIM_CFG.on_stderr(event, data)
    end

    if event == 'exit' then
      log('exit')
      sprite.on_close()
      if type(cmd) == 'table' then
        cmd = table.concat(cmd, ' ')
      end
      local info = cmd
      local level = vim.log.levels.INFO
      if #errorlines > 0 then
        if #lines > 0 then
          vim.list_extend(errorlines, lines)
        end
        trace(errorlines)
        vim.fn.setqflist({}, ' ', {
          title = cmd,
          lines = errorlines,
          efm = efm,
        })
        failed = true
        log(errorlines[1], job_id)
        vim.cmd([[echo v:shell_error]])
      elseif #lines > 0 then
        trace(lines)
        local opts = {}
        if _GO_NVIM_CFG.test_efm == true then
          efm = require('go.gotest').efm()
          opts = {
            title = cmd,
            lines = lines,
            efm = efm,
          }
        else
          opts = {
            title = cmd,
            lines = lines,
          }
        end
        vim.fn.setqflist({}, ' ', opts)
      end

      if tonumber(data) ~= 0 then
        failed = true
        info = info .. ' exited with code: ' .. tostring(data)
        level = vim.log.levels.ERROR
      end
      _GO_NVIM_CFG.job_id = nil
      if failed then
        cmd = cmd .. ' go test failed'
        level = vim.log.levels.WARN
        util.quickfix('botright copen')
      end

      itemn = 1
      if failed then
        vim.notify(info .. ' failed', level)
      else
        vim.notify(info .. ' succeed', level)
        vim.notify(table.concat(lines, '\n\r'), level)
      end
      failed = false
      _GO_NVIM_CFG.on_exit(event, data)
    end
    return cmd
  end

  -- releative dir does not work without shell
  log('cmd ', cmdstr)
  if is_windows then -- gitshell is more like cmd.exe
    cmdstr = cmd
  end
  _GO_NVIM_CFG.job_id = vim.fn.jobstart(cmdstr, {
    on_stderr = on_event,
    on_stdout = on_event,
    on_exit = on_event,
    stdout_buffered = true,
    stderr_buffered = true,
  })
  _GO_NVIM_CFG.on_jobstart(cmdstr)
end

M.stopjob = function(id)
  id = id or _GO_NVIM_CFG.job_id
  if id == nil then
    return
  end
  local r = vim.fn.jobstop(id)
  if r == 1 then
    _GO_NVIM_CFG.job_id = nil
  else
    util.warn('failed to stop job ' .. tostring(id))
  end
end
M.compile_efm = compile_efm
return M
