" --- Basic settings ---
set number
set clipboard=unnamedplus

" --- Plugins ---
call plug#begin()
Plug 'scrooloose/nerdtree'
call plug#end()

" --- Keybindings ---
nnoremap <C-b> :NERDTreeToggle<CR>
