" Highlight groups {{{
highlight! link fmDirectory fmPrompt
highlight! link fmExecutable Operator
highlight! link fmLink Include
highlight! link fmCurrent Operator
highlight! link fmSelected Visual
highlight! link fmPrompt Function
" }}}
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
" Abstract function for showing error messages {{{
function fm#error(msg) abort
  echohl ErrorMsg
  echo a:msg
  echohl Normal

  return ""
endfunction
" }}}
" Abstract function for handling prompts {{{
function fm#prompt(msg, ...) abort

  echohl fmPrompt

  " If the optional second argument is 'truthy', only take a single character
  " as input, else take an entire string
  if exists("a:2") && a:2
    echo a:msg
    let input = nr2char(getchar())
  else

    " This is a file manager, therefore the completions offered should be
    " relevant
    let input = input(a:msg, exists("a:1") ? a:1 : "", "file")
  endif

  echohl Normal
  mode

  return input
endfunction
" }}}
" Abstract function for doing yes-no prompts {{{
function! fm#confirm(msg) abort

  " No confirmation setting
  if ! b:fm_require_confirm
    return "y"
  endif

  " Non-blank input at first, as user press ESC and cancel the confirmation
  let input = " "

  " Loop till the user enters either ESC, y, Y, n or N
  while input !~? '\(^$\|y\|n\)'
    let input = fm#prompt(a:msg . "? (y or n) ", "", 1)

    " User has pressed ESC, set the input to blank
    if input == ''
      let input = ""
    endif
  endwhile

  return input
endfunction
" }}}
" Get selected items or the current item if there aren't any {{{
function! fm#get_items() abort
  let items = []

  " Get all the selected items in a list instead of a per-directory basis
  for [key, value] in items(b:fm_selected)
    let key = substitute(key, '[@*=>|/]$', "", "")
    let key = substitute(key, '"', '\"', "g")

    let value = map(copy(value), '"' . key . '/' . '" . v:val')
    call extend(items, value)
  endfor

  " Check if items have not been selected
  if empty(items)
    if getline(".") == ''
      return ['']
    endif

    " Pass on the current item as the selected item
    let items = fnameescape(b:fm_current_dir . "/" . getline("."))
    let items = [substitute(items, '[@*=>|/]$', "", "")]
  endif

  return items
endfunction
" }}}
" Refresh Fm {{{
function! fm#refresh() abort
  let line = line(".")

  silent! call fm#render()
  execute "normal! " . line . "G"

  return ""
endfunction
" }}}
" Highlight the selected items {{{
function! fm#draw_selects() abort
  syntax clear fmSelected

  " Go through all the items in the current directory selection list and
  " highlight them as being selected
  for item in b:fm_selected[b:fm_current_dir]
    execute "syntax match fmSelected '^" . substitute(item, "'", "\\\\'", "g") . "$'"
  endfor

  return ""
endfunction
" }}}
" Set the buffer name according to the current directory {{{
function! fm#set_name() abort

  " Make the buffer name the current directory
  execute "file " . b:fm_current_dir

  return ""
endfunction
" }}}
" Position the cursor on the previous cursor position {{{
function! fm#set_cursor() abort

  " Check if the directory has been visited before
  if has_key(b:fm_history, b:fm_current_dir)

    " Position the cursor on the item it was present on the previous time, if
    " it still exists
    silent! call setpos(".", [0, 2, 1, 0])
    let position = search(b:fm_history[b:fm_current_dir], "cW")

    if position == -1
      silent! call setpos(".", [0, 1, 1, 0])
    endif

  else

    " Place the cursor on the second line of the file
    silent! call setpos(".", [0, 2, 1, 0])
  endif

  return ""
endfunction
" }}}
" Render the file manager {{{
function! fm#render() abort

  " Don't attempt to render the directory if it doesn't exist
  if !isdirectory(b:fm_current_dir)
    call fm#error("Error: directory '" . b:fm_current_dir . "' does not exist!")
    return ""
  endif

  " Generate the list of files and directories
  let cmd = "ls " . (b:fm_show_hidden ? "-A " : "")
  let cmd = cmd . b:fm_ls_opts . " " . fnameescape(b:fm_current_dir)

  setlocal modifiable

  " Render it
  silent! call setline(1, b:fm_current_dir)
  silent! call deletebufline(bufnr(), 2, "$")
  silent! call setline(2, systemlist(cmd))

  " Add an empty line if there are no items
  if line("$") == 1
    silent! call append(1, "")


  else

    " Highlight the selected items in the directory
    silent! call fm#draw_selects()
  endif

  setlocal nomodifiable

  " Position the cursor
  silent! call fm#set_cursor()

  return ""
