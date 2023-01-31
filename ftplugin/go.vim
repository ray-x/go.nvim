let s:cpo_save = &cpo
set cpo&vim

let &cpo = s:cpo_save
unlet s:cpo_save

setlocal formatoptions-=t

setlocal comments=s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

setlocal noexpandtab

" vim: sw=2 ts=2 et
