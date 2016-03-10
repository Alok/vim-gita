let s:V = vital#of('vim_gita')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitInfo = s:V.import('Git.Info')
let s:GitProcess = s:V.import('Git.Process')
let s:GitProcessOld = s:V.import('Git.ProcessOld')

function! gita#vital() abort
  return s:V
endfunction

function! gita#throw(...) abort
  let msg = join(a:000)
  throw printf('vim-gita: %s', msg)
endfunction

function! gita#execute(git, args, ...) abort
  call s:GitProcess.set_config({
        \ 'executable': g:gita#executable,
        \ 'arguments':  g:gita#arguments,
        \})
  let options = get(a:000, 0, {})
  return s:GitProcess.execute(a:git, a:args, options)
endfunction

function! gita#execute_old(git, name, ...) abort
  call s:GitProcessOld.set_config({
        \ 'executable': g:gita#executable,
        \ 'arguments':  g:gita#arguments,
        \})
  let options = get(a:000, 0, {})
  let config  = get(a:000, 1, {})
  if !&verbose
    return s:GitProcessOld.execute(a:git, a:name, options, config)
  else
    let result = s:GitProcessOld.execute(a:git, a:name, options, config)
    call s:Prompt.debug(printf(
          \ 'o %s: %s', (result.status ? 'Fail' : 'OK'), join(result.args),
          \))
    if &verbose >= 2
      call s:Prompt.debug(printf(
            \ '| status: %d', result.status,
            \))
      call s:Prompt.debug('| --- content ---')
      for line in result.content
        call s:Prompt.debug(line)
      endfor
      call s:Prompt.debug('| ----- end -----')
    endif
    call s:Prompt.debug('')
    return result
  endif
endfunction

function! gita#get_git_version() abort
  if exists('s:git_version')
    return s:git_version
  endif
  let s:git_version = s:GitInfo.get_git_version()
  return s:git_version
endfunction

function! s:is_debug() abort
  " Used to tell if gita is in debug mode
  return &verbose
endfunction

function! s:is_batch() abort
  " Used to tell if gita is in batch mode (test mode)
  return g:gita#test
endfunction

call s:Prompt.set_config({
      \ 'debug': function('s:is_debug'),
      \ 'batch': function('s:is_batch'),
      \})
call gita#util#define_variables('', {
      \ 'test': 0,
      \ 'develop': 1,
      \ 'executable': 'git',
      \ 'arguments': ['-c', 'color.ui=false', '--no-pager'],
      \ 'complete_threshold': 100,
      \})
