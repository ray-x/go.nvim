;; extends

; inject sql into any const string with word query in the name
; e.g. const query = `SELECT * FROM users WHERE name = 'John'`;

(
 (const_spec
  name: (identifier) @_id
  value: (expression_list (raw_string_literal) @injection.content))

 (#match? @_id ".*[Q|q]uery.*")
 (#set! injection.language "sql")
)

(short_var_declaration
    left: (expression_list
            (identifier) @_id (#match? @_id ".*[Q|q]uery.*"))
    right: (expression_list
             (raw_string_literal) @sql (#offset! @sql 0 1 0 -1))
)


; inject sql in single line strings
; e.g. db.GetContext(ctx, "SELECT * FROM users WHERE name = 'John'")
(call_expression
  (selector_expression
    field: (field_identifier) @_field (#any-of? @_field "Exec" "GetContext" "ExecContext" "SelectContext" "In" "RebindNamed" "Rebind" "QueryRowxContext" "NamedExec"))
  (argument_list
    (interpreted_string_literal) @sql)
    (#offset! @sql 0 1 0 -1))

; ----------------------------------------------------------------

; Go code example with interpreted string literal
; query := fmt.Sprintf("UPDATE task SET %s = ? WHERE id = ?", field)
(short_var_declaration
    left: (expression_list) @_left (#eq? @_left "query")
    right: (expression_list
        (call_expression
            function: (selector_expression
                operand: (identifier) @_operand (#eq? @_operand "fmt")
                field: (field_identifier) @_field (#eq? @_field "Sprintf")
            )
            arguments: (argument_list
                (interpreted_string_literal) @sql
            )
        )
    )
)

; ----------------------------------------------------------------

; Go code example with interpreted string literal and type identifier
; var query string = fmt.Sprintf("SELECT * from kkk WHERE id = ?", bb)

(var_declaration
    (var_spec
        name: (identifier) @_name (#match? @_name "[Q|q]uery")
        value: (expression_list
            (call_expression
                function: (selector_expression
                    operand: (identifier) @_operand (#eq? @_operand "fmt")
                    field: (field_identifier) @_field (#eq? @_field "Sprintf")
                )
                arguments: (argument_list
                    (interpreted_string_literal) @sql
                )
            )
        )
    )
)

; ----------------------------------------------------------------

; Go code example with interpreted string literal and type identifier:
; var query string = "SELECT * FROM books"

(var_declaration
    (var_spec
        name: (identifier) @_name (#match? @_name "[Q|q]uery")
        value: (expression_list
            (interpreted_string_literal) @sql
        )
    )
)

; ----------------------------------------------------------------
; a general query injection
(((
  [(interpreted_string_literal)
    (raw_string_literal)] @sql
      (#match? @sql "(SELECT|select|INSERT|insert|UPDATE|update|DELETE|delete).+(FROM|from|INTO|into|VALUES|values|SET|set).*(WHERE|where|GROUP BY|group by)?"
))))

; ----------------------------------------------------------------
; fallback keyword and comment based injection
(
  (raw_string_literal) @sql
  (#contains? @sql "-- sql" "--sql" "ADD CONSTRAINT" "ALTER TABLE" "ALTER COLUMN" "DATABASE" "FOREIGN KEY" "GROUP BY" "HAVING" "CREEATE INDEX" "INSERT INTO" "NOT NULL" "PRIMARY KEY" "UPDATE SET" "TRUNCATE TABLE" "LEFT JOIN")
  (#offset! @sql 0 1 0 -1)
)
(
  (interpreted_string_literal) @sql
  (#contains? @sql "-- sql" "--sql" "ADD CONSTRAINT" "ALTER TABLE" "ALTER COLUMN" "DATABASE" "FOREIGN KEY" "GROUP BY" "HAVING" "CREEATE INDEX" "INSERT INTO" "NOT NULL" "PRIMARY KEY" "UPDATE SET" "TRUNCATE TABLE" "LEFT JOIN")
  (#offset! @sql 0 1 0 -1)
)

; should I use a more exhaustive list of keywords?
;  "ADD" "ADD CONSTRAINT" "ALL" "ALTER" "AND" "ASC" "COLUMN" "CONSTRAINT" "CREATE" "DATABASE" "DELETE" "DESC" "DISTINCT" "DROP" "EXISTS" "FOREIGN KEY" "FROM" "JOIN" "GROUP BY" "HAVING" "IN" "INDEX" "INSERT INTO" "LIKE" "LIMIT" "NOT" "NOT NULL" "OR" "ORDER BY" "PRIMARY KEY" "SELECT" "SET" "TABLE" "TRUNCATE TABLE" "UNION" "UNIQUE" "UPDATE" "VALUES" "WHERE"



; json
(
 (const_spec
  name: (identifier) @_id
  value: (expression_list (raw_string_literal) @json))

 (#match? @_id ".*[J|j]son.*")
)

; jsonStr := `{"foo": "bar"}`
(short_var_declaration
    left: (expression_list
            (identifier) @_id (#match? @_id ".*[J|j]son.*"))
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