endfunction
" }}}
" Correct the cursor position if necessary {{{
function! fm#cursor_correct() abort

  let line = line(".")

  " Don't let the cursor go to the first line
  if line < 2
    let line = 2
  endif

  " Keep the cursor at the first column because I like it that way
  silent! call setpos(".", [0, line, 1, 0])

  return ""
endfunction
" }}}
" Toggle the selection of an item {{{
function! fm#toggle() abort

  " Get the item
  let item = getline(".")

  " Check if the directory contains selections
  if has_key(b:fm_selected, b:fm_current_dir)

    " The hypothetical index of the item in the selection list
    let index = index(b:fm_selected[b:fm_current_dir], item)

    " Check if the hypothetical index is in fact false
    if index == -1

      " The item is not selected, select it
      call add(b:fm_selected[b:fm_current_dir], item)
    else

      " The item is selected, 'de-select' it
      call remove(b:fm_selected[b:fm_current_dir], index)
    endif
  else

    " The selection list does not exist for this directory, generate it by
    " making the current item the only item in the selection list of the
    " current directory
    let b:fm_selected[b:fm_current_dir] = [item]
  endif

  " Go down a line
  normal! j
  silent! call fm#draw_selects()

  return ""
endfunction
" }}}
" Toggle the selection of everything in the current directory {{{
function! fm#toggle_all() abort

  " Check if the current directory has a selection list and the number of
  " items is equal to the number of lines in the buffer
  if has_key(b:fm_selected, b:fm_current_dir) && len(b:fm_selected[b:fm_current_dir]) == line("$") - 1

    " De-select everything
    let b:fm_selected[b:fm_current_dir] = []
  else

    " Select everything
    let b:fm_selected[b:fm_current_dir] = getline(2, "$")
  endif

  " Redraw the selections
  silent! call fm#draw_selects()

  return ""
endfunction
" }}}
" Toggle show hidden {{{
function! fm#toggle_hidden() abort

  " The current selected item
  let b:fm_history[b:fm_current_dir] = getline(".")

  " Toggle show hidden state
  if b:fm_show_hidden
    let b:fm_show_hidden = 0
  else
    let b:fm_show_hidden = 1
  endif

  " Refresh the buffer
  silent! call fm#render()
  return ""
endfunction
" }}}
" Rename a file/directory {{{
function! fm#rename(...) abort

  let item = getline(".")

  " Check if the current line is blank (an empty directory)
  if empty(item)
    call fm#error("Nothing to rename!")
    return ""
  endif

  " The present name of the item
  let old_name = substitute(item, '[@*=>|/]$', "", "")
  let old_name = b:fm_current_dir . "/" . old_name

  " Get the new name from the user
  if exists("a:1") && !empty(a:1)
    let new_name = (empty(matchstr(a:1, "/")) ? b:fm_current_dir . "/" : "") . a:1
  else
    let new_name = fm#prompt("New name: ", old_name)
  endif

  " User pressed ESC or whatever
  if empty(new_name)
    return ""
  endif

  let cmd = "mv " . fnameescape(old_name) . " " . fnameescape(new_name)

  " Check if a file/directory with that name exist already
  if !empty(glob(b:fm_current_dir . "/" . new_name))

    " Ask for confirmation
    let choice = fm#confirm("A file/directory with that name exists already. Overwrite")

    " User confirmed overwrite, delete it
    if choice ==? "y"
      silent! call system("rm -rf " . fnameescape(new_name))
    else
      return ""
    endif

  endif

  " Rename the item
  silent! call system(cmd)
  silent! call fm#render()

  " Move the cursor to the item
  let b:fm_current_dir = fnamemodify(new_name, ":h")
  let new_name = substitute(new_name, '/$', "", "")
  let new_name = substitute(new_name, '.*/', "", "")

  silent! call fm#render()
  silent! call search(new_name, "cW")

  return ""
