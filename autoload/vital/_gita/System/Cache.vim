" ___vital___
" NOTE: lines between '" ___vital___' is generated by :Vitalize.
" Do not mofidify the code nor insert new lines before '" ___vital___'
if v:version > 703 || v:version == 703 && has('patch1170')
  function! vital#_gita#System#Cache#import() abort
    return map({'unregister': '', '_vital_depends': '', 'register': '', 'new': '', '_vital_loaded': ''},  'function("s:" . v:key)')
  endfunction
else
  function! s:_SID() abort
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze__SID$')
  endfunction
  execute join(['function! vital#_gita#System#Cache#import() abort', printf("return map({'unregister': '', '_vital_depends': '', 'register': '', 'new': '', '_vital_loaded': ''}, \"function('<SNR>%s_' . v:key)\")", s:_SID()), 'endfunction'], "\n")
  delfunction s:_SID
endif
" ___vital___
let s:save_cpo = &cpo
set cpo&vim

let s:registry = {}
function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:P = a:V.import('Prelude')
  call s:register('dummy',      'System.Cache.Dummy')
  call s:register('memory',     'System.Cache.Memory')
  call s:register('file',       'System.Cache.File')
  call s:register('singlefile', 'System.Cache.SingleFile')
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \ 'System.Cache.Dummy',
        \ 'System.Cache.Memory',
        \ 'System.Cache.File',
        \ 'System.Cache.SingleFile',
        \]
endfunction

function! s:new(name, ...) abort
  if !has_key(s:registry, a:name)
    throw printf(
          \ 'vital: System.Cache: A cache system "%s" is not registered.',
          \ a:name,
          \)
  endif
  let class = s:registry[a:name]
  return call(class.new, a:000, class)
endfunction

function! s:register(name, class) abort
  let class = s:P.is_string(a:class) ? s:V.import(a:class) : a:class
  let s:registry[a:name] = class
endfunction
function! s:unregister(name) abort
  unlet! s:registry[a:name]
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
