;; extends match Query and json
(
 (const_spec
  name: (identifier) @_id
  value: (expression_list (raw_string_literal) @sql))

 (#contains? @_id "Query")
)

(
 (const_spec
  name: (identifier) @_id
  value: (expression_list (raw_string_literal) @json))

 (#contains? @_id "Json")
)


(short_var_declaration
    left: (expression_list
            (identifier) @_id (#match? @_id "Query"))
    right: (expression_list
             (raw_string_literal) @sql (#offset! @sql 0 1 0 -1))
)


(short_var_declaration
    left: (expression_list
            (identifier) @_id (#match? @_id "Json"))
    right: (expression_list
             (raw_string_literal) @json (#offset! @json 0 1 0 -1))
)

((composite_literal
  type: (type_identifier) @_type
  body: (literal_value
      (keyed_element
        (literal_element) @_key
        (literal_element) @lua)))
    (#eq? @_key "overrideScript")
    (#eq? @_type "generatorTestCase"))
