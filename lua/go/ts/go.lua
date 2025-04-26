local nodes = require('go.ts.nodes')

local tsutil = require('nvim-treesitter.ts_utils')
local log = require('go.utils').log
local warn = require('go.utils').warn
local info = require('go.utils').info
local debug = require('go.utils').debug
local trace = require('go.utils').trace

local api = vim.api

local parsers = require "nvim-treesitter.parsers"
local utils = require "nvim-treesitter.utils"
local ts = vim.treesitter
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
            (literal_element (interpreted_string_literal))
        )
      ) @test.block
    ))]],
  query_tbl_kv_node = [[ (
          keyed_element
            (literal_element (identifier) @test.nameid)
            (literal_element (interpreted_string_literal) @test.name)
        ) @test.kvblock]],
  query_sub_testcase_node = [[ (call_expression
    (selector_expression
      (field_identifier) @method.name)
    (argument_list
      (interpreted_string_literal) @tc.name
      (func_literal) )
    (#eq? @method.name "Run")
  ) @tc.run ]],
  query_string_literal = [[((interpreted_string_literal) @string.value)]],
  ginkgo_query = [[
  (call_expression
    function: (identifier) @func_name (#any-of? @func_name "It" "Describe" "Context")
    arguments: (argument_list
      (interpreted_string_literal) @test_name
      (func_literal) @test_body))
  ]],
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
    debug('function not found')
    return nil
  end
  return ns[#ns]
end

M.is_position_in_node = function(node, row, col)
  if not row and not col then
    row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1
  end
  if not col then
    col = 0
  end
  local start_row, start_col, end_row, end_col = node:range()
  if row < start_row or (row == start_row and col < start_col) then
    return false
  end
  if row > end_row or (row == end_row and col > end_col) then
    return false
  end
  return true
end

M.get_tbl_testcase_node_name = function(bufnr)
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufn, 'go')
  if not parser then
    return warn('treesitter parser not found for' .. vim.fn.bufname(bufn))
  end
  if vim.fn.has('nvim-0.11') ~= 1 then
    return warn('please update to nvim 0.11 or later')
  end
  local tree = parser:parse()
  tree = tree[1]

  local tbl_case_query = vim.treesitter.query.parse('go', M.query_tbl_testcase_node)
  local tbl_case_kv_query = vim.treesitter.query.parse('go', M.query_tbl_kv_node)

  local curr_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  curr_row = curr_row - 1
  for pattern, match, metadata in tbl_case_query:iter_matches(tree:root(), bufn, 0, -1) do
    -- first: find the @test.block
    for id, nodes in pairs(match) do
      local name = tbl_case_query.captures[id] or tbl_case_query.captures[pattern]
      local get_tc_block = function(node, range_checker)
        if name == 'test.block' then
          local start_row, _, end_row, _ = node:range()

          if not range_checker(start_row, end_row, curr_row) then
            -- no need to check the range
            return
          end
          trace(name, tc_name, start_row, end_row, curr_row)
          return true
        end
      end
      for _, node in pairs(nodes) do

        local n = get_tc_block(node, function(start_row, end_row, curr_row)
          if (start_row <= curr_row and curr_row <= end_row) then -- curr_row starts from 1
            trace('valid node:', node)  -- the nvim manual is out of sync for release version
            return true -- cursor is in the same line, this is a strong match
          end
        end)
        if n then
          -- return n
          local tc_name, guess

          local start_row, _, end_row, _ = node:range()
          local result = {}
          -- find kv nodes inside test case struct
          for pattern2, match2, _ in tbl_case_kv_query:iter_matches(tree:root(), bufn, start_row, end_row+1) do
            local id
            for i2, nodes2 in pairs(match2) do
              local name2 = tbl_case_kv_query.captures[i2] -- or tbl_case_kv_query.captures[pattern2]
              for i, n2 in pairs(nodes2) do -- the order is abit random
                -- if name2 == 'test.name' then
                local start_row2, _, end_row2, _ = n2:range()
                if name2 == 'test.nameid' then
                  id =  vim.treesitter.get_node_text(n2, bufn)
                  if id == 'name' then
                    result[name2] = id
                  end
                elseif name2 == 'test.name' then
                  local tc_name2 = vim.treesitter.get_node_text(n2, bufn)
                  if id == 'name' then
                    log('found node', name2, tc_name2)
                    tc_name = tc_name2
                  elseif start_row2 <= curr_row and curr_row <= end_row2 then -- curr_row starts
                    guess = tc_name2
                  end
                else
                  trace('found node', name2, n2:range())
                end

                trace('node type name',i2, i, name2, id, start_row2, end_row2, curr_row, tc_name, guess)
              end
            end
          end
          local testcase = tc_name or guess
          if testcase then
            testcase = string.gsub(testcase, '"', '')
            return testcase
          else
            debug('testcase not found')
          end
        end
      end
    end
  end
  return nil
end

M.get_sub_testcase_name = function(bufnr)
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufn, 'go')
  if not parser then
    return warn('treesitter parser not found for ' .. vim.fn.bufname(bufn))
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
      if (start_row < curr_row  and curr_row <= end_row + 1) then
        is_inside_test = true
      else
        is_inside_test = false
      end
      goto continue
    end
    if name == 'tc.name' and is_inside_test then

      return string.gsub(vim.treesitter.get_node_text(node, bufn), '"', '')
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
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cur_node = tsutil.get_node_at_cursor(0, true)
  if not cur_node then
    vim.notify('cursor not in a node or TS parser not init correctly', vim.log.levels.INFO)
    return
  end


  local parent_is_import = function(node)
    local n = node
    while n do
      if n:type() == 'import_spec' then
        return true
      end
      n = n:parent()
    end
  end

  if parent_is_import(cur_node) then
    return cur_node
  end
end

M.get_module_at_pos = function(bufnr)
  local node = M.get_import_node_at_pos(bufnr)
  log(node)
  if node then
    local module = vim.treesitter.get_node_text(node, vim.api.nvim_get_current_buf())
    module = string.gsub(module, '"', '')
    log('module', vim.inspect(module))
    return module
  else
    warn('module not found')
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
