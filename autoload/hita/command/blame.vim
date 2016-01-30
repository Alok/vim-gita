let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:DateTime = s:V.import('DateTime')
let s:String = s:V.import('Data.String')
let s:MemoryCache = s:V.import('System.Cache.Memory')
let s:GitParser = s:V.import('Git.Parser')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:ProgressBar = s:V.import('ProgressBar')

highlight HitaPseudoSeparatorDefault
      \ term=underline cterm=underline ctermfg=8 gui=underline guifg=#363636
sign define HitaPseudoSeparatorSign
      \ texthl=SignColumn linehl=HitaPseudoSeparator

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'porcelain',
        \])
  return options
endfunction
function! s:get_blame_content(git, commit, filename, options) abort
  let options = s:pick_available_options(a:options)
  let options['commit'] = a:commit
  let options['--'] = [a:filename]
  let result = hita#execute(a:git, 'blame', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction

function! s:get_chunk_cache() abort
  if !exists('s:_chunk_cache')
    let s:_chunk_cache = s:MemoryCache.new()
  endif
  return s:_chunk_cache
endfunction
function! s:string_wrap(str, width) abort
  return map(
        \ s:String.wrap(a:str, a:width - 1),
        \ 'substitute(v:val, "^\s*\|\s*$", "", "g")',
        \)
endfunction
function! s:string_truncate(str, width) abort
  return strdisplaywidth(a:str) > a:width
        \ ? s:String.truncate(a:str, a:width - 4) . '...'
        \ : a:str
endfunction
function! s:format_timestamp(timestamp, timezone, now) abort
  let datetime  = s:DateTime.from_unix_time(a:timestamp, a:timezone)
  let timedelta = datetime.delta(a:now)
  if timedelta.duration().months() < 3
    return timedelta.about()
  elseif datetime.year() == a:now.year()
    return 'on ' . datetime.strftime('%d %b')
  else
    return 'on ' . datetime.strftime('%d %b, %Y')
  endif
endfunction
function! s:format_chunk(chunk, width, now, wrap, extra, srl, whitespaces) abort
  let summary = a:wrap
        \ ? s:string_wrap(a:chunk.summary, a:width)
        \ : [s:string_truncate(a:chunk.summary, a:width)]
  let revision = a:chunk.revision[:(a:srl-1)]
  let author = a:chunk.author
  let timestr = s:format_timestamp(
        \ a:chunk.author_time,
        \ a:chunk.author_tz,
        \ a:now,
        \)
  let author_info = author . ' authored ' . timestr
  let formatted = summary + [
        \ author_info . a:whitespaces[a:srl+1+len(author_info):] . revision
        \]
  if a:extra && has_key(a:chunk, 'previous')
    let prefix = 'Prev: '
    let previous_revision = a:chunk.previous[:(a:srl - 1)]
    let formatted += [
          \ a:whitespaces[a:srl+1+len(prefix):] . prefix . previous_revision,
          \]
  elseif a:extra && get(a:chunk, 'boundary')
    let formatted += [
          \ a:whitespaces[9:] . 'BOUNDARY',
          \]
  endif
  return formatted
