local eq = assert.are.same
local input = {
  'package a',
  '',
  'type x struct {',
  '\tFoo int',
  '\tbar int',
  '\ty struct {',
  '\t\tFoo int',
  '\t\tbar int',
  '\t}',
  '}',
  'type z struct{}',
}
local status
local default = {
  ['function'] = 'func',
  ['method'] = 'func',
  ['struct'] = 'struct',
  ['interface'] = 'interface',
}

local output_inner = {
  'package a',
  '',
  'type x struct {',
  '\tFoo int `xx:"foo"`',
  '\tbar int `xx:"bar"`',
  'y struct {',
  '\t\tFoo int `xx:"foo"`',
  '\t\tbar int `xx:"bar"`',
  '}',
  '',
}

local cur_dir = vim.fn.expand('%:p:h')

describe('should get nodes  ', function()
  vim.cmd([[silent exe 'e tags.go']])
  vim.fn.append(0, input)
  vim.cmd([[w]])
  local bufn = vim.fn.bufnr('')
  require('plenary.reload').reload_module('go.nvim')
  require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')

  -- _GO_NVIM_CFG.verbose = true
  local nodes = require('go.ts.nodes')

  it('get all nodes should get struct x', function()
    vim.fn.setpos('.', { bufn, 4, 1, 0 })
    local query = require('go.ts.go').query_struct_block
    local ns = nodes.get_all_nodes(query, 'go', default, bufn)
    eq('x', ns[1].name)
  end)
  it('it should get struct y', function()
    vim.fn.setpos('.', { bufn, 8, 1, 0 })
    local query = require('go.ts.go').query_struct_block .. require('go.ts.go').query_em_struct_block
    -- local query = require('go.ts.go').query_em_struct
    local ns = nodes.get_all_nodes(query, 'go', default, bufn)
    eq('y', ns[2].name)
  end)
  it('node at cursor should get struct x', function()
    vim.fn.setpos('.', { bufn, 4, 1, 0 })
    local query = require('go.ts.go').query_struct_block
    local ns = nodes.nodes_at_cursor(query, default, bufn)
    print(vim.inspect(ns))
    eq('x', ns[1].name)
  end)
  it('it should get struct y', function()
    vim.fn.setpos('.', { bufn, 8, 1, 0 })
    local query = require('go.ts.go').query_struct_block .. require('go.ts.go').query_em_struct_block
    -- local query = require('go.ts.go').query_em_struct
    local ns = nodes.nodes_at_cursor(query, default, bufn)
    eq('y', ns[#ns].name)
  end)
  it('struct at pos should get struct y', function()
    vim.fn.setpos('.', { bufn, 8, 4, 0 })
    local ns = require('go.ts.go').get_struct_node_at_pos()
    print(vim.inspect(ns))
    eq('y', ns.name)
  end)
end)
describe('should get nodes for play list ', function()
  local fix_path = cur_dir .. '/lua/tests/fixtures/ts/playlist.go' -- %:p:h ? %:p
  local lines = vim.fn.readfile(fix_path)
  require('plenary.reload').reload_module('go.nvim')
  require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')

  -- local name = vim.fn.tempname() .. '.go'
  -- print('play list tmp:' .. name)
  --
  print('play list test:' .. fix_path)
  -- vim.fn.writefile(lines, name)
  local cmd = " silent exe 'e " .. fix_path .. "'"
  vim.cmd(cmd)

  local bufn = vim.fn.bufnr('')

  -- _GO_NVIM_CFG.verbose = true
  local nodes = require('go.ts.nodes')
  it('should get function name', function()
    vim.fn.setpos('.', { bufn, 21, 5, 0 })
    local ns = require('go.ts.go').get_func_method_node_at_pos()
    print(vim.inspect(ns))
    eq('createPlaylist', ns.name)
  end)
  it('should get method (with par list) name', function()
    vim.fn.setpos('.', { bufn, 33, 21, 0 })
    local ns = require('go.ts.go').get_func_method_node_at_pos()
    print(vim.inspect(ns))
    eq('addSong', ns.name)
  end)
  it('should get method (no par) name', function()
    vim.fn.setpos('.', { bufn, 48, 3, 0 })
    local ns = require('go.ts.go').get_func_method_node_at_pos()
    print(vim.inspect(ns))
    eq('showAllSongs', ns.name)
  end)
end)

describe('should get nodes for interface ', function()
  local path = cur_dir .. '/lua/tests/fixtures/ts/interfaces.go' -- %:p:h ? %:p
  -- local name = vim.fn.tempname() .. '.go'
  -- print('interface tmp:' .. name)
  -- print('interface test:' .. path)
  -- local lines = vim.fn.readfile(path)
  -- vim.fn.writefile(lines, name)
  local cmd = " silent exe 'e " .. path .. "'"
  vim.cmd(cmd)
  local bufn = vim.fn.bufnr('')
  it('should get interface name', function()
    vim.fn.setpos('.', { bufn, 11, 6, 0 })
    local ns = require('go.ts.go').get_interface_node_at_pos()
    print(vim.inspect(ns))
    eq('Geometry', ns.name)
  end)
  it('should get interface method name', function()
    vim.fn.setpos('.', { bufn, 11, 5, 0 })
    local ns = require('go.ts.go').get_interface_method_node_at_pos()
    print(vim.inspect(ns))
    eq('Area', ns.name)
  end)
  it('should get package name', function()
    vim.fn.setpos('.', { bufn, 3, 5, 0 })
    local ns = require('go.ts.go').get_package_node_at_pos()
    print(vim.inspect(ns))
    eq('main', ns.name)
  end)
  it('should get package name', function()
    vim.fn.setpos('.', { bufn, 3, 1, 0 })
    local ns = require('go.ts.go').get_package_node_at_pos()
    print(vim.inspect(ns))
    eq('main', ns.name)
  end)
end)

describe('should get nodes for import golden ', function()
  local path = cur_dir .. '/lua/tests/fixtures/fmt/goimports2_golden.go' -- %:p:h ? %:p
  it('should get module name', function()
    -- local name = vim.fn.tempname() .. '.go'
    -- print('tmp:' .. name)

    -- print('test:' .. path)
    -- local lines = vim.fn.readfile(path)
    -- vim.fn.writefile(lines, name)
    local cmd = " silent exe 'e " .. path .. "'"
    print('cmd:', cmd)
    vim.cmd(cmd)

    require('plenary.reload').reload_module('go.nvim')
    require('plenary.reload').reload_module('nvim-treesitter/nvim-treesitter')

    local bufn = vim.fn.bufnr('')
    vim.fn.setpos('.', { bufn, 4, 4, 0 })
    print('hl1', vim.inspect(require('vim.treesitter.highlighter')))
    vim.treesitter.stop()
    vim.treesitter.start()
    local buf = vim.api.nvim_win_get_buf(0)

    local root_lang_tree = vim.treesitter.get_parser(buf, 'go')
    -- read current line
    print('current line', vim.api.nvim_get_current_line(), vim.o.filetype, buf)

    root_lang_tree:parse()
    print('highlighter', vim.inspect(vim.treesitter.highlighter))
    local ns = require('go.ts.go').get_module_at_pos()
    print('module node: ', vim.inspect(ns))
    eq('fmt', ns)
  end)
end)
