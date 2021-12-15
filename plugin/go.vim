let s:cpo_save = &cpo
set cpo&vim

" CompilerSet errorformat =%-G#\ %.%#                                 " Ignore lines beginning with '#' ('# command-line-arguments' line sometimes appears?)
" CompilerSet errorformat+=%-G%.%#panic:\ %m                          " Ignore lines containing 'panic: message'
" CompilerSet errorformat+=%Ecan\'t\ load\ package:\ %m               " Start of multiline error string is 'can\'t load package'
" CompilerSet errorformat+=%A%\\%%(%[%^:]%\\+:\ %\\)%\\?%f:%l:%c:\ %m " Start of multiline unspecified string is 'filename:linenumber:columnnumber:'
" CompilerSet errorformat+=%A%\\%%(%[%^:]%\\+:\ %\\)%\\?%f:%l:\ %m    " Start of multiline unspecified string is 'filename:linenumber:'
" CompilerSet errorformat+=%C%*\\s%m                                  " Continuation of multiline error message is indented
" CompilerSet errorformat+=%-G%.%#                                    " All lines not matching any of the above patterns are ignored
"

let &cpo = s:cpo_save
unlet s:cpo_save
