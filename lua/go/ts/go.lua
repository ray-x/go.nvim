local nodes = require('go.ts.nodes')

local tsutil = require('nvim-treesitter.ts_utils')
local log = require('go.utils').log
local warn = require('go.utils').warn
local info = require('go.utils').info
local debug = require('go.utils').debug
debug = log

local M = {
  query_struct = '(type_spec name:(type_identifier) @definition.struct type: (struct_type))',
  query_package = '(package_clause (package_identifier)@package.name)@package.clause',
  query_struct_id = '(type_spec name:(type_identifier) @definition.struct  (struct_type))',
  query_em_struct_id = '(field_declaration name:(field_identifier) @definition.struct (struct_type))',
  query_struct_block = [[((type_declaration (type_spec name:(type_identifier) @struct.name type: (struct_type)))@struct.declaration)]],
  query_struct_block_type = [[((type_spec name:(type_identifier) @struct.name type: (struct_type))@struct.declaration)]],  -- type(struct1, struct2)
  -- query_type_declaration = [[((type_declaration (type_spec name:(type_identifier)@type_decl.name type:(type_identifier)@type_decl.type))@type_decl.declaration)]], -- rename to gotype so not confuse with type
  query_type_declaration = [[((type_declaration (type_spec name:(type_identifier)@type_decl.name)))]],
  query_em_struct_block = [[(field_declaration name:(field_identifier)@struct.name type: (struct_type)) @struct.declaration]],
  query_struct_block_from_id = [[(((type_spec name:(type_identifier) type: (struct_type)))@block.struct_from_id)]],
  -- query_em_struct = "(field_declaration name:(field_identifier) @definition.struct type: (struct_type))",
  query_interface_id = [[((type_declaration (type_spec name:(type_identifier) @interface.name type:(interface_type)))@interface.declaration)]],
  -- query_interface_method = [[((method_spec name: (field_identifier)@method.name)@interface.method.declaration)]],
  query_interface_method = [[((method_elem name: (field_identifier)@method.name)@interface.method.declaration)]], --
  -- this is a breaking change require TS parser update
  query_func = '((function_declaration name: (identifier)@function.name) @function.declaration)',
  query_method = '(method_declaration receiver: (parameter_list (parameter_declaration name:(identifier)@method.receiver.name type:(type_identifier)@method.receiver.type)) name:(field_identifier)@method.name)@method.declaration',
  query_method_name = [[((method_declaration
     receiver: (parameter_list)@method.receiver
     name: (field_identifier)@method.name
     body:(block))@method.declaration)]],
  query_method_void = [[((method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (pointer_type)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     body:(block)
  )@method.declaration)]],
  query_method_multi_ret = [[(method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (pointer_type)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (parameter_list)@method.result
     body:(block)
     )@method.declaration]],
  query_method_single_ret = [[((method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (pointer_type)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (type_identifier)@method.result
     body:(block)
     )@method.declaration)]],
  query_tr_method_void = [[((method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (type_identifier)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     body:(block)
  )@method.declaration)]],
  query_tr_method_multi_ret = [[((method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (type_identifier)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (parameter_list)@method.result
     body:(block)
     )@method.declaration)]],
  query_tr_method_single_ret = [[((method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (type_identifier)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (type_identifier)@method.result
     body:(block)
     )@method.declaration)]],
  query_test_func = [[((function_declaration name: (identifier) @test_name
        parameters: (parameter_list
            (parameter_declaration
                     name: (identifier)
                     type: (pointer_type
                         (qualified_type
                          package: (package_identifier) @_param_package
                          name: (type_identifier) @_param_name))))
         ) @testfunc
      (#contains? @test_name "Test"))]],
  query_tbl_testcase_node = [[ ( literal_value (
      literal_element (
        literal_value .(
          keyed_element
            (literal_element (identifier))
            (literal_element (interpreted_string_literal) @test.name)
         )
       ) @test.block
    ))
  ]],
  query_sub_testcase_node = [[ (call_expression
    (selector_expression
      (field_identifier) @method.name)
    (argument_list
      (interpreted_string_literal) @tc.name
      (func_literal) )
    (#eq? @method.name "Run")
  ) @tc.run ]],
  query_string_literal = [[((interpreted_string_literal) @string.value)]],
}

local function get_name_defaults()
  return { ['func'] = 'function', ['if'] = 'if', ['else'] = 'else', ['for'] = 'for' }
end

M.get_struct_node_at_pos = function(bufnr)
  local query = M.query_struct_block .. ' ' .. M.query_em_struct_block .. ' ' .. M.query_struct_block_type
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn)
  if ns == nil then
    debug('struct not found')
  else
    log('struct node', ns)
    return ns[#ns]
  end
end

M.get_type_node_at_pos = function(bufnr)
  local query = M.query_type_declaration
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn)
  if ns == nil then
    debug('type not found')
  else
    log('type node', ns)
    return ns[#ns]
  end
end

M.get_interface_node_at_pos = function(bufnr)
  local query = M.query_interface_id

  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn)
  if ns == nil then
    debug('interface not found')
  else
    return ns[#ns]
  end
end

M.get_interface_method_node_at_pos = function(bufnr)
  local query = M.query_interface_method
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufnr)
  if ns == nil then
    warn('interface method not found')
  else
    return ns[#ns]
  end
end

M.get_func_method_node_at_pos = function(bufnr)
  local query = M.query_func .. ' ' .. M.query_method_name
  -- local query = require("go.ts.go").query_method_name

  local bufn = bufnr or vim.api.nvim_get_current_buf()

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn)
  if ns == nil then
    warn('function not found')
    return nil
  end
  return ns[#ns]
end

M.get_tbl_testcase_node_name = function(bufnr)
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufn)
  if not parser then
    return warn('treesitter parser not found')
  end
  local tree = parser:parse()
  tree = tree[1]

  local tbl_case_query = vim.treesitter.query.parse('go', M.query_tbl_testcase_node)

  local curr_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  for _, match, _ in tbl_case_query:iter_matches(tree:root(), bufn, 0, -1) do
    local tc_name = nil
    for id, node in pairs(match) do
      local name = tbl_case_query.captures[id]
      -- IDK why test.name is captured before test.block
      if name == 'test.name' then
        tc_name = vim.treesitter.get_node_text(node, bufn)
      end

      if name == 'test.block' then
        local start_row, _, end_row, _ = node:range()
        if (curr_row >= start_row and curr_row <= end_row) then
          return tc_name
        end
      end
    end
  end
  return nil
end

M.get_sub_testcase_name = function(bufnr)
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufn)
  if not parser then
    return warn('treesitter parser not found')
  end

  local sub_case_query = vim.treesitter.query.parse('go', M.query_sub_testcase_node)
  local tree = parser:parse()
  tree = tree[1]

  local is_inside_test = false
  local curr_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  for id, node in sub_case_query:iter_captures(tree:root(), bufn, 0, -1) do
    local name = sub_case_query.captures[id]
    -- tc_run is the first capture of a match, so we can use it to check if we are inside a test
    if name == 'tc.run' then
      local start_row, _, end_row, _ = node:range()
      if (curr_row >= start_row and curr_row <= end_row) then
        is_inside_test = true
      else
        is_inside_test = false
      end
      goto continue
    end
    if name == 'tc.name' and is_inside_test then
      return vim.treesitter.get_node_text(node, bufn)
    end
    ::continue::
  end
  return nil
end

M.get_string_node = function(bufnr)
  local query = M.query_string_literal
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn, 'value')
  if ns == nil then
    debug('struct not found')
  else
    log('struct node', ns[#ns])
    return ns[#ns]
  end
end

M.get_import_node_at_pos = function(bufnr)
  local bufn = bufnr or vim.api.nvim_get_current_buf()

  local cur_node = tsutil.get_node_at_cursor()

  if cur_node and (cur_node:type() == 'import_spec' or cur_node:parent():type() == 'import_spec') then
    return cur_node
  end
end

M.get_module_at_pos = function(bufnr)
  local node = M.get_import_node_at_pos(bufnr)
  if node then
    local module = vim.treesitter.get_node_text(node, vim.api.nvim_get_current_buf())
    -- log
    module = string.gsub(module, '"', '')
    return module
  end
end

M.get_package_node_at_pos = function(bufnr)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  if row > 10 then
    return
  end
  local query = M.query_package
  -- local query = require("go.ts.go").query_method_name

  local bufn = bufnr or vim.api.nvim_get_current_buf()

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn)
  if ns == nil then
    warn('package not found')
  else
    return ns[#ns]
  end
end

function M.in_func()
  local ok, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
  if not ok then
    return false
  end
  local current_node = ts_utils.get_node_at_cursor()
  if not current_node then
    return false
  end
  local expr = current_node

  while expr do
    if expr:type() == 'function_declaration' or expr:type() == 'method_declaration' then
      return true
    end
    expr = expr:parent()
  end
  return false
end

return M
