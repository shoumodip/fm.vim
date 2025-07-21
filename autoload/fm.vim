let s:iota = 0
let s:marked_tree = {}
let s:marked_flat = {}

function! s:error(message)
    echohl ErrorMsg
    echo "ERROR: "..a:message
    echohl Normal
endfunction

function! s:shell(cmd, ...)
    let output = systemlist(a:cmd)
    if v:shell_error == 0
        return v:true
    endif

    if exists("a:1") ? a:1 : v:true
        new
    endif

    setlocal buftype=nofile
    setlocal filetype=fmerror
    setlocal bufhidden=hide
    setlocal nomodifiable

    setlocal modifiable
    silent! call deletebufline("", 1, "$")
    call setline(1, "$ "..a:cmd)
    call setline(2, output)
    setlocal nomodifiable
    call s:error("Command exited with code "..v:shell_error)

    syntax clear
    syntax match Title "\%1l.*"

    nnoremap <buffer> <nowait> <silent> q :<C-u>bdelete!<CR>
    return v:false
endfunction

function! s:prompt(prompt, ...)
    echohl Question
    try
        let input = input(a:prompt . ": ", exists("a:1") ? a:1 : "", exists("a:2") ? a:2 : "file")
    catch
        let input = ""
    endtry
    echohl Normal

    mode
    return input
endfunction

function! s:choice(prompt, options)
    echohl Question
    echon a:prompt . " ["..a:options.."]: "
    echohl Normal

    while v:true
        try
            let choice = getchar()
            if choice == 27
                mode
                return ""
            endif

            let choice = nr2char(choice)
            if stridx(a:options, choice) != -1
                mode
                return choice
            endif
        catch
            mode
            return ""
        endtry
    endwhile
endfunction

function! s:buffer_name(iota, path)
    return "[Fm #"..a:iota.."] "..a:path
endfunction

function! s:buffer_rename()
    execute "file "..fnameescape(s:buffer_name(b:fm_iota, b:fm_path))
endfunction

function! s:buffer_reload()
    let line = line(".")

    setlocal modifiable
    silent! call deletebufline("", 1, "$")
    call setline(1, b:fm_path)
    call setline(2, systemlist("ls -vpA --group-directories-first "..shellescape(b:fm_path)))
    setlocal nomodifiable

    if has_key(b:fm_last, b:fm_path)
        if !search("^\\V"..b:fm_last[b:fm_path].."\\M$", "cw")
            execute "normal! "..line.."G"
        endif
        normal! 0
    endif
endfunction

function! s:buffer_highlight()
    syntax clear
    syntax match Normal "/" contained
    syntax match Directory ".*/$" contains=Normal
    syntax match Title "\%1l.*"

    if has_key(s:marked_tree, b:fm_path)
        for item in keys(s:marked_tree[b:fm_path])
            execute "syntax match Special /^\\V"..substitute(item, "/", "\\\\/", "").."\\M$/ contains=Normal"
        endfor
    endif
endfunction

function! s:buffer_has_items()
    if &l:filetype !=# "fm"
        return v:false
    endif

    if line(".") < 2
        return v:false
    endif

    return v:true
endfunction

function! s:item_current()
    if !s:buffer_has_items()
        return ""
    endif

    return getline(".")
endfunction

function! s:item_toggle(line)
    let item = getline(a:line)
    if item == ""
        return
    endif
    let path = b:fm_path..item

    if !has_key(s:marked_tree, b:fm_path)
        let s:marked_tree[b:fm_path] = {}
    endif

    let dict = s:marked_tree[b:fm_path]
    if has_key(dict, item)
        call remove(dict, item)
        call remove(s:marked_flat, path)
    else
        let dict[item] = 1
        let s:marked_flat[path] = 1
    endif
endfunction

function! s:exec_preview(action, allow_current)
    if &l:filetype !=# "fm"
        return
    endif

    if empty(s:marked_flat)
        if !a:allow_current || !s:buffer_has_items()
            return
        endif

        let line = line(".")
        let count = min([v:count ? v:count : 1, line("$") - line + 1])
        let items = map(getline(line, line + count - 1), "b:fm_path..v:val")
    else
        let items = keys(s:marked_flat)
    endif

    let path = b:fm_path

    new
    setlocal buftype=nofile
    setlocal filetype=fmpreview
    setlocal bufhidden=hide
    setlocal nomodifiable

    let b:fmpreview_path = path
    let b:fmpreview_items = items
    let b:fmpreview_action = a:action

    setlocal modifiable
    call setline(1, "Press <Enter> to "..a:action.." the following item(s):")
    call setline(2, items)
    normal! 2G
    setlocal nomodifiable

    syntax clear
    syntax match Title "\%1l.*"

    nnoremap <buffer> <nowait> <silent> q    :<C-u>bdelete! \| mode<CR>
    nnoremap <buffer> <nowait> <silent> <CR> :<C-u>call fm#confirm()<CR>
