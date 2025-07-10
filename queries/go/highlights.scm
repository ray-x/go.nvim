;; extends

(if_statement
  [
   "if"
  ] @comment
  condition: (binary_expression
    left: (identifier) @left_id (#eq? @left_id "err")
    operator: "!="
    right: (nil)
  ) @comment
  consequence: (block
    (return_statement
      (expression_list
        (identifier) @ret_id (#eq? @ret_id "err")
      )
    ) @comment
  )
 (#set! "priority" 128)
)
