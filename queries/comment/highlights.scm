; extends

;; Match **bold** and __bold__ in comment text with higher priority
("text" @bold
  (#match? @bold "(\\*\\*|__)[^\\*\\_]+(\\*\\*|__)")
  (#set! priority 126))  ;; Set priority higher than default

;; Match ~~strikethrough~~ in comment text with higher priority
("text" @strikethrough
  (#match? @strikethrough "\\~\\~[^\\~]+\\~\\~")
  (#set! priority 126))
