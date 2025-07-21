if exists("g:loaded_fm")
    finish
endif

let g:loaded_fm = 1
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

if exists("#FileExplorer")
    autocmd! FileExplorer *
endif

command! -nargs=? -complete=dir Explore call fm#new(<q-args>)
command! Vexplore wincmd v | Explore
command! Sexplore wincmd s | Explore
command! Texplore tab split | Explore

function! s:buffer_creation_callback()
    let path = expand("%")
    if isdirectory(path)
        call fm#new(path, v:true)
    endif
endfunction

augroup Fm
    autocmd!
    autocmd VimEnter,BufReadPre * call s:buffer_creation_callback()
augroup END
