; extends

;; Match **bold** and __bold__ in comment text with higher priority
("text" @comment.bold
  (#match? @comment.bold "(\\*\\*|__)[^\\*\\_]+(\\*\\*|__)")
  (#set! priority 126))  ;; Set priority higher than default

;; Match *italic* and _italic_ in comment text with higher priority
("text" @comment.italic
  (#match? @comment.italic "(\\*|_)[^\\*\\_]+(\\*|_)")
  (#set! priority 130))

;; Match ~~strikethrough~~ in comment text with higher priority
("text" @comment.strikethrough
  (#match? @comment.strikethrough "~~[^~]+~~")
  (#set! priority 126))

;; Match [text] in comment text nodes (reference links) with higher priority
("text" @comment.link
  (#match? @comment.link "\\[[^\\]]+\\]")
  (#set! priority 126))
