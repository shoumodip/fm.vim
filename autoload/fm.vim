" Prompt the user for a input string.
" This is just a pretty and CTRL-c handling wrapper around input()
" See `:h input()` and `:h completion()` for more information
"
" @param prompt The input prompt
" @opt-param text The initial text, defaults to the current directory
" @opt-param completion The completion system used, defaults to `file`
" @return The input string
function! fm#prompt(prompt, ...)
    echohl FmPrompt
    try
        let text = exists("a:1") ? a:1 : substitute(bufname(), " \\*popup\\*$", "", "")
        let completion = exists("a:2") ? a:2 : "file"
        let input = input(a:prompt . ": ", text, completion)
    catch
        let input = ""
    endtry
    echohl Normal

    mode
    return input
endfunction

" Confirm an `yes-or-no` question from the user case insensitively.
" This will keep fetching characters till it receives a 'y' or a 'n'
"
" @param prompt The input prompt
" @return Whether the user confirmed with 'Y' or 'y'
function! fm#confirm(prompt)
    echohl FmPrompt
    echon a:prompt . "? (y or n) "
    echohl Normal

    while v:true
        try
            let choice = nr2char(getchar())
        catch
            let choice = "n"
        endtry

        if choice ==? "y" || choice ==? "n"
            mode
            return choice ==? "y"
        endif
    endwhile
endfunction

" Get the items under the cursor according to the count used.
"
" @return The list of items
function! fm#items()
    if &l:filetype ==# "fm"
        if line("$") == 1
            return []
        else
            let start = getpos(".")[1]
            let count = max([v:count - 1, 0])
            return getline(start, start + count)
        endif
    endif
endfunction

" Mark/unmark an item.
"
" Examples:
"   x    Mark/unmark the item under the cursor
"   69x  Mark/unmark 69 items under the cursor
function! fm#mark()
    if &l:filetype !=# "fm"
        return
    endif

    let items = fm#items()
    let mark_list = b:fm_mark_list[bufname()]

    for item in items
        let index = index(mark_list, item)
        let item_escaped = substitute(item, "'", "\\\\'", "g")

        if index == -1
            call add(mark_list, item)

            if item[len(item) - 1] == "/"
                execute "syntax match FmMarked '^" . item_escaped . "$'he=e-1"
            else
                execute "syntax match FmMarked '^" . item_escaped . "$'"
            endif
        else
            call remove(mark_list, index)

            if item[len(item) - 1] == "/"
                execute "syntax match FmFolder '" . item_escaped . "'he=e-1"
            else
                execute "syntax match Normal '" . item_escaped . "'"
            endif
        endif
    endfor

    execute "normal! " . len(items) . "j"
endfunction

" Unmark everything in the current directory or globally.
"
" @param global Whether the unmarking takes place globally
function! fm#clear_marks(global)
    if &l:filetype ==# "fm"
        if a:global
            for dirname in keys(b:fm_mark_list)
                let b:fm_mark_list[dirname] = []
            endfor
        else
            let b:fm_mark_list[bufname()] = []
        endif
    endif
endfunction

" Toggle the marks in the current directory.
" The unmarked items get marked, while the marked items get unmarked
function! fm#toggle()
    if &l:filetype ==# "fm"
        for item in getline(2, "$")
            let mark_list = b:fm_mark_list[bufname()]
            let index = index(mark_list, item)

            if index == -1
                call add(mark_list, item)
            else
                call remove(mark_list, index)
            endif
        endfor

        call fm#load()
    endif
endfunction

