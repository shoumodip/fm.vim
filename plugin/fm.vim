if exists("g:loaded_fm")
    finish
endif
let g:loaded_fm = 1

" Non overwriting variable definition mechanism
function s:Let(var, value)
    if !exists(a:var)
        execute "let " . a:var . " = " . a:value
    endif
endfunction

call s:Let("g:fm#ls_arguments", "'-vp --group-directories-first'")
call s:Let("g:fm#hidden", "v:false")

" Non overwriting highlight mechanism
function s:HL(name, link)
    if !hlexists(a:name)
        execute "highlight! link " . a:name . " " . a:link
    endif
endfunction

" Highlight groups
call s:HL("FmPrompt", "Question")
call s:HL("FmHeader", "Title")
call s:HL("FmFolder", "Directory")
call s:HL("FmMarked", "WarningMsg")

call s:HL("FmHelpTitle", "Title")
call s:HL("FmHelpKey", "Keyword")
call s:HL("FmHelpHead", "Comment")

command! Explore call fm#open(expand("%:p:h"))
command! Vexplore wincmd v | Explore
command! Sexplore wincmd s | Explore
command! Texplore tab split | Explore

function s:Dominate(group)
   if exists("#" . a:group)
       execute "autocmd! " . a:group . " *"
   endif
endfunction

call s:Dominate("FileExplorer")
call s:Dominate("NERDTreeHijackNetrw")

" Just in case
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

augroup Fm
    autocmd!
    autocmd BufEnter * if isdirectory(resolve(expand("%:p"))) | call fm#open(resolve(expand("%:p"))) | endif
augroup END
