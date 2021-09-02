syntax on
set termguicolors
colorscheme nord

set cursorline
set colorcolumn =81
let &t_SI = "\<Esc>[6 q"
let &t_SR = "\<Esc>[4 q"
let &t_EI = "\<Esc>[2 q"

set showtabline =2
set scrolloff =12

set shiftwidth =2
set tabstop =2

set autochdir
set expandtab
set hidden
set hlsearch
set ignorecase
set incsearch
set nocompatible
set number
set relativenumber
set showcmd
set smartcase
set swapfile

set dir =~/.cache/neovim
set encoding =UTF-8
set history =999
set wildignore +=*/tmp/*,*.so,*.swp,*.zip,*.svg,*.png,*.jpg,*.gif,node_modules,dist,build
set ttimeoutlen =0

set nobackup nowritebackup

" ------------------------------------------------------------------------------
"  common
" ------------------------------------------------------------------------------

" leader key
map <Space> <leader>

" unmap arrow keys
no <down>   <Nop>
no <left>   <Nop>
no <right>  <Nop>
no <up>     <Nop>
ino <down>  <Nop>
ino <left>  <Nop>
ino <right> <Nop>
ino <up>    <Nop>
vno <down>  <Nop>
vno <left>  <Nop>
vno <right> <Nop>
vno <up>    <Nop>

" save & quit
nmap <leader>w :w<CR>
nmap <leader><leader>w :wa<CR>
nmap <leader>q :q<CR>
nmap <leader><leader>q :qa!<CR>

" buffer manipulation
nmap <silent> <C-h> :bp<CR>
nmap <silent> <C-l> :bn<CR>
nmap <silent> <C-w> :bd<CR>

" window manipulation
nmap <silent> <C-A-k> :wincmd k<CR>
nmap <silent> <C-A-j> :wincmd j<CR>
nmap <silent> <C-A-h> :wincmd h<CR>
nmap <silent> <C-A-l> :wincmd l<CR>

" toggle search highlighting
nmap <silent> <F3> :set hlsearch!<CR>

" ------------------------------------------------------------------------------
"  lightline
" ------------------------------------------------------------------------------

" disable --INSERT-- message
set noshowmode

let g:lightline = {
\  'colorscheme': 'nord',
\  'active': {
\    'left': [ [ 'mode', 'paste' ],
\              [ 'readonly', 'cocstatus', 'gitbranch', 'gitstatus' ] ],
\  },
\  'tabline': {
\    'left': [ ['buffers'] ],
\    'right': [ [] ],
\  },
\  'component_expand': {
\    'buffers': 'lightline#bufferline#buffers',
\  },
\  'component_type': {
\    'buffers': 'tabsel',
\  },
\  'component_function': {
\    'cocstatus': 'coc#status',
\    'gitbranch': 'LightlineGitBranch',
\    'gitstatus': 'LightlineGitStatus',
\  },
\}

let g:lightline#bufferline#unnamed = '[No Name]'
let g:lightline#bufferline#filename_modifier = ':t'

function! LightlineGitBranch() abort
  return get(g:, 'coc_git_status', '')
endfunction

function! LightlineGitStatus() abort
  let status = get(b:, 'coc_git_status', '')
  let trimmed = substitute(status, '^\s*\(.\{-}\)\s*$', '\1', '')
  return trimmed
endfunction

nmap <leader>b :echo get(b:, 'coc_git_blame', '')<CR>

" ------------------------------------------------------------------------------
"  indentLine
" ------------------------------------------------------------------------------

autocmd FileType markdown,json let b:indentLine_enabled=0

" ------------------------------------------------------------------------------
"  NERDTree
" ------------------------------------------------------------------------------

let g:NERDTreeWinSize = 45
let g:NERDTreeCaseSensitiveSort = 1
let g:NERDTreeDirArrowExpandable = ''
let g:NERDTreeDirArrowCollapsible = ''

" toggle Nerdtree
nmap <silent> <C-n> :NERDTreeToggle<CR>

" find current buffer in Nerdtree
nmap <leader>o :NERDTreeFind<cr>

" ------------------------------------------------------------------------------
"  coc.nvim
" ------------------------------------------------------------------------------

" better display for messages
set cmdheight=2

" smaller updatetime for CursorHold & CursorHoldI
set updatetime=300

" don't give |ins-completion-menu| messages
set shortmess+=c

" always show signcolumns
set signcolumn=yes

" completion
inoremap <silent><expr> <TAB>
  \ pumvisible() ? "\<C-n>" :
  \ <SID>check_back_space() ? "\<TAB>" :
  \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

" trigger completion
inoremap <silent><expr> <c-space> coc#refresh()

" navigate diagnostics
nmap <silent><C-k> <Plug>(coc-diagnostic-prev)
nmap <silent><C-j> <Plug>(coc-diagnostic-next)

" gotos
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" reference rename
nmap <leader>rn <Plug>(coc-rename)

" documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>

" codeaction of selected region
xmap <leader>a <Plug>(coc-codeaction-selected)
nmap <leader>a <Plug>(coc-codeaction-selected)

" codeaction of current line
nmap <leader>a <Plug>(coc-codeaction)

" format selected region
xmap <leader>f :call CocAction('format')<CR>
nmap <leader>f :call CocAction('format')<CR>
xmap <leader>x :CocFix<CR>
nmap <leader>x :CocFix<CR>

" show all diagnostics
nnoremap <silent> <leader>e :<C-u>CocList diagnostics<cr>

" highlight symbol under cursor on CursorHold
autocmd CursorHold * silent call CocActionAsync('highlight')

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction
