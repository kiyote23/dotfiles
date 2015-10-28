set nocompatible		" choose no compatibility with legacy vi
syntax enable
set encoding=utf-8
set showcmd
filetype plugin indent on
execute pathogen#infect()

"" set leader
let mapleader=","

"" Whitespace
set nowrap
set tabstop=2 shiftwidth=2
set expandtab
set backspace=indent,eol,start

"" Searching
set hlsearch
set incsearch
set ignorecase
set smartcase

"" Wordwrap
set wrap
set linebreak
set nolist    " list disables linebreak
set textwidth=0
set wrapmargin=0
set formatoptions+=1

"" Linenumbers
set number
set relativenumber

"" Spelling
autocmd BufRead,BufNewFile *.txt setlocal spell
autocmd BufRead,BufNewFile *.md setlocal spell
autocmd FileType gitcommit setlocal spell
set complete+=kspell

"" Markdown Syntax Highlighting for .md files
au BufRead,BufNewFile *.md set filetype=markdown

"" Get MacVim to load colorscheme
"" colorscheme solarized
"" let macvim_skip_colorscheme=1

"" adjust light or dark depending on time of day
let hour = strftime("%H")
if 6 <= hour && hour < 18
  set background=light
else
  set background=dark
endif
let g:solarized_termcolors=256
let g:solarized_visibility = "high"
let g:solarized_contrast = "high"
let g:solarized_termtrans=1
colorscheme solarized
"" togglebg#map("<F5>")

" Enable the list of buffers
let g:airline#extensions#tabline#enabled = 1

" Show just the filename
let g:airline#extensions#tabline#fnamemod = ':t'

"" CtrlP Setup
"" some default ignores
let g:ctrlp_custom_ignore = {
  \ 'dir' : '\v[\/](\.(git|hg|svn)|\_site)$',
  \ 'file': '\v\.(exe|so|dll|class|png|jpg|jpeg)$'
  \}

"" Use a leader instead of the actual named binding
nmap <leader>p :CtrlP<cr>

"" Easy bindings for its various modes
nmap <leader>bb :CtrlPBuffer<cr>
nmap <leader>bm :CtrlPMixed<cr>
nmap <leader>bs :CtrlPMRU<cr>

"" Buffergator setup
"" Use the right side of the screen
let g:buffergator_viewport_split_policy = 'R'

"" I want my own keymappings
let g:buffergator_suppress_keymaps = 1

" Go to previous buffer open
nmap <leader>jj :BuffergatorMruCyclePrev<cr>

"" Go to the next buffer open
nmap <leader>kk :BuffergatorMruCycleNext<cr>

"" View the entire list of buffers open
nmap <leader>bl :BuffergatorOpen<cr>

"" Shared bindings from Solution #1 from earlier
nmap <leader>T :enew<cr>
nmap <leader>bq :bp <BAR> bd #<cr>

"" Yank text to the OS X clipboard
noremap <leader>y "*y
noremap <leader>yy "*Y

"" Preserve indentation while pasting text from the OS X clipboard
noremap <leader>v :set paste<CR>:put *<CR>:set nopaste<CR>

"" Buffer stuff
set hidden
nmap <leader>T :enew<cr>
nmap <leader>l :bnext<cr>
nmap <leader>h :bprevious<cr>
nmap <leader>bq :bq <BAR> bd #<cr>
nmap <leader>bl :ls<CR>

"" Center cursor in middle of screen
nnoremap <leader>zz :let &scrolloff=999-&scrolloff<CR>

"" Open NERDtree
nmap <leader>nt :NERDTree<cr>

"" Edit and Reload .vimrc files
"" from https://github.com/aaronlake/vimrc/blob/master/setting/keymap.vim
nmap <silent> <leader>ev :e $MYVIMRC<cr>
nmap <silent> <leader>es :so $MYVIMRC<cr>

"" Send Email from Vim using Mail.app
nmap <leader>nm :NewMailApp<CR>
nmap <leader>sm :SendMailApp<CR>
