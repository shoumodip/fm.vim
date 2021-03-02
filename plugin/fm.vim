if exists("g:loaded_fm")
  finish
endif

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
"
function! s:HL(name, link)
  if !hlexists(a:name)
    execute "highlight! link ".a:name." ".a:link
  endif

  return 1
endfunction

call s:HL("fmDirectory", "fmPrompt")
call s:HL("fmExecutable", "String")
call s:HL("fmLink", "Operator")
call s:HL("fmCurrent", "Operator")
call s:HL("fmSelected", "Visual")
call s:HL("fmPrompt", "Function")
" }}}
" NOOOOOO you have to use Netrw! Haha Fm go brrrrrr! {{{
" Netrw sucks hahaha!
let g:loaded_netrwPlugin = 69

augroup fm_for_the_win
  autocmd!
  autocmd BufEnter * if isdirectory(resolve(expand("%:p"))) | call fm#start() | endif
augroup END

" Replace the netrw commands with fm commands
command! Explore call fm#start()
command! Vexplore wincmd v | Explore
command! Sexplore wincmd s | Explore
command! Texplore tab split | Explore
" }}}

let g:loaded_fm = 69