" Get the list of selected items.
"
" Logic:
"   - Marked items in the current directory                   => return them
"   - Marked items in another directory and global mode is on => return them
"   - There are items under the cursor                        => return them
"   - Nothing                                                 => return []
"
" @opt-param global Turn on global mode
" @return The list of selected items
function! fm#selected(...)
    if &l:filetype !=# "fm"
        return
    endif

    let global = exists("a:1") ? a:1 : v:false

    if global
        let mark_list = []

        for [dirname, items] in items(b:fm_mark_list)
            let mark_list += map(copy(items), {_, item -> dirname . item})
        endfor
    else
        let mark_list = map(copy(b:fm_mark_list[bufname()]), {_, item -> bufname() . item})
    endif

    if len(mark_list)
        return mark_list
    elseif line("$") == 1
        return []
    else
        return map(fm#items(), {_, item -> bufname() . item})
    endif
endfunction

" Apply POSIX shell escaping to a list of items.
" Use this if the items are being operated on by shell commands, as without
" proper escaping of specific characters, errors might occur
"
" @return The escaped items
function! fm#escape(items)
    return map(copy(a:items), {_, item -> shellescape(resolve(item))})
endfunction

" Get the selected items, with escaping performed
"
" @return The list of escaped selected items
function! fm#selected_escaped(...)
    if exists("a:1")
        return fm#escape(fm#selected(a:1))
    else
        return fm#escape(fm#selected())
    endif
endfunction

" Enter into a specific item
"
" @param item The item to enter into, defaults to the item under the cursor
function! fm#enter(...)
    if &l:filetype ==# "fm"
        if exists("a:1")
            call fm#open(bufname() . a:1)
        elseif line("$") > 1
            call fm#open(bufname() . getline("."))
        endif
    endif
endfunction

" Enter into the parent directory
function! fm#parent()
    if &l:filetype ==# "fm"
        let previous = bufname()
        if previous ==# "/"
            return
        endif

        let previous = fnamemodify(slice(previous, 0, -1), ":t")
        call fm#open(bufname() . "..")
        call search("^" . previous . "\\/\\?$", "c")
    endif
endfunction

" Turn on edit mode in the current Fm buffer
function! fm#edit_start()
    if &l:filetype !=# "fm"
        return
    endif

    let line = line(".")
    let items = getline(2, "$")
    if len(items) == 0
        echo "Cannot open an edit buffer on an empty directory\n"
    else
        execute "edit " . bufname() . " *edit*"
        setlocal buftype=nofile
        setlocal filetype=fmedit

        let b:fm_edit_init = items

        syntax clear
        syntax match FmFolder ".*/$"he=e-1

        call setline(1, items)
        execute line - 1

        nnoremap <buffer> <nowait> <silent> ZZ :<c-u>call fm#edit_write()<cr><c-l>
        nnoremap <buffer> <nowait> <silent> ZQ :<c-u>call fm#edit_abort()<cr><c-l>

        echo "Press ZZ to write and ZQ to abort changes"
    endif
endfunction

" Abort the changes in the current Fm edit buffer
function! fm#edit_abort()
    let line = line(".")
    if &l:filetype ==# "fmedit"
        bdelete!
    endif
    execute line + 1
endfunction

" Write the changes in the current Fm edit buffer
function! fm#edit_write()
    if &l:filetype !=# "fmedit"
        return
    endif

    let line = line(".")
    let bufname = substitute(bufname(), " \\*edit\\*$", "", "")
    let edit_final = getline(1, "$")

    if len(b:fm_edit_init) != len(edit_final)
        echo "The number of final items must match the number of initial ones\n"
    else
        for i in range(0, len(b:fm_edit_init) - 1)
            if b:fm_edit_init[i] != edit_final[i]
                let initial = shellescape(bufname . b:fm_edit_init[i])
                let final = shellescape(bufname . edit_final[i])
                call system("mv " . initial . " " . final)
            endif
        endfor

        call fm#edit_abort()
        call fm#load()
        execute line + 1
    endif
endfunction

" Toggle the display of hidden items in the current Fm buffer
function! fm#toggle_hidden()
    if &l:filetype ==# "fm"
        let b:fm_hidden = !b:fm_hidden
        call fm#load()
    endif
endfunction

" Load the current Fm buffer from the filesystem
function! fm#load()
    if &l:filetype !=# "fm"
        return
    endif

    let path = bufname()

    if !isdirectory(bufname())
        if fm#confirm("Invalid Fm buffer. Delete it")
            bdelete!
        endif
        return
    endif

    let command = "ls " . b:fm_ls_arguments . (b:fm_hidden ? " " : " -A ")
    let items = systemlist(command . shellescape(path))

    let line = line(".")

    setlocal modifiable
    silent! normal! gg"_dG
    call setline(1, [path] + items)
    setlocal nomodifiable

    if has_key(b:fm_line_list, bufname())
        execute "normal! " . b:fm_line_list[bufname()] . "G"
    else
        execute "normal! " . line . "G"
    endif
    normal! 0

    syntax clear
    syntax match FmFolder ".*/$"he=e-1

    for item in b:fm_mark_list[bufname()]
        let item_escaped = substitute(item, "'", "\\\\'", "g")

        if item[len(item) - 1] == "/"
            execute "syntax match FmMarked '^" . item_escaped . "$'he=e-1"
        else
            execute "syntax match FmMarked '^" . item_escaped . "$'"
        endif
    endfor

    syntax match FmHeader "\%1l.*"
endfunction

" The buffer local mappings in the Fm buffer
function! fm#mappings()
    nnoremap <buffer> <nowait> <silent> d  :<c-u>call fm#mkdir()<cr>
    nnoremap <buffer> <nowait> <silent> f  :<c-u>call fm#touch()<cr>

    nnoremap <buffer> <nowait> <silent> D  :<c-u>call fm#delete()<cr>
    nnoremap <buffer> <nowait> <silent> R  :<c-u>call fm#rename()<cr>
    nnoremap <buffer> <nowait> <silent> gD :<c-u>call fm#delete(v:true)<cr>
    nnoremap <buffer> <nowait> <silent> gR :<c-u>call fm#rename(v:true)<cr>

    nnoremap <buffer> <nowait> <silent> c  :<c-u>call fm#move(v:false, "", v:true)<cr>
    nnoremap <buffer> <nowait> <silent> m  :<c-u>call fm#move()<cr>
    nnoremap <buffer> <nowait> <silent> gc :<c-u>call fm#move(v:true, "", v:true)<cr>
    nnoremap <buffer> <nowait> <silent> gm :<c-u>call fm#move(v:true)<cr>

    nnoremap <buffer> <nowait> <silent> x  :<c-u>call fm#mark()<cr>
    nnoremap <buffer> <nowait> <silent> X  :<c-u>call fm#toggle()<cr>

    nnoremap <buffer> <nowait> <silent> p  :<c-u>call fm#permissions()<cr>
    nnoremap <buffer> <nowait> <silent> gp :<c-u>call fm#permissions(v:true)<cr>
    nnoremap <buffer> <nowait> <silent> s  :<c-u>call fm#shellcmd()<cr>
    nnoremap <buffer> <nowait> <silent> gs :<c-u>call fm#shellcmd(v:true)<cr>

    nnoremap <buffer> <nowait> <silent> l  :<c-u>call fm#enter()<cr>
    nnoremap <buffer> <nowait> <silent> h  :<c-u>call fm#parent()<cr>
    nnoremap <buffer> <nowait> <silent> i  :<c-u>call fm#edit_start()<cr>

    nnoremap <buffer> <nowait> <silent> r  :<c-u>call fm#load()<cr>
    nnoremap <buffer> <nowait> <silent> H  :<c-u>call fm#toggle_hidden()<cr>
    nnoremap <buffer> <nowait> <silent> q  :<c-u>bdelete!<cr><c-l>

    nnoremap <buffer> <nowait> <silent> j  j0
    nnoremap <buffer> <nowait> <silent> k  k0
    nnoremap <buffer> <nowait> <silent> gg 2G0

    nnoremap <buffer> <nowait> <silent> <cr>  :<c-u>call fm#enter()<cr>
    nnoremap <buffer> <nowait> <silent> <c-h> :<c-u>call fm#help()<cr>
endfunction

" Fix the cursor position
function! fm#fix_cursor()
    if line(".") == 1
        normal! 2G0
    endif
endfunction

" Open an item from the filesystem into a Fm or a normal buffer
"
" @opt-param path The path, will ask the user if not supplied
function! fm#open(...)
    if exists("a:1")
        let path = a:1
    else
        try
            let path = fm#prompt("Open")
            if len(path) == 0
                return
            endif
        catch
            return
        endtry
    endif

    let path = resolve(fnamemodify(path, ":p"))

    if &l:filetype ==# "fm"
        let b:fm_line_list[bufname()] = line(".")
    endif

    if !isdirectory(path)
        execute "edit " . path
        return
    endif

    if path[len(path) - 1] != "/"
        let path .= "/"
    endif

    if &l:filetype !=# "fm"
        execute "edit " . path
    endif

    execute "file " . path
    normal! 2G0

    autocmd CursorMoved <buffer> call fm#fix_cursor()
    call fm#mappings()

    setlocal buftype=nofile
    setlocal nomodifiable

    if &l:filetype !=# "fm"
        setlocal filetype=fm
        let b:fm_mark_list = {bufname(): []}
        let b:fm_line_list = {bufname(): 2}
        let b:fm_hidden = g:fm#hidden
        let b:fm_ls_arguments = g:fm#ls_arguments
    endif

    if !has_key(b:fm_mark_list, bufname())
        let b:fm_mark_list[bufname()] = []
    endif

    call fm#load()
endfunction

" Create a directory, wrapper around UNIX `mkdir`.
"
" @opt-param directory The directory name, will ask user if not supplied
function! fm#mkdir(...)
    if &l:filetype ==# "fm"
        let directory = exists("a:1") ? a:1 : fm#prompt("Directory")
        if len(directory) > 0
            let dirname = fnamemodify(directory, ":h")

            call system("mkdir -p " . shellescape(directory))
            call fm#open(dirname, v:true)
            call search(fnamemodify(directory, ":t"), "cw")
        endif
    endif
endfunction

" Create a file, wrapper around UNIX `touch`.
"
" @opt-param file The file name, will ask user if not supplied
function! fm#touch(...)
    if &l:filetype ==# "fm"
        let file = exists("a:1") ? a:1 : fm#prompt("File")
        if len(file) > 0
            let dirname = fnamemodify(file, ":h")

            call system("mkdir -p " . shellescape(dirname))
            call system("touch " . shellescape(file))
            call fm#open(dirname, v:true)
            call search(fnamemodify(file, ":t"), "cw")
        endif
    endif
endfunction

" Change the permissions of the selected items, wrapper around UNIX `chmod`.
"
" @opt-param global Whether it should be done globally
" @opt-param perms The permissions, takes sequential input if exhausted
function! fm#permissions(...)
    if &l:filetype !=# "fm"
        return
    endif

    let global = exists("a:1") ? a:1 : v:false
    let perms = exists("a:2") ? a:2 : []
    let items = fm#selected(global)

    for i in range(0, len(items) - 1)
        let item = items[i]
        let readable = filereadable(item) ? "+r" : "-r"
        let writable = filewritable(item) ? "+w" : "-w"
        let executable = executable(item) ? "+x" : "-x"

        let initial = " [" . readable . "," . writable . "," . executable . "]"
        let final = i < len(perms) ? perms[i] : fm#prompt("Change permissions of " . item . initial, "")

        for change in split(final)
            if change =~? "[+-][rwx]"
                call system("chmod " . change . " " . shellescape(item))
            else
                echo "Invalid change specification '" . change . "'\n"
                return
            endif
        endfor
    endfor

    call fm#clear_marks(global)
    call fm#load()
endfunction

" Rename the selected items, wrapper around UNIX `mv`.
"
" @opt-param global Whether it should be done globally
" @opt-param dests The destinations, takes sequential input if exhausted
function! fm#rename(...)
    if &l:filetype !=# "fm"
        return
    endif

    let global = exists("a:1") ? a:1 : v:false
    let dests = exists("a:2") ? a:2 : []
    let items = fm#selected(global)

    for i in range(0, len(items) - 1)
        let item = items[i]
        let dest = i < len(dests) ? dests[i] : fm#prompt("Rename " . item . " to", item)

        if len(dest) > 0 && substitute(dest, "/$", "", "") != substitute(item, "/$", "", "")
            let dirname = fnamemodify(dest, ":p:h")
            call system("mkdir -p " . shellescape(dirname))
            call system("mv " . shellescape(item) . " " . shellescape(dest))
        endif
    endfor

    call fm#clear_marks(global)
    call fm#load()
    keeppatterns execute "/" . fnamemodify(dest, ":t")
endfunction

" Move the selected items to a directory, wrapper around UNIX `mv` and `cp`.
"
" @opt-param global Whether it should be done globally
" @opt-param dest The destination, input will be taken by default
" @opt-param copy Whether the files should be copied instead of moved
function! fm#move(...)
    if &l:filetype !=# "fm"
        return
    endif

    let global = exists("a:1") ? a:1 : v:false
    let items = fm#selected_escaped(global)
    let copy = exists("a:3") ? a:3 : v:false

    if exists("a:2") && len(a:2) > 0
        let dest = len(items) > 0 ? a:2 : ""
    else
        let prefix = copy ? "Copy " : "Move "
        if len(items) == 1
            let dest = fm#prompt(prefix . items[0] . " to")
        elseif len(items) > 0
            execute "split " . bufname() . " *popup*"
            setlocal nonumber norelativenumber
            setlocal buftype=nofile
            call setline(1, items)

            redraw
            let dest = fm#prompt(prefix . len(items) . " items to")
            bdelete!
        else
            let dest = ""
        endif
    endif

    if len(dest) > 0
        let dirname = fnamemodify(dest, ":p:h")
        call system("mkdir -p " . shellescape(dirname))

        let command = copy ? "cp -r" : "mv"
        call system(command . " " . join(items, " ") . " " . shellescape(dest))
        call fm#clear_marks(global)
        call fm#load()
    endif
endfunction

" Delete the selected items, wrapper around UNIX `rm`.
" The `rm` command removes permanently, proceed with caution
"
" @opt-param global Whether it should be done globally
" @opt-param confirm Whether it is confirmed, user is asked by default
function! fm#delete(...)
    if &l:filetype !=# "fm"
        return
    endif

    let global = exists("a:1") ? a:1 : v:false
    let items = fm#selected_escaped(global)

    if exists("a:2")
        let confirm = a:2
    else
        if len(items) == 1
            let confirm = fm#confirm("Delete " . items[0])
        elseif len(items) > 0
            execute "split " . bufname() . " *popup*"
            setlocal nonumber norelativenumber
            setlocal buftype=nofile
            call setline(1, items)

            redraw
            let confirm = fm#confirm("Delete " . len(items) . " items")
            bdelete!
        else
            let confirm = v:false
        endif
    endif

    if confirm
        call system("rm -rf " . join(items, " "))
        call fm#clear_marks(global)
        call fm#load()
    endif
endfunction

" Run a shell command selected items and display the output.
" If the output is can be fitted in the echo area, it is echoed, otherwise a
" popup window is opened with the output
"
" @opt-param global Whether it should be done globally
" @opt-param cmd The command, user is asked by default
function! fm#shellcmd(...)
    if &l:filetype !=# "fm"
        return
    endif

    let global = exists("a:1") ? a:1 : v:false
    let items = fm#selected_escaped(global)

    if exists("a:2")
        let cmd = len(items) > 0 ? a:2 : ""
    else
        if len(items) == 1
            let cmd = fm#prompt("Run shell command on " . items[0], "", "shellcmd")
        elseif len(items) > 0
            execute "split " . bufname() . " *popup*"
            setlocal nonumber norelativenumber
            setlocal buftype=nofile
            call setline(1, items)

            redraw
            let cmd = fm#prompt("Run shell command on " . len(items) . " items", "", "shellcmd")
            bdelete!
        else
            let cmd = ""
        endif
    endif

    if len(cmd) > 0
        if exists("g:asyncrun_name")
            execute "AsyncRun " . cmd . " " . join(items, " ")
            wincmd w
            normal! gg
            echo 'Press "q" to close this popup'
            nnoremap <buffer> <nowait> <silent> q :<c-u>bdelete!<cr><c-l>
        elseif exists("g:loaded_dispatch")
            execute "Dispatch " . cmd . " " . join(items, " ")
            wincmd w
            normal! gg
            echo 'Press "q" to close this popup'
            nnoremap <buffer> <nowait> <silent> q :<c-u>bdelete!<cr><c-l>
        else
            let output = systemlist(cmd . " " . join(items, " "))

            call fm#clear_marks(global)
            call fm#load()

            if len(output) == 0
                return
            endif

            if len(output) <= &cmdheight
                echo output[0]
            elseif len(output) > 0
                execute "split " . bufname() . " *popup*"
                setlocal nonumber norelativenumber
                setlocal buftype=nofile
                call setline(1, output)
                setlocal nomodifiable

                echo 'Press "q" to close this popup'
                nnoremap <buffer> <nowait> <silent> q :<c-u>bdelete!<cr><c-l>
            endif
        endif
    endif
endfunction

function! fm#help()
    split *fm help*
    setlocal nonumber norelativenumber
    setlocal buftype=nofile

    let text  = ["   ======== Actions =========        ============ Others ============"]
    let text += ["   (D) Delete                        (x)    Mark/unmark item"]
    let text += ["   (R) Rename                        (X)    Toggle marks in directory"]
    let text += ["   (c) Copy to a directory           (l)    Open item"]
    let text += ["   (m) Move to a directory           (h)    Go up one directory"]
    let text += ["   (p) Change permissions            (i)    Start edit mode"]
    let text += ["   (s) Execute shell commands        (q)    Quit"]
    let text += ["   (g) Run the next action globally  (r)    Refresh"]
    let text += ["   (f) Create a file                 (<cr>) Open item"]
    let text += ["   (d) Create a directory            (<bs>) Go up one directory"]
    let text += [""]
    let text += ["  Selected Items: The marked items or the items under the cursor"]
    let text += ["  Action:         Operation on selected items in the current directory"]
    let text += ["  Global Action:  Operation on all selected items in the current buffer"]

    syntax match FmHelpHead "\%1l=*"
    syntax match FmHelpKey "([^)]*)"hs=s+1,he=e-1
    syntax match FmHelpTitle ".*:"he=e-1
    syntax keyword FmHelpTitle Actions Others

    call setline(1, text)
    setlocal nomodifiable

    echo 'Press "q" to close this popup'
    nnoremap <buffer> <nowait> <silent> q :<c-u>bdelete!<cr><c-l>
endfunction

function! fm#explore()
    let previous = bufnr()
    call fm#open(expand("%:p:h"))

    let name = fnamemodify(bufname(previous), ":t")
    if name !=# ""
        call search("^" . name . "\\/\\?$", "c")
    endif

    echo "Press <C-h> to get help"
endfunction
