if exists('g:loaded_fm')
  finish
endif
let g:loaded_fm = 1

" Fm variables {{{
let g:fm#ls_opts = "--group-directories-first -Fv"
let g:fm#show_hidden = 1
let g:fm#require_confirm = 1
let g:fm#keys = {
      \ "l"   : "fm#open",
      \ "h"   : "fm#up",
      \ "<CR>": "fm#open",
      \ "<BS>": "fm#up",
      \ "f"   : "fm#new('file')",
      \ "d"   : "fm#new('directory')",
      \ "r"   : "fm#rename",
      \ "D"   : "fm#delete",
      \ "q"   : "fm#close",
      \ "x"   : "fm#toggle",
      \ "X"   : "fm#toggle_all",
      \ "R"   : "fm#refresh",
      \ "H"   : "fm#toggle_hidden",
      \ "e"   : "fm#edit_start",
      \ "m"   : "fm#move",
      \ "c"   : "fm#move(1)",
      \ "."   : "fm#action",
      \ "!"   : "fm#action('! ', '\<Home>\<Right>')",
      \ }
" }}}
" Highlight groups {{{
highlight! link fmDirectory fmPrompt
highlight! link fmExecutable String
highlight! link fmLink Operator
highlight! link fmCurrent Operator
highlight! link fmSelected Visual
highlight! link fmPrompt Function
" }}}
" NOOOOOO you have to use Netrw! Haha Fm go brrrrrr! {{{
" Netrw sucks hahaha!
let g:loaded_netrwPlugin = 1

command! Explore call fm#start()
command! Vexplore wincmd v | Explore
command! Sexplore wincmd s | Explore
command! Texplore tab split | Explore

augroup fm_for_the_win
  autocmd!
  autocmd BufEnter * if isdirectory(resolve(expand("%:p"))) | call fm#start() | endif
augroup END
" }}}
