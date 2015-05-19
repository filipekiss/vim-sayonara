" vim: et sw=2 sts=2

" Plugin:      https://github.com/mhinz/vim-sayonara
" Description: Sane window/buffer deletion.
" Maintainer:  Marco Hinz <http://github.com/mhinz>

if exists('g:loaded_sayoara') || &compatible
  finish
endif
let g:loaded_sayoara = 1

let s:prototype = {}

" s:prototype.create_scratch_buffer() {{{1
function! s:prototype.create_scratch_buffer()
  enew!
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  return bufnr('%')
endfunction

" s:prototype.handle_modified_buffer() {{{1
function! s:prototype.handle_modified_buffer()
  if &modified
    echo 'There are unsaved changes. Close anyway? [y/n]: '
    if nr2char(getchar()) != 'y'
      redraw!
      return 'return'
    endif
  endif
  return ''
endfunction

" s:prototype.handle_window() {{{1
function! s:prototype.handle_window()
  let do_delete = !self.is_buffer_shown_in_another_window(self.target_buffer)

  " :Sayonara!

  if self.do_preserve
    let scratch_buffer = self.preserve_window()
    if do_delete
      " After preserve_window(), the target buffer might not exist
      " anymore (bufhidden=delete).
      if bufloaded(self.target_buffer)
            \ && (scratch_buffer != self.target_buffer)
        execute 'silent bdelete!' self.target_buffer
      endif
    endif
    return
  endif

  ":Sayonara

  " quickfix, location or cmdline window
  if &buftype == 'quickfix' || (&buftype == 'nofile' && &filetype == 'vim')
    try
      close
    catch /E444/  " cannot close last window
      quit!
    endtry
    return
  endif

  let valid_buffers = len(filter(range(1, bufnr('$')),
        \ 'buflisted(v:val) && v:val != self.target_buffer'))

  " Special case: don't quit last window if there are other listed buffers
  if (tabpagenr('$') == 1) && (winnr('$') == 1) && (valid_buffers >= 1)
    execute 'silent bdelete!' self.target_buffer
    return
  endif

  lclose
  try
    close
  catch /E444/  " cannot close last window
    quit!
  endtry

  if do_delete
    if bufloaded(self.target_buffer)
      execute 'silent bdelete!' self.target_buffer
    endif
  endif
endfunction

" s:prototype.preserve_window() {{{1
function! s:prototype.preserve_window()
  let altbufnr = bufnr('#')
  let valid_buffers = filter(range(1, bufnr('$')),
        \ 'buflisted(v:val) && v:val != self.target_buffer')

  if empty(valid_buffers)
    return self.create_scratch_buffer()
  elseif index(valid_buffers, altbufnr) == -1
    " get previous valid buffer
    let bufs = []
    for buf in valid_buffers
      if buf < self.target_buffer
        call insert(bufs, buf, 0)
      else
        call add(bufs, buf)
      endif
    endfor
    execute 'buffer!' bufs[0]
  else
    buffer! #
  endif
endfunction

" s:prototype.is_buffer_shown_in_another_window() {{{1
function! s:prototype.is_buffer_shown_in_another_window(target_buffer)
  let current_tab = tabpagenr()
  let other_tabs  = filter(range(1, tabpagenr('$')), 'v:val != current_tab')

  if len(filter(tabpagebuflist(current_tab), 'v:val == a:target_buffer')) > 1
    return 1
  endif

  for tab in other_tabs
    if index(tabpagebuflist(tab), a:target_buffer) != -1
      return 1
    endif
  endfor

  return 0
endfunction

" s:sayonara() {{{1
function! s:sayonara(do_preserve)
  let hidden = &hidden
  set hidden
  try
    let instance = extend(s:prototype, {
          \ 'do_preserve': a:do_preserve,
          \ 'target_buffer': bufnr('%'),
          \ })
    execute instance.handle_modified_buffer()
    call instance.handle_window()
  finally
    let &hidden = hidden
  endtry
endfunction
" }}}

command! -nargs=0 -complete=buffer -bang -bar Sayonara call s:sayonara(<bang>0)