endfunction

function! s:buffer_enter_callback()
    if s:buffer_has_items()
        let b:fm_last[b:fm_path] = getline(".")
        call s:buffer_reload()
        call s:buffer_highlight()
    endif
endfunction

function! s:cursor_moved_callback()
    if line(".") < 2
        normal! 2G
    endif
endfunction

function! fm#enter()
    let item = s:item_current()
    if item == ""
        return
    endif

    let b:fm_last[b:fm_path] = item

    let item = b:fm_path..item
    if !isdirectory(item)
        if buflisted(item)
            execute "buffer "..fnameescape(item)
        else
            execute "edit "..fnameescape(item)
        endif
        return
    endif

    let b:fm_path = fnamemodify(resolve(item), ":p")
    call s:buffer_rename()
    call s:buffer_reload()
endfunction

function! fm#parent()
    if &l:filetype !=# "fm"
        return
    endif

    if line(".") > 1
        let b:fm_last[b:fm_path] = getline(".")
    endif

    let base = fnamemodify(b:fm_path, ":h:t")
    if base == ""
        return
    endif
    let last = base.."/"

    let b:fm_path = b:fm_path[0:-len(last) - 1]
    let b:fm_last[b:fm_path] = last

    call s:buffer_rename()
    call s:buffer_reload()
endfunction

function! fm#rename()
    let item = s:item_current()
    if item == ""
        return
    endif

    let old = item
    let new = s:prompt("Rename", item[-1:-1] == "/" ? item[0:-2] : item)
    if new == ""
        return
    endif

    if new[-1:-1] == "/"
        if old[-1:-1] == "/"
            let new = new[0:-2]
        else
            call s:error("Unexpected '/' in new file name "..shellescape(new))
            return
        endif
    endif

    if old[-1:-1] == "/"
        let old = old[0:-2]
    endif

    if stridx(new, "/") != -1
        call s:error("Unexpected '/' in new name "..shellescape(new))
        return
    endif

    if new ==# old
        return
    endif

    if !s:shell("mv "..shellescape(b:fm_path..old).." "..shellescape(b:fm_path..new))
        return
    endif

    let b:fm_last[b:fm_path] = new
    call s:buffer_reload()
endfunction

function! fm#reload()
    if &l:filetype !=# "fm"
        return
    endif

    if s:buffer_has_items()
        let b:fm_last[b:fm_path] = getline(".")
    endif

    call s:buffer_reload()
endfunction

function! fm#toggle(all)
    if !s:buffer_has_items()
        return
    endif

    if a:all
        for i in range(1, line("$"))
            call s:item_toggle(i + 1)
        endfor
    else
        let line = line(".")
        let count = min([v:count ? v:count : 1, line("$") - line + 1])
        for _ in range(count)
            call s:item_toggle(line)
            let line += 1
        endfor
        execute "normal! "..count.."j"
    endif

    call s:buffer_highlight()
endfunction

function! fm#move()
    call s:exec_preview("move", v:false)
endfunction

function! fm#copy()
    call s:exec_preview("copy", v:false)
endfunction

function! fm#touch()
    if &l:filetype !=# "fm"
        return
    endif

    let name = s:prompt("Create File")
    if name == ""
        return
    endif

    if name[-1:-1] == "/"
        call s:error("Unexpected ending '/' in name "..shellescape(name))
        return
    endif

    if name[0] == "/"
        let path = resolve(name)
    else
        let path = resolve(b:fm_path..name)
    endif

    let parent = fnamemodify(path, ":h")
    if parent != "/"
        let parent .= "/"
    endif

    if !s:shell("mkdir -p "..shellescape(parent))
        return
    endif

    if !s:shell("touch "..shellescape(path))
        return
    endif

    if line(".") > 1
        let b:fm_last[b:fm_path] = getline(".")
    endif

    let b:fm_path = parent
    let b:fm_last[b:fm_path] = fnamemodify(path, ":t")
    call s:buffer_reload()
endfunction

function! fm#mkdir()
    if &l:filetype !=# "fm"
        return
    endif

    let name = s:prompt("Create Directory")
    if name == ""
        return
    endif

    if name[0] == "/"
        let path = resolve(name)
    else
        let path = resolve(b:fm_path..name)
    endif

    if path == "/"
        return
    endif

    let parent = fnamemodify(path, ":h")
    if parent != "/"
        let parent .= "/"
    endif

    if !s:shell("mkdir -p "..shellescape(path))
        return
    endif

    if line(".") > 1
        let b:fm_last[b:fm_path] = getline(".")
    endif

    let b:fm_path = parent
    let b:fm_last[b:fm_path] = fnamemodify(path, ":t").."/"
    call s:buffer_reload()
