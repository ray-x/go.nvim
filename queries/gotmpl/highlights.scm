; Copyright: https://github.com/ngalaiko/tree-sitter-go-template
; Identifiers

[
    (field)
    (field_identifier)
] @property

(variable) @variable

; Function calls

(function_call
  function: (identifier) @function)

(method_call
  method: (selector_expression
    field: (field_identifier) @method))

; Operators

"|" @operator
":=" @operator

; Builtin functions

((identifier) @function.builtin
 (#match? @function.builtin "^(and|call|html|index|slice|js|len|not|or|print|printf|println|urlquery|eq|ne|lt|ge|gt|ge)$"))

; Delimiters

"." @punctuation.delimiter
"," @punctuation.delimiter

"{{" @punctuation.bracket
"}}" @punctuation.bracket
"{{-" @punctuation.bracket
"-}}" @punctuation.bracket
")" @punctuation.bracket
"(" @punctuation.bracket

; Keywords

[
    "else"
    "else if"
    "if"
    "with"
] @conditional

[
    "range"
    "end"
    "template"
    "define"
    "block"
] @keyword

; Literals

[
  (interpreted_string_literal)
  (raw_string_literal)
  (rune_literal)
] @string

(escape_sequence) @string.special

[
  (int_literal)
  (float_literal)
  (imaginary_literal)
] @number

[
    (true)
    (false)
] @boolean

[
  (nil)
] @constant.builtin

(comment) @comment
(ERROR) @error
