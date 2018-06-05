" Syntax Highlighting
if has("syntax")
    syntax on
endif

" tmux 256
if &term == "screen"
	set t_Co=256
endif

" 보이지 않는 글씨 보이기
" :set list, :set nolist

" Sometimes an error occurs. Why?
" set listchars=eol:¬,tab:→,trail:~,extends:»,precedes:«,space:␣

" 자동 들여쓰기
set autoindent
set cindent

" 자동 인덴트할 때 너비
set tabstop=4
set shiftwidth=4
set expandtab

" 소프트탭
set softtabstop=4

" 넘버
set nu

" 컬러테마
colorscheme twilight256

" 상태바 표시를 항상한다
set laststatus=2
set statusline=\ %<%l:%v\ [%P]%=%a\ %h%m%r\ %F\

" 검색어 하이라이팅
set hlsearch

" 작업 중인 파일 외부에서 변경됬을 경우 자동으로 불러옴
set autoread


" Default mapping
let g:multi_cursor_next_key='<C-a>'

set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim

" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'airblade/vim-gitgutter'
Plugin 'terryma/vim-multiple-cursors'
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line
