-- first version: from https://github.com/arsham/shark
local ls = require('luasnip')
local fmt = require('luasnip.extras.fmt').fmt
local ok, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
if not ok then
  local ok, packer = pcall(require, 'packer')
  if ok then
    require('packer').loader('nvim-treesitter')
  else
    local ok, lazy = pcall(require, 'lazy')
    if lazy then
      lazy.load({ plugins = { 'nvim-treesitter' } })
    else
      error('Please install nvim-treesitter')
    end
  end
  ts_utils = require('nvim-treesitter.ts_utils')
end
local ts_locals = require('nvim-treesitter.locals')
local rep = require('luasnip.extras').rep
local ai = require('luasnip.nodes.absolute_indexer')

local M = {}

M.go_err_snippet = function(args, _, _, spec)
  local err_name = args[1][1]
  local index = spec and spec.index or nil
  local msg = spec and spec[1] or ""
  if spec and spec[2] then
    err_name = err_name .. spec[2]
  end
  return ls.sn(index, {
    ls.c(1, {
      ls.sn(nil, fmt('fmt.Errorf("{}: %w", {})', { ls.i(1, msg), ls.t(err_name) })),
      -- ls.sn(nil, fmt('fmt.Errorf("{}", {}, {})', { ls.t(err_name), ls.i(1, msg), ls.i(2) })),
      ls.sn(
        nil,
        fmt('internal.GrpcError({},\n\t\tcodes.{}, "{}", "{}", {})', {
          ls.t(err_name),
          ls.i(1, 'Internal'),
          ls.i(2, 'Description'),
          ls.i(3, 'Field'),
          ls.i(4, 'fields'),
        })
      ),
      ls.t(err_name),
    }),
  })
end

---Transform makes a node from the given text.
local function transform(text, info)
  local string_sn = function(template, default)
    info.index = info.index + 1
    return ls.sn(info.index, fmt(template, ls.i(1, default)))
  end
  local new_sn = function(default)
    return string_sn('{}', default)
  end

  -- cutting the name if exists.
  if text:find([[^[^\[]*string$]]) then
    text = 'string'
  elseif text:find('^[^%[]*map%[[^%]]+') then
    text = 'map'
  elseif text:find('%[%]') then
    text = 'slice'
  elseif text:find([[ ?chan +[%a%d]+]]) then
    return ls.t('nil')
  end

  -- separating the type from the name if exists.
  local type = text:match([[^[%a%d]+ ([%a%d]+)$]])
  if type then
    text = type
  end

  if text == 'int' or text == 'int64' or text == 'int32' then
    return new_sn('0')
  elseif text == 'float32' or text == 'float64' then
    return new_sn('0')
  elseif text == 'error' then
    if not info then
      return ls.t('err')
    end

    info.index = info.index + 1
    return M.go_err_snippet({ { info.err_name } }, nil, nil, { index = info.index })
  elseif text == 'bool' then
    info.index = info.index + 1
    return ls.c(info.index, { ls.i(1, 'false'), ls.i(2, 'true') })
  elseif text == 'string' then
    return string_sn('"{}"', '')
  elseif text == 'map' or text == 'slice' then
    return ls.t('nil')
  elseif string.find(text, '*', 1, true) then
    return new_sn('nil')
  end

  text = text:match('[^ ]+$')
  if text == 'context.Context' then
    text = 'context.Background()'
  else
    -- when the type is concrete
    text = text .. '{}'
  end

  return ls.t(text)
end

local get_node_text = vim.treesitter.get_node_text

local handlers = {
  parameter_list = function(node, info)
    local result = {}

    local count = node:named_child_count()
    for idx = 0, count - 1 do
      table.insert(result, transform(get_node_text(node:named_child(idx), 0), info))
      if idx ~= count - 1 then
        table.insert(result, ls.t({ ', ' }))
      end
    end

    return result
  end,

  type_identifier = function(node, info)
    local text = get_node_text(node, 0)
    return { transform(text, info) }
  end,
}

local query_is_set = false

local function set_query()
  if query_is_set then
    return
  end
  query_is_set = true
  vim.treesitter.query.set(
    'go',
    'LuaSnip_Result',
    [[
      [
        (method_declaration result: (_) @id)
        (function_declaration result: (_) @id)
        (func_literal result: (_) @id)
      ]
  ]]
  )
end

local function return_value_nodes(info)
  set_query()
  local cursor_node = ts_utils.get_node_at_cursor()
  local scope_tree = ts_locals.get_scope_tree(cursor_node, 0)

  local function_node
  for _, scope in ipairs(scope_tree) do
    if scope:type() == 'function_declaration'
        or scope:type() == 'method_declaration'
        or scope:type() == 'method_declaration'
        or scope:type() == 'func_literal'
    then
      function_node = scope
      break
    end
  end

  if not function_node then
    return
  end

  local query = (vim.fn.has('nvim-0.9') == 1) and vim.treesitter.query.get('go', 'LuaSnip_Result')
  for _, node in query:iter_captures(function_node, 0) do
    if handlers[node:type()] then
      return handlers[node:type()](node, info)
    end
  end
  return ls.t({ '' })
end

local is_in_function = require('go.ts.go').in_func()

---Transforms the given arguments into nodes wrapped in a snippet node.
M.make_return_nodes = function(args)
  local info = { index = 0, err_name = args[1][1] }

  return ls.sn(nil, return_value_nodes(info))
end
M.make_default_return_nodes = function()
  local info = { index = 0, err_name = 'nil' }

  return ls.sn(nil, return_value_nodes(info))
end

M.fill_return = function()
  local info = { index = 0, err_name = 'nil' }
  return ls.sn(nil, return_value_nodes(info))
end

---Runs the command in shell.
-- @param command string
-- @return table
M.shell = require('go.utils').run_command

M.last_lua_module_section = function(args)
  local text = args[1][1] or ''
  local split = vim.split(text, '.', { plain = true })

  local options = {}
  for len = 0, #split - 1 do
    local node = ls.t(table.concat(vim.list_slice(split, #split - len, #split), '_'))
    table.insert(options, node)
  end

  return ls.sn(nil, {
    ls.c(1, options),
  })
end

function M.is_in_test_file()
  local filename = vim.fn.expand('%:p')
  return vim.endswith(filename, '_test.go')
end

function M.is_in_test_function()
  return M.is_in_test_file() and is_in_function()
end

M.create_t_run = function(args)
  return ls.sn(1, {
    ls.c(1, {
      ls.t({ '' }),
      ls.sn(
        nil,
        fmt('\tt.Run("{}", {}{})\n{}', {
          ls.i(1, 'Case'),
          ls.t(args[1]),
          rep(1),
          ls.d(2, M.create_t_run, ai[1]),
        })
      ),
    }),
  })
end

M.mirror_t_run_funcs = function(args)
  local strs = {}
  for _, v in ipairs(args[1]) do
    local name = v:match('^%s*t%.Run%s*%(%s*".*", (.*)%)')
    if name then
      local node = string.format('func %s(t *testing.T) {{\n\tt.Parallel()\n}}\n\n', name)
      table.insert(strs, node)
    end
  end
  local str = table.concat(strs, '')
  if #str == 0 then
    return ls.sn(1, ls.t(''))
  end
  return ls.sn(1, fmt(str, {}))
end

return M