endfunction
function! s:parse_blame(git, content, options) abort
  let options = extend({
        \ 'enable_pseudo_separator': -1,
        \ 'navigation_winwidth': -1,
        \ 'short_revision_length': -1,
        \}, a:options)
  let enable_pseudo_separator = options.enable_pseudo_separator == -1
        \ ? g:hita#command#blame#enable_pseudo_separator
        \ : options.enable_pseudo_separator
  let navigation_winwidth = options.navigation_winwidth == -1
        \ ? g:hita#command#blame#navigation_winwidth
        \ : options.navigation_winwidth
  let short_revision_length = options.short_revision_length == -1
        \ ? g:hita#command#blame#short_revision_length
        \ : options.short_revision_length
  " subtract columns for signs
  let navigation_winwidth -= 2
  let result = s:GitParser.parse_blame_to_chunks(a:content)
  let now = s:DateTime.now()
  let chunk_cache = s:get_chunk_cache()
  let min_chunk_lines = enable_pseudo_separator ? 2 : 1
  let navi_content = []
  let view_content = []
  let lineinfos = []
  let linerefs = []
  let separators = []
  let k = result.chunks[-1].linenum
  let linenum_width = len(k.final + get(k, 'nlines', 1))
  let linenum_format = printf('%%%ds %%s', linenum_width)
  let navi_width = navigation_winwidth - linenum_width - 1
  let whitespaces = repeat(' ', navi_width)
  let revisions = result.revisions
  let linenum = 1
  let progressbar = s:ProgressBar.new(len(result.chunks), {
        \ 'prefix': 'Constructing chunks: ',
        \ 'statusline': 1,
        \})
  try
    for chunk in result.chunks
      call extend(chunk, revisions[chunk.revision])
      let n_contents = len(chunk.contents)
      let cache_name = (n_contents > 2) . chunk.revision
      if !chunk_cache.has(cache_name)
        let formatted_chunk = s:format_chunk(
              \ chunk, navi_width, now,
              \ n_contents > 2,
              \ n_contents > 3,
              \ short_revision_length,
              \ whitespaces,
              \)
        call chunk_cache.set(cache_name, formatted_chunk)
      else
        let formatted_chunk = chunk_cache.get(cache_name)
      endif
      let n_lines = max([min_chunk_lines, n_contents])
      for cursor in range(n_lines)
        if cursor < n_contents
          call add(linerefs, linenum)
        endif
        call add(navi_content, printf(linenum_format,
              \ cursor >= n_contents ? '' : chunk.linenum.final + cursor,
              \ get(formatted_chunk, cursor, ''),
              \))
        call add(view_content, get(chunk.contents, cursor, ''))
        call add(lineinfos, {
              \ 'chunkref': chunk.index,
              \ 'linenum': {
              \   'original': chunk.linenum.original + cursor,
              \   'final': chunk.linenum.final + cursor,
              \ },
              \})
        let linenum += 1
      endfor
      call progressbar.update()
      " Add a pseudo separator line
      if !enable_pseudo_separator
        continue
      endif
      call add(navi_content, '')
      call add(view_content, '')
      call add(lineinfos, {
            \ 'chunkref': chunk.index,
            \ 'linenum': {
            \   'original': chunk.linenum.original + (n_lines - 1),
            \   'final': chunk.linenum.final + (n_lines - 1),
            \ },
            \})
      call add(separators, linenum)
      let linenum += 1
    endfor
  finally
    call progressbar.exit()
  endtry
  let offset = enable_pseudo_separator ? -2 : -1
  let blame = {
        \ 'chunks': result.chunks,
        \ 'lineinfos': lineinfos[:offset],
        \ 'linerefs': linerefs,
        \ 'separators': empty(separators) ? [] : separators[:offset],
        \ 'navi_content': navi_content[:offset],
        \ 'view_content': view_content[:offset],
        \}
  return blame
endfunction
function! s:display_pseudo_separators(separators, expr) abort
  let bufnum = bufnr(a:expr)
  execute printf('sign unplace * buffer=%d', bufnum)
  for linenum in a:separators
    execute printf(
          \ 'sign place %d line=%d name=HitaPseudoSeparatorSign buffer=%d',
          \ linenum, linenum, bufnum,
          \)
  endfor
endfunction

function! hita#command#blame#bufname(...) abort
  let options = hita#option#init('blame', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  let git = hita#get_or_fail()
  let commit = hita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = hita#variable#get_valid_filename(options.filename)
  return hita#autocmd#bufname(git, {
        \ 'content_type': 'blame',
        \ 'extra_options': [],
        \ 'commitish': commit,
        \ 'path': filename,
        \})
