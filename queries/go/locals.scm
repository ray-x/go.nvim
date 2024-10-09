; extends

(var_spec) @local.scope

(field_declaration
  name: (field_identifier) @local.definition.field)

(method_elem
  name: (field_identifier) @function.method.name
  parameters: (parameter_list) @function.method.parameter_list) @local.interface.method.declaration

(type_declaration
  (type_spec
    name: (type_identifier) @local.name
    type: [(struct_type) (interface_type)] @local.type)) @local.start
