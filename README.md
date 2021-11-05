# Fm
![Demo](img/demo.png)

An extensible and minimalistic file manager for Vim.

## Install
Use your plugin manager of choice to install this plugin.

| Plugin manager | Command                                                                  |
| -------------- | ------------------------------------------------------------------------ |
| [Vim Plug](https://github.com/junegunn/vim-plug)  | `Plug 'shoumodip/fm.vim'`             |
| [Vundle](https://github.com/VundleVim/Vundle.vim) | `Plugin 'shoumodip/fm.vim'`           |
| [Dein](https://github.com/Shougo/dein.vim)        | `call dein#add('shoumodip/fm.vim')`   |
| [Minpac](https://github.com/k-takata/minpac)      | `call minpac#add('shoumodip/fm.vim')` |

Or use the builtin packages feature.

| Editor | Path                                   |
| ------ | ----                                   |
| Vim    | `cd ~/.vim/pack/plugins/start`         |
| NeoVim | `cd ~/.config/nvim/pack/plugins/start` |

```console
$ git clone https://github.com/shoumodip/fm.vim
```

## Usage
Run `:Ex` and press <kbd>C-h</kbd>. It should display a help window. Here is the online version.

|          Actions                          |              Others                      |
| ----------------------------------------- | ---------------------------------------- |
| <kbd>D</kbd> Delete                       | <kbd>x</kbd>         Mark/unmark item    |
| <kbd>R</kbd> Rename                       | <kbd>X</kbd>         Toggle marks        |
| <kbd>c</kbd> Copy to a directory          | <kbd>l</kbd>         Open item           |
| <kbd>m</kbd> Move to a directory          | <kbd>h</kbd>         Go up one directory |
| <kbd>p</kbd> Change permissions           | <kbd>i</kbd>         Start edit mode     |
| <kbd>s</kbd> Execute shell commands       | <kbd>q</kbd>         Quit                |
| <kbd>g</kbd> Run the next action globally | <kbd>r</kbd>         Refresh             |
| <kbd>f</kbd> Create a file                | <kbd>Enter</kbd>     Open item           |
| <kbd>d</kbd> Create a directory           | <kbd>BackSpace</kbd> Go up one directory |

- **Selected Items**: The marked items or the items under the cursor
- **Action**:         Operation on selected items in the current directory
- **Global Action**:  Operation on all selected items in the current buffer

## Ex-mode API
Same as Netrw.

| Command      | Description                   |
| ------------ | ----------------------------- |
| `Ex[plore]`  | Open Fm in the current window |
| `Sex[plore]` | Open Fm in a split            |
| `Vex[plore]` | Open Fm in a vertical split   |
| `Tex[plore]` | Open Fm in a new tab          |

## Configuration
Global Fm options follow the naming scheme of `g:fm#OPTION`. When a Fm buffer is opened, the state of the global options at that instant is copied over to buffer local variables. The global option ceases to have any effect in *that particular buffer*, it is now the job of the buffer level options. They follow the naming scheme of `b:fm_OPTION`. Even though the global options don't have any effect on already open buffers, they will affect the subsequent Fm buffers.

### `g:fm#ls_arguments`
The arguments supplied to `ls`.

- Type: `string`
- Default: `-vp --group-directories-first`

### `g:fm#hidden`
Whether dotfiles are hidden.

- Type: `boolean`
- Default: `v:false`

## Fm API
Check out `autoload/fm.vim`. Every single function is documented with `jsdoc` style parameter annotations.

## Plugins
The shell command (<kbd>s</kbd>) feature of Fm has support for [vim-dispatch](https://github.com/tpope/vim-dispatch) and [asyncrun.vim](https://github.com/skywind3000/asyncrun.vim)

## See also
- [vim-dirvish](https://github.com/justinmk/vim-dirvish)