endfunction

function! fm#chmod(add)
    let item = s:item_current()
    if item == ""
        return
    endif

    let choice = s:choice(a:add ? "Add Permission" : "Remove Permission", "rwx")
    if choice == ""
        return
    endif

    if !s:shell("chmod "..(a:add ? "+" : "-")..choice.." "..shellescape(b:fm_path..item))
        return
    endif

    if choice == "r"
        let choice = "readable"
    elseif choice == "w"
        let choice = "writeable"
    elseif choice == "x"
        let choice = "executable"
    endif

    if a:add
        echo "Added "..choice.." permission to "..shellescape(item)
    else
        echo "Removed "..choice.." permission from "..shellescape(item)
    endif
endfunction

function! fm#shell(...)
    if !s:buffer_has_items()
        return
    endif

    let cmd = s:prompt("Shell Command", "", "shellcmd")
    if cmd == ""
        return
    endif
    let cmd = shellescape(cmd)

    call s:exec_preview("shell", v:true)
    let b:fmpreview_cmd = cmd

    setlocal modifiable
    call setline(1, "Press <Enter> to run "..cmd.." on the following item(s):")
    setlocal nomodifiable
endfunction

function! fm#delete()
    call s:exec_preview("delete", v:true)
endfunction

function! fm#edit_abort()
    if &l:filetype !=# "fmedit"
        return
    endif

    let cursor = getpos(".")
    let cursor[0] = b:fmedit_buffer
    let cursor[1] += 1
    bdelete!
    call setpos(".", cursor)
endfunction

function! fm#edit_write()
    if &l:filetype !=# "fmedit"
        return
    endif

    let cursor = getpos(".")
    let cursor[0] = b:fmedit_buffer
    let cursor[1] += 1

    let init = b:fmedit_items
    let final = getline(1, "$")

    mode
    if len(init) != len(final)
        new
        setlocal buftype=nofile
        setlocal filetype=fmerror
        setlocal bufhidden=hide
        call setline(1, "The initial and final number of items do not match. The initial items are:")
        call setline(2, init)
        setlocal nomodifiable

        syntax clear
        syntax match Normal "/" contained
        syntax match Directory ".*/$" contains=Normal
        syntax match ErrorMsg "\%1l.*"

        nnoremap <buffer> <nowait> <silent> q :<C-u>bdelete!<CR>
        return
    endif

    let parent = getbufvar(cursor[0], "fm_path")
    if has_key(s:marked_tree, parent)
        let parent_dict = s:marked_tree[parent]
    else
        let parent_dict = {}
    endif

    for i in range(0, len(init) - 1)
        let old = init[i]
        let new = final[i]

        if new[-1:-1] == "/"
            if old[-1:-1] != "/"
                execute "normal! 0"..(i + 1).."G"
                call s:error("Unexpected '/' in new file name "..shellescape(new))
                return
            endif
        else
            if old[-1:-1] == "/"
                execute "normal! 0"..(i + 1).."G"
                call s:error("Expected '/' in new directory name "..shellescape(new))
                return
            endif
        endif

        if old != new
            let old_path = parent..old
            let new_path = parent..new

            if !s:shell("mv -n "..shellescape(old_path).." "..shellescape(new_path))
                return
            endif

            if has_key(parent_dict, old)
                call remove(parent_dict, old)
                let parent_dict[new] = 1
            endif

            if has_key(s:marked_flat, old_path)
                call remove(s:marked_flat, old_path)
                let s:marked_flat[new_path] = 1
            endif
        endif
    endfor

    let col = col(".")
    let last = getline(".")

    bdelete!
    call setpos(".", cursor)

    let b:fm_last[b:fm_path] = last
    call s:buffer_reload()
    call s:buffer_highlight()

    if col == 1
        normal! 0
    else
        execute "normal! "..(col - 1).."l"
    endif
endfunction

function! fm#edit_start()
    if &l:filetype !=# "fm"
        return
    endif

    let line = line(".")
    let items = getline(2, "$")
    if len(items) == 0
        call s:error("Cannot open an edit buffer on an empty directory")
        return
    endif

    let cursor = getpos(".")
    let cursor[1] -= 1

    execute "edit "..fnameescape("[FmEdit #"..b:fm_iota.."] "..b:fm_path)

    setlocal buftype=nofile
    setlocal filetype=fmedit
    setlocal bufhidden=hide

    let b:fmedit_items = items
    let b:fmedit_buffer = cursor[0]

    syntax clear
    syntax match Normal "/" contained
    syntax match Directory ".*/$" contains=Normal

    call setline(1, items)
    call setpos(".", cursor)

    nnoremap <buffer> <nowait> <silent> ZZ :<C-u>call fm#edit_write()<CR>
    nnoremap <buffer> <nowait> <silent> ZQ :<C-u>call fm#edit_abort()<CR>

    echo "Press ZZ to write and ZQ to abort changes"