endfunction
function! hita#command#blame#call(...) abort
  let options = hita#option#init('blame', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \ '_enable_pseudo_separator': -1,
        \ '_navigation_winwidth': -1,
        \ '_short_revision_length': -1,
        \ '_verbose': 1,
        \})
  let git = hita#get_or_fail()
  let commit = hita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = hita#variable#get_valid_filename(options.filename)
  if options._verbose
    redraw | echo 'Retrieving a blame content. It may take some time ...'
  endif
  let content = s:get_blame_content(git, commit, filename, options)
  if options._verbose
    redraw | echo
  endif
  let result = {
        \ 'commit': commit,
        \ 'filename': filename,
        \ 'content': content,
        \}
  if get(options, 'porcelain')
    let result.blame = s:parse_blame(git, content, {
          \ 'enable_pseudo_separator': options._enable_pseudo_separator,
          \ 'navigation_winwidth': options._navigation_winwidth,
          \ 'short_revision_length': options._short_revision_length,
          \})
  endif
  return result
endfunction
function! hita#command#blame#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:hita#command#blame#default_opener
        \ : options.opener
  let bufname = hita#command#blame#bufname(options)
  if !empty(bufname)
    call hita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \})
    call hita#command#blame#navi#open(extend(copy(options), {
          \ 'opener': printf(
          \   'leftabove vertical %d split',
          \   g:hita#command#blame#navigation_winwidth,
          \ ),
          \}))
    setlocal scrollbind
    keepjump wincmd p
    setlocal scrollbind
    " BufReadCmd will call ...#edit to apply the content
  endif
endfunction
function! hita#command#blame#read(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let options['porcelain'] = 1
  let result = hita#command#blame#view#call(options)
  call hita#util#buffer#read_content(result.blame.view_content)
endfunction
function! hita#command#blame#edit(...) abort
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let options['porcelain'] = 1
  let result = hita#command#blame#call(options)
  call hita#set_meta('content_type', 'blame')
  call hita#set_meta('options', s:Dict.omit(options, ['force']))
  call hita#set_meta('commit', result.commit)
  call hita#set_meta('filename', result.filename)
  call hita#set_meta('blame', result.blame)
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nonumber nowrap nofoldenable foldcolumn=0
  setlocal nomodifiable
  setlocal scrollopt=ver
  augroup vim_hita_internal_blame
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer>
          \ setlocal nonumber nowrap nofoldenable foldcolumn=0
  augroup END
  call hita#util#buffer#edit_content(result.blame.view_content)
  call hita#command#blame#define_highlights()
  call hita#command#blame#display_pseudo_separators(result.blame.separators)
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita blame',
          \ 'description': 'Show what revision and author last modified each line of a file',
          \ 'complete_threshold': g:hita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to blame.',
          \   'If nothing is specified, it show a blame of HEAD.',
          \   'If <commit> is specified, it show a blame of the named <commit>.',
          \ ], {
          \   'complete': function('s:complete_commit'),
          \ })
    call s:parser.add_argument(
          \ 'filename', [
          \   'A filename which you want to blame.',
          \   'A filename of the current buffer is used when omited.',
          \ ],
          \)
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! hita#command#blame#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call hita#option#assign_commit(options)
  call hita#option#assign_filename(options)
  " extend default options
  let options = extend(
        \ deepcopy(g:hita#command#blame#default_options),
        \ options,
        \)
  call hita#command#blame#open(options)
endfunction
function! hita#command#blame#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction
function! hita#command#blame#define_highlights() abort
  highlight default link HitaPseudoSeparator HitaPseudoSeparatorDefault
endfunction
function! hita#command#blame#display_pseudo_separators(separators, ...) abort
  let expr = get(a:000, 0, '%')
  call s:display_pseudo_separators(a:separators, expr)
endfunction

call hita#util#define_variables('command#blame', {
      \ 'default_options': {},
      \ 'default_opener': 'tabnew',
      \ 'enable_pseudo_separator': 1,
      \ 'navigation_winwidth': 50,
      \ 'short_revision_length': 7,
      \})
