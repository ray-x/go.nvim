(field_declaration
  name: (field_identifier) @definition.field)

(method_spec
  name: (field_identifier) @method.name
  parameters:(parameter_list) @method.parameter_list
)@interface.method.declaration


(var_spec) @scope
