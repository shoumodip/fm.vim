if exists("g:loaded_fm")
  finish
endif

" Highlight groups
highlight! link FmPrompt    Identifier
highlight! link FmHeader    Structure
highlight! link FmFolder    Identifier
highlight! link FmMarked    Special

highlight! link FmHelpTitle Title
highlight! link FmHelpKey   Keyword
highlight! link FmHelpHead  Comment

" Replace netrw with Fm
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

command! Explore call fm#open(expand("%:p:h"))
command! Vexplore wincmd v | Explore
command! Sexplore wincmd s | Explore
command! Texplore tab split | Explore

augroup Fm
  autocmd!
  autocmd BufEnter * if isdirectory(resolve(expand("%:p"))) | call fm#open(resolve(expand("%:p"))) | endif
augroup END
