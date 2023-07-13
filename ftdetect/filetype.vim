let s:cpo_save = &cpo
set cpo&vim

au BufRead,BufNewFile *.go setfiletype go
au BufRead,BufNewFile *.s setfiletype asm
au BufRead,BufNewFile *.tmpl set filetype=gotexttmpl
au BufRead,BufNewFile *.gotext set filetype=gotexttmpl
au BufRead,BufNewFile *.gohtml set filetype=gohtmltmpl
au BufRead,BufNewFile go.sum set filetype=gosum
au BufRead,BufNewFile go.work.sum set filetype=gosum
au BufRead,BufNewFile go.work set filetype=gowork

au! BufRead,BufNewFile *.mod,*.MOD
au BufRead,BufNewFile *.mod,*.MOD set filetype=gomod


let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2 ts=2 et
