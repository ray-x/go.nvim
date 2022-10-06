local runner = require('go.runner')
local utils = require('go.utils')
local M = {}

local util = require('go.utils')
local log = util.log
local vfn = vim.fn
local api = vim.api

function M.watch(args)
  args = args or {}

  local cmd = { 'gotestsum', '--watch' }
  vim.list_extend(cmd, args)

  local opts = {
    update_buffer = true,
    on_exit = function()
      vim.schedule(function()
        vim.notify('watch stopped')
      end)
    end,
    on_chunk = function(err, lines)
      if err then return end
      for _, line in ipairs(lines) do
        if line:match('Errors') then
          vim.notify(vfn.join(lines, ', ' ), vim.lsp.log_levels.ERROR)
          return
        elseif line:match('PASS') or line:match('DONE') then
          vim.notify(line, vim.lsp.log_levels.INFO)
        end
      end

    end
  }
  runner.run(cmd, opts)
  return cmd, opts
end

local test_result = {}
local test_panel
local show_panel = function()
  local panel = util.load_plugin('guihua.lua', 'guihua.panel')
  if not panel then
    vim.notify('guihua not installed')
    return
  end
  if test_panel == nil or not test_panel:is_open() then
    test_panel = panel:new({
      header = '    go test   ',
      render = function(buf)
        -- log(test_result)
        return test_result
      end,
    })

    test_panel:open(true)
  else
    test_panel:redraw(false)
  end
  return test_panel
end

local function handle_data_out(_, data, ev)
  data = util.handle_job_data(data)
  if not data then
    return
  end
  local get_fname_num = utils.get_fname_num
  for _, val in ipairs(data) do
    -- first strip the filename
    local item = {}
    -- item.lnum = 1
    item.text = val
    item.node_text = val
    local fname, lnum = get_fname_num(val)

    if fname then
      local bnr = vfn.bufnr(fname, true)
      item.bufnr = bnr
      item.lnum = lnum
      if bnr > 0 then
        item.uri = vim.uri_from_bufnr(bnr)
      end
      item.fname = fname
      item.lnum = lnum
    end
    -- item.filename = fname
    table.insert(test_result, item)
    log(item)
  end
  return show_panel()
end

function M.run(...)
  if not require('go.install').install('gotestsum') then
    util.warn('please wait for gotstssum to be installed and re-run the command')
    return
  end
  local args = { ... }
  test_result = {}
  log(debug.traceback())

  local cmd = { 'gotestsum', unpack(args) }

  vfn.jobstart(cmd, {
    on_stdout = handle_data_out,
    on_exit = function(e, data, _)
      if data ~= 0 then
        log('no packege info data ' .. e .. tostring(data))
        return
      end
      -- show_panel()
    end,
  })
  return test_result
end

return M