endfunction
" }}}
" Create a new file/directory {{{
function! fm#new(type, ...) abort

  " The name of the item
  if exists("a:1") && !empty(a:1)
    let name = (empty(matchstr(a:1, "/")) ? b:fm_current_dir . "/" : "") . a:1
  else
    let name = fm#prompt("Create " . a:type . ": ", b:fm_current_dir . "/")
  endif

  " User pressed ESC or whatever
  if empty(name)
    return ""
  endif

  " Get rid of the '/' at the end because I'm paranoid
  let name = substitute(name, '/$', "", "")

  " Check if the file exists already
  if !empty(glob(name))

    " Ask for confirmation
    let choice = fm#confirm("A " . a:type . " with that name exists already. Overwrite")

    if choice ==? "y"

      " It was at this moment that the file knew, it f**ked up
      silent! call system("rm -rf " . fnameescape(name))
    else
      return ""
    endif
  endif

  " Rant time: Whenever I want to create a file, I want the parent directories
  " to just pop into existence if needed, you know. Not a SINGLE file manager
  " I have ever used have this feature, and it drives me nuts. Like let's say
  " I want to create a file and the parent directory doesn't exist. The file
  " manager is like 'Lol nope!'. Then I have to manually create the
  " directories leading up to the file and THEN create the file. It's SOOOOO
  " annoying. Therefore this file manager is smarter. If the parent directory
  " doesn't exist, it will simply ask you for confirmation if you want to
  " create them. And even that depends on the `g:fm#require_confirm` variable
  " being 'truthy'. If it's not, it won't even bother to ask, the directory
  " will just automatically be created without asking the user.
  let file_parent_dir = fnamemodify(name, ":h")

  " Check if the parent directory is non-existant
  if !isdirectory(file_parent_dir)

    " Ask for confirmation
    let choice = fm#confirm("Parent directory does not exist. Create it")

    " And the Lord said, 'Let there be parent directories'
    if choice ==? "y"
      silent! call mkdir(file_parent_dir, "p")
    else
      return ""
    endif
  endif

  " Focus the new item after creating it
  let b:fm_history[b:fm_current_dir] = fnamemodify(name, ":p:h:t")

  let file_name = fnamemodify(name, ":p:t")
  let b:fm_current_dir = file_parent_dir
  let cmd = (a:type ==# "file" ? "> " : "mkdir ") . fnameescape(name)

  silent! call system(cmd)
  silent! call fm#render()
  silent! call search(file_name, "cW")

  return ""
endfunction
" }}}
" Delete a file/directory {{{
function! fm#delete() abort

  let line = join(fm#get_items(), " ")

  if line == ''
    call fm#error("Nothing to delete!")
    return ""
  endif

  let choice = fm#confirm("Confirm delete")

  let cur_line = line(".") - 1

  if choice ==? "y"
    let cmd = "rm -rf " . line
    silent! call system(cmd)
    silent! call fm#render()

    " Delete always gives priority to the selected items, therefore this is
    " perfectly safe code. It won't randomly remove user selections. Checkmate
    " rustaceans.
    silent! call remove(b:fm_selected, b:fm_current_dir)
    silent! call fm#draw_selects()

    execute "normal! " . cur_line . "G"
  endif

  return ""
endfunction
" }}}
" Perform actions on items {{{
function! fm#action(...) abort

  " There are two optional arguments to this function. The first argument is
  " the text present at the front of the `:` prompt. The second argument is
  " the key pressed to move the cursor or whatever. Not the key notation
  " follows the feedkeys() notation and NOT 'key-notation'

  let line = join(fm#get_items(), " ")

  if line == ''
    call fm#error("Nothing to apply action on!")
    return ""
  endif

  let keys = ":" . (exists("a:1") ? a:1 : " ") . line
  let keys .= exists("a:2") ? a:2 : "\<Home>"

  call feedkeys(keys, "n")

  return ""
endfunction
" }}}
" Move or copy an item to a directory {{{
function! fm#move(...) abort
  let line = join(fm#get_items(), " ")

  " The 'anchor' to focus on after moving the item(s)
  if has_key(b:fm_selected, b:fm_current_dir) && len(b:fm_selected[b:fm_current_dir]) > 0
    let anchor = b:fm_selected[b:fm_current_dir][0]
  else
    let anchor = getline(".")
  endif

  if line == ''
    call fm#error("Nothing to " . (a:copy ? "copy" : "move") . "!")
    return ""
  endif

  if exists("a:2") && !empty(a:2)
    let dir = (empty(matchstr(a:2, "/")) ? b:fm_current_dir . "/" : "") . a:2
  else
    let prompt = (a:copy ? "Copy" : "Move") . " to: "
    let item = substitute(b:fm_current_dir, '/$', "", "g") . "/"
    let dir = fm#prompt(prompt, item)
  endif

  if empty(dir)
    return ""
  endif

  let dir = substitute(dir, '/$', "", "g")

  " Check if the directory is even valid
  if isdirectory(dir)
    let cmd = (exists("a:1") && a:1 ? "cp -r" : "mv") . " -f " . line . " " . dir . "/"

    silent! call system(cmd)
    let b:fm_current_dir = dir
    let b:fm_history[b:fm_current_dir] = anchor

    silent! call fm#render()
  else
    call fm#error("Error: invalid directory!")
  endif

  return ""
endfunction
" }}}
" Start edit mode {{{
function! fm#edit_start() abort

  let buffer = bufnr()

  " Something I REALLY admire about Emacs' `dired-mode'. One can just go into
  " this 'edit mode' and make changes and upon saving them, the file structure
  " gets changed. The idea is amazing, because that way we get to use the sane
  " keybindings of our favourite editor (checkmate, Emacs!) to manipulate the
  " file structure.

  if getbufline(buffer, "$")[0] ==# ''
    call fm#error("Nothing to edit!")
    return ""
  endif

  " Copy over the file structure to the edit buffer
  let text = getline(2, "$")
  let line = line(".") - 1

  let edit_buffer_name = fnamemodify(b:fm_current_dir, ":t")
  execute "edit ~/.cache/fm_edit" . buffer . " - " . edit_buffer_name . " - Edit"

  let b:fm_edit_target = buffer
  let edit_buffer = bufnr()

  silent! call append(1, text)
  silent! call deletebufline(bufnr(), 1, 1)

  " A limitation of edit mode. I couldn't figure out a way to make sure that
  " the files are renamed as they should be, so this is a way around it.
  " Basically if the number of lines before and after edit mode don't match
  " up, some lines are missing! In that case scream at the user and insult
  " him/her in order to assert maximum intellectual dominance. (lol)
  let b:fm_edit_total_lines = line("$")

  autocmd BufWritePost <buffer> call fm#edit_save()
  nnoremap <buffer> <silent> <C-c> :call fm#edit_close()<CR>
  silent! %s/[@*=>|\/]$//e

  setlocal nomodified
  execute "normal! " . line . "G"

  return ""
endfunction
" }}}
" Close the edit buffer {{{
function! fm#edit_close() abort

  let edit_buffer = bufnr()

  let target = fnamemodify(b:fm_edit_target, ":t")
  let edit_name = bufname()

  let line = line(".") + 1

  " This is a weird behaviour in Vim. Whenever I delete the buffer in a split,
  " the entire split gets closed, even though some buffers were being edited
  " from it. The buffers don't get deleted, it's just that the split pops out
  " of existence
  silent! execute "buffer " . b:fm_edit_target
  silent! execute "bdelete! " . edit_buffer
  silent! call delete(edit_name)

  silent! execute "normal! " . line . "G"
  return ""
endfunction
" }}}
" Save the changes made in edit mode {{{
function! fm#edit_save() abort

  if !exists("b:fm_edit_total_lines")
    return ""
  endif

  " THOU SHALT NOT DELETE ITEMS IN EDIT MODE!!!
  if line("$") != b:fm_edit_total_lines
    silent! call fm#close_edit()
    call fm#error("Some lines are missing! Can't save changes")
    return ""
  endif

  let text = getline(0, "$")
  let cur_line = line(".") + 1

  " Apply the changes made to the filestructure
  let dir = getbufvar(b:fm_edit_target, "fm_current_dir") . "/"
  let counter = 2

  for line in text

    let item = getbufline(b:fm_edit_target, counter)[0]
    let item = substitute(item, '[@*=>|/]$', "", "")

    let cmd = "mv " . dir . item . " " . dir . line
    silent! call system(cmd)

    let counter += 1
  endfor

  " Get rid of the edit buffer and render
  silent! call fm#edit_close()
  silent! call fm#render()

  silent! execute "normal! " . cur_line . "G"
  return ""
endfunction
" }}}
" Close Fm {{{
function! fm#close() abort
  execute "bdelete!"

  return ""
endfunction
" }}}
" Edit a file {{{
function! fm#edit(file) abort
  execute "edit " . a:file

  return ""
endfunction
" }}}
" Change the current directory of Fm {{{
" NOTE: This does NOT change the current directory of Vim
function! fm#change_dir(dir) abort

  " Store the position of the cursor in the history so that on a subsequent
  " return to it later in the SAME buffer, automatically position the cursor
  let b:fm_history[b:fm_current_dir] = getline(".")
  let b:fm_current_dir = substitute(a:dir, '^//', "/", "g")

  silent! call fm#set_name()
  silent! call fm#render()

  return ""
endfunction
" }}}
" Open the current item. {{{
function! fm#open(...) abort
  let item = b:fm_current_dir . "/"

  " Open the directory specified in the argument
  " If no argument supplied open the file/directory under the cursor
  if exists("a:1")
    let item .= a:1
  else
    let item .= getline(".")
  endif

  " Get rid of the format characters generated by ls
  let item = substitute(item, '[@*=>|]$', "", "g")

  " Figure out the true path of the directory
  let item = resolve(item)

  " Do whatever is needed
  if isdirectory(item)
    call fm#change_dir(item)
  elseif ! empty(glob(item))
    call fm#edit(item)
  else
    call fm#error("Invalid directory or file: " . item)
  endif

  return ""
endfunction
" }}}
" Go back a directory and position the cursor {{{
function! fm#up() abort

  if b:fm_current_dir ==# '/'
    return ""
  endif

  " Focus on the directory we were just viewing, not the history or whatever
  let tail = fnamemodify(b:fm_current_dir, ":t")
  silent! call fm#open("..")

  let b:fm_history[b:fm_current_dir] = tail
  silent! call fm#set_cursor()

  return ""
endfunction
" }}}
" Generate the mappings for fm {{{
function! fm#mappings() abort

  for [key, mapping] in items(g:fm#keys)

    " If the mapping doesn't end with a ')' add it to the end. Saves a bit of
    " typing
    if mapping !~? ')$'
      let mapping = mapping . "()"
    endif

    execute "nnoremap <buffer> <nowait> <silent> " . key . " <Cmd>call " . mapping . "<CR>"
  endfor

  return ""
endfunction
" }}}
" Start the file manager {{{
function! fm#start() abort

  if exists("b:fm_history")
    return ""
  endif

  " The real stuff

  " Figure out whether the file manager should be opened in the parent
  " directory of the current buffer, or the current buffer itself. Depends on
  " whether the current buffer is a directory or not.
  if isdirectory(resolve(expand("%:p")))
    execute "edit " . expand("%:p")

    " Just accept that this works lol. I don't remember what I did here

    let path = expand("%:p")
    let b:fm_current_dir = strpart(path, 0, strlen(path) - 1)
  else

    execute "edit " . expand("%:p:h")
    let b:fm_current_dir = substitute(expand("%:p"), '/$', "", "g")
  endif

  " The buffer level variables
  let b:fm_history = {}
  let b:fm_selected = {}
  let b:fm_show_hidden = g:fm#show_hidden
  let b:fm_ls_opts = g:fm#ls_opts
  let b:fm_require_confirm = g:fm#require_confirm

  " Important
  setlocal buftype=nofile
  setlocal nomodifiable

  " Black and white is meh unless it's a movie (Even then it's kinda meh lol)
  syntax match fmDirectory '.*/$'he=e-1
  syntax match fmExecutable '.*\*$'he=e-1
  syntax match fmLink '.*@$'he=e-1
  syntax match fmCurrent '\%1l.*$'

  " Generate mappings
  silent! call fm#mappings()

  " Prevent weird cursor movements. Muhahahahahahahaha!
  autocmd CursorMoved <buffer> call fm#cursor_correct()

  " Boom
  silent! call fm#render()
  silent! call fm#set_name()
  return ""
endfunction
" }}}
" NOOOOOO you have to use Netrw! Haha Fm go brrrrrr! {{{

" Netrw sucks hahaha!
let g:loaded_netrwPlugin = 1
command! Explore call fm#start()

" A little mapping to make life a bit easier
nnoremap <silent> <Leader>d :call fm#start()<CR>

" Open netrw automatically on a buffer read if it is a directory
autocmd BufEnter * if isdirectory(resolve(expand("%:p"))) | call fm#start() | endif
" }}}
