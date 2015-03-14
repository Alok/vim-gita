"******************************************************************************
" vim-gita utility
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:get_vital() " {{{
  if !exists('s:_vital_module_Vital')
    " TODO replace it to 'vim_gita'
    let s:_vital_module_Vital = vital#of('vital')
  endif
  return s:_vital_module_Vital
endfunction " }}}
function! gita#util#import(name) " {{{
  let cache_name = printf('_vital_module_%s', substitute(a:name, '\.', '_', 'g'))
  if !has_key(s:, cache_name)
    let s:[cache_name] = s:get_vital().import(a:name)
  endif
  return s:[cache_name]
endfunction " }}}
function! gita#util#is_numeric(...) " {{{
  let X = gita#util#import('Prelude')
  return call(X.is_numeric, a:000, X)
endfunction " }}}
function! gita#util#is_number(...) " {{{
  let X = gita#util#import('Prelude')
  return call(X.is_number, a:000, X)
endfunction " }}}
function! gita#util#is_float(...) " {{{
  let X = gita#util#import('Prelude')
  return call(X.is_float, a:000, X)
endfunction " }}}
function! gita#util#is_string(...) " {{{
  let X = gita#util#import('Prelude')
  return call(X.is_string, a:000, X)
endfunction " }}}
function! gita#util#is_funcref(...) " {{{
  let X = gita#util#import('Prelude')
  return call(X.is_funcref, a:000, X)
endfunction " }}}
function! gita#util#is_list(...) " {{{
  let X = gita#util#import('Prelude')
  return call(X.is_list, a:000, X)
endfunction " }}}
function! gita#util#is_dict(...) " {{{
  let X = gita#util#import('Prelude')
  return call(X.is_dict, a:000, X)
endfunction " }}}
function! gita#util#flatten(...) " {{{
  let X = gita#util#import('Data.List')
  return call(X.flatten, a:000, X)
endfunction " }}}

function! gita#util#echomsg(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echomsg m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#util#input(hl, msg, ...) abort " {{{
  execute 'echol' a:hl
  try
    return input(a:msg, get(a:000, 0, ''))
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#util#debug(...) abort " {{{
  if !get(g:, 'gita#debug', 0)
    return
  endif
  let parts = []
  for x in a:000
    call add(parts, string(x))
    silent unlet! x
  endfor
  call gita#util#echomsg('Comment', 'DEBUG: ' . join(parts))
endfunction " }}}
function! gita#util#info(message, ...) abort " {{{
  let title = get(a:000, 0, '')
  if strlen(title)
    call gita#util#echomsg('Title', title)
    call gita#util#echomsg('None', a:message)
  else
    call gita#util#echomsg('Title', a:message)
  endif
endfunction " }}}
function! gita#util#warn(message, ...) abort " {{{
  let title = get(a:000, 0, '')
  if strlen(title)
    call gita#util#echomsg('Warning', title)
    call gita#util#echomsg('None', a:message)
  else
    call gita#util#echomsg('Warning', a:message)
  endif
endfunction " }}}
function! gita#util#error(message, ...) abort " {{{
  let title = get(a:000, 0, '')
  if strlen(title)
    call gita#util#echomsg('Error', title)
    call gita#util#echomsg('None', a:message)
  else
    call gita#util#echomsg('Error', a:message)
  endif
endfunction " }}}
function! gita#util#ask(message, ...) abort " {{{
  return gita#util#input('Question', a:message, get(a:000, 0, ''))
endfunction " }}}
function! gita#util#asktf(message, ...) abort " {{{
  let result = gita#util#ask(
        \ printf('%s [yes/no]: ', a:message),
        \ get(a:000, 0, ''))
  while yesno !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if result == ''
      call gita#util#warn('Canceled.')
      break
    endif
    call gita#util#error('Invalid input.')
    let result = gita#util#ask(printf('%s [yes/no]: ', a:message))
  endwhile
  redraw
  return result =~? 'y\%[es]'
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
