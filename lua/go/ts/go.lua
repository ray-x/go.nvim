M = {
  -- query_struct = "(type_spec name:(type_identifier) @definition.struct type: (struct_type))",
  query_package = "(package_clause (package_identifier)@package.name)@package.clause",

  query_struct_id = "(type_spec name:(type_identifier) @definition.struct  (struct_type))",

  query_em_struct_id = "(field_declaration name:(field_identifier) @definition.struct (struct_type))",

  query_struct_block = "(type_declaration (type_spec name:(type_identifier) @struct.name type: (struct_type)))@struct.declaration",

  query_em_struct_block = "(field_declaration name:(field_identifier)@struct.name type: (struct_type)) @struct.declaration",

  query_struct_block_from_id = "((type_spec name:(type_identifier) type: (struct_type)))@block.struct_from_id",

  --query_em_struct = "(field_declaration name:(field_identifier) @definition.struct type: (struct_type))",
  query_interface_id = [[(type_declaration (type_spec name:(type_identifier) @interface.name type:(interface_type)))@interface.declaration]],

  query_interface_method = [[(method_spec name: (field_identifier)@method.name)@interface.method.declaration]],

  query_func = "((function_declaration name: (identifier)@function.name) @function.declaration)",
  -- query_method = "(method_declaration receiver: (parameter_list (parameter_declaration name:(identifier)@method.receiver.name type:(type_identifier)@method.receiver.type)) name:(field_identifier)@method.name)@method.declaration"

  query_method_name = [[(method_declaration
     receiver: (parameter_list)@method.receiver
     name: (field_identifier)@method.name
     body:(block))@method.declaration]],

  query_method_void = [[(method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (pointer_type)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     body:(block)
  )@method.declaration]],

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

  query_method_single_ret = [[(method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (pointer_type)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (type_identifier)@method.result
     body:(block)
     )@method.declaration]],

  query_tr_method_void = [[(method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (type_identifier)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     body:(block)
  )@method.declaration]],

  query_tr_method_multi_ret = [[(method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (type_identifier)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (parameter_list)@method.result
     body:(block)
     )@method.declaration]],

  query_tr_method_single_ret = [[(method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (type_identifier)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (type_identifier)@method.result
     body:(block)
     )@method.declaration]]
}
function get_name_defaults()
    return {
        ["func"] = "function",
        ["if"] = "if",
        ["else"] = "else",
        ["for"] = "for",
    }
end

M.get_struct_node_at_pos = function(row, col)
  local query = require("go.ts.go").query_struct_block .. " " .. require("go.ts.go").query_em_struct_block

  local nodes = require("go.ts.nodes")
  local bufn = vim.fn.bufnr("")

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn, row, col)
  return ns[#ns]
end

M.get_interface_node_at_pos = function(row, col)
  local query = require("go.ts.go").query_interface_id
  local nodes = require("go.ts.nodes")
  local bufn = vim.fn.bufnr("")

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn, row, col)
  return ns[#ns]
end

M.get_interface_method_node_at_pos = function(row, col)
  local query = require("go.ts.go").query_interface_method
  local nodes = require("go.ts.nodes")
  local bufn = vim.fn.bufnr("")

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn, row, col)
  return ns[#ns]
end

M.get_func_method_node_at_pos = function(row, col)
  local query = require("go.ts.go").query_func .. " " .. require("go.ts.go").query_method_name
  -- local query = require("go.ts.go").query_method_name
  local nodes = require("go.ts.nodes")
  local bufn = vim.fn.bufnr("")

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn, row, col)
  if ns == nil then return nil end
  return ns[#ns]
end

M.get_package_node_at_pos = function(row, col)
  if row > 10 then return end
  local query = require("go.ts.go").query_package
  -- local query = require("go.ts.go").query_method_name
  local nodes = require("go.ts.nodes")
  local bufn = vim.fn.bufnr("")

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn, row, col)
  if ns == nil then return nil end
  return ns[#ns]
end

return M
