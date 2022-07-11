(
 (const_spec
  name: (identifier) @_id
  value: (expression_list (raw_string_literal) @sql))

 (#contains? @_id "Query")
)

((composite_literal
  type: (type_identifier) @_type
  body: (literal_value
      (keyed_element
        (literal_element) @_key
        (literal_element) @lua)))
    (#eq? @_key "overrideScript")
    (#eq? @_type "generatorTestCase"))