endfunction

function! fm#new(path, ...)
    let path = fnamemodify(resolve(a:path), ":p")
    let replace = v:false
    if exists("a:1")
        let replace = a:1
    endif

    if !replace
        execute "edit "..fnameescape(s:buffer_name(s:iota, path))
    endif

    setlocal buftype=nofile
    setlocal filetype=fm
    setlocal bufhidden=hide
    setlocal nomodifiable

    let b:fm_iota = s:iota
    let s:iota += 1

    let b:fm_last = {}
    let b:fm_path = path

    if replace
        call s:buffer_rename()
    endif

    call s:buffer_reload()
    call s:buffer_highlight()

    autocmd BufEnter    <buffer> call s:buffer_enter_callback()
    autocmd CursorMoved <buffer> call s:cursor_moved_callback()

    nnoremap <buffer> <nowait> <silent> <Enter> :<C-u>call fm#enter()<CR>
    nnoremap <buffer> <nowait> <silent> <BS>    :<C-u>call fm#parent()<CR>

    nnoremap <buffer> <nowait> <silent> R :<C-u>call fm#rename()<CR>
    nnoremap <buffer> <nowait> <silent> r :<C-u>call fm#reload()<CR>

    nnoremap <buffer> <nowait> <silent> x :<C-u>call fm#toggle(0)<CR>
    nnoremap <buffer> <nowait> <silent> X :<C-u>call fm#toggle(1)<CR>

    nnoremap <buffer> <nowait> <silent> m :<C-u>call fm#move()<CR>
    nnoremap <buffer> <nowait> <silent> c :<C-u>call fm#copy()<CR>

    nnoremap <buffer> <nowait> <silent> f :<C-u>call fm#touch()<CR>
    nnoremap <buffer> <nowait> <silent> d :<C-u>call fm#mkdir()<CR>

    nnoremap <buffer> <nowait> <silent> ! :<C-u>call fm#shell()<CR>
    nnoremap <buffer> <nowait> <silent> + :<C-u>call fm#chmod(1)<CR>
    nnoremap <buffer> <nowait> <silent> - :<C-u>call fm#chmod(0)<CR>

    nnoremap <buffer> <nowait> <silent> D :<C-u>call fm#delete()<CR>
    nnoremap <buffer> <nowait> <silent> i :<C-u>call fm#edit_start()<CR>
    nnoremap <buffer> <nowait> <silent> q :<C-u>bdelete!<CR>
endfunction

function! fm#confirm()
    if &l:filetype !=# "fmpreview"
        return
    endif

    if exists("b:fmpreview_cmd")
        let cmd = b:fmpreview_cmd
    endif

    let path = b:fmpreview_path
    let items = join(map(b:fmpreview_items, "shellescape(v:val)"), " ")
    let action = b:fmpreview_action

    let s:marked_flat = {}
    let s:marked_tree = {}

    if action ==? "move"
        let command = "mv -f "..items.." "..shellescape(path)
    elseif action ==? "copy"
        let command = "cp -rf "..items.." "..shellescape(path)
    elseif action ==? "shell"
        bdelete! | mode
        call s:buffer_reload()
        call s:buffer_highlight()

        if exists("g:asyncrun_name")
            execute "AsyncRun "..cmd.." "..items
            copen
            normal! gg
            nnoremap <buffer> <nowait> <silent> q :<C-u>bdelete!<CR>
        elseif exists(":Compile")
            execute "Compile "..cmd.." "..items
        elseif exists(":terminal")
            let number = &l:number
            let relativenumber = &l:relativenumber
            execute "split | terminal "..cmd.." "..items
            let &l:number = number
            let &l:relativenumber = relativenumber

            normal! gg
            nnoremap <buffer> <nowait> <silent> q :<C-u>bdelete!<CR>
        else
            let cmd .= " "..items
            let output = systemlist(cmd)
            if len(output) == 0
                return
            endif

            if len(output) <= &cmdheight
                echo output[0]
            elseif len(output) > 0
                new
                setlocal buftype=nofile
                call setline(1, "$ "..cmd)
                call setline(2, output)
                setlocal nomodifiable

                syntax clear
                syntax match Title "\%1l.*"

                nnoremap <buffer> <nowait> <silent> q :<C-u>bdelete!<CR>
            endif
        endif
        return
    elseif action ==? "delete"
        let command = "rm -rf "..items
    else
        call s:error("Invalid action "..shellescape(action))
        return
    endif

    if !s:shell(command, v:false)
        return
    endif

    bdelete! | mode
    call s:buffer_reload()
    call s:buffer_highlight()
endfunction
