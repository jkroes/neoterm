let g:neoterm.repl = { 'loaded': 0 }

function! g:neoterm.repl.instance()
  if !has_key(l:self, 'instance_id')
    if !g:neoterm.has_any()
      call neoterm#new({ 'handlers': neoterm#repl#handlers() })
    end

    call neoterm#repl#term(g:neoterm.last_id)
  end

  return g:neoterm.instances[l:self.instance_id]
endfunction

function! neoterm#repl#handlers()
  return { 'on_exit': function('s:repl_result_handler') }
endfunction

function! s:repl_result_handler(...)
  let g:neoterm.repl.loaded = 0
endfunction

function! neoterm#repl#term(id)
  if has_key(g:neoterm.instances, a:id)
    let g:neoterm.repl.instance_id = a:id
    let g:neoterm.repl.loaded = 1

    if !empty(get(g:, 'neoterm_repl_command', ''))
          \ && g:neoterm_auto_repl_cmd
          \ && !g:neoterm_direct_open_repl
      call neoterm#exec({
            \ 'cmd': [g:neoterm_repl_command, g:neoterm_eof],
            \ 'target': g:neoterm.repl.instance().id
            \ })
    end
  else
    echoe printf('There is no %s term.', a:id)
  end
endfunction

function! neoterm#repl#set(value)
  let g:neoterm_repl_command = a:value
endfunction

function! neoterm#repl#selection()
  let [l:lnum1, l:col1] = getpos("'<")[1:2]
  let [l:lnum2, l:col2] = getpos("'>")[1:2]
  if &selection ==# 'exclusive'
    let l:col2 -= 1
  endif
  let l:lines = getline(l:lnum1, l:lnum2)
  let l:lines[-1] = l:lines[-1][:l:col2 - 1]
  let l:lines[0] = l:lines[0][l:col1 - 1:]
  call g:neoterm.repl.exec(l:lines)
endfunction

function! neoterm#repl#line(...)
  let l:lines = getline(a:1, a:2)
  call g:neoterm.repl.exec(l:lines)
endfunction

function! neoterm#repl#opfunc(type)
  let [l:lnum1, l:col1] = getpos("'[")[1:2]
  let [l:lnum2, l:col2] = getpos("']")[1:2]
  let l:lines = getline(l:lnum1, l:lnum2)
  if a:type ==# 'char'
    let l:lines[-1] = l:lines[-1][:l:col2 - 1]
    let l:lines[0] = l:lines[0][l:col1 - 1:]
  endif
  call g:neoterm.repl.exec(l:lines)
endfunction

function! s:store_line()
  let prev_line = ''

  function! Inner(command) closure
    " If our repl is (i)Python, remove lines consisting only of whitespace.
    " Such lines trigger premature execution of submitted code (e.g., before
    " all lines defining a function are submitted)
    if (g:neoterm_repl_command =~ 'python')
      let pycommand = filter(a:command, 'v:val !~ "^\\s*$"')
      " If not iPython, add a blank line between the end of an indented line and
      " an unindented line. Python throws a syntax error, e.g., if following a
      " function definition immediately by a call to a function, within a REPL
      if (g:neoterm_repl_command !~ 'ipython')
        let index = 0
        let ipycommand = []

        while index < (len(pycommand))
          let prev_indent = len(matchstr(prev_line, '^\s*'))
          let curr_line = pycommand[index]
          let curr_indent = len(matchstr(curr_line, '^\s*'))

          if ((prev_indent > curr_indent) && curr_indent == 0)
            call add(ipycommand, '')
          endif
          call add(ipycommand, curr_line)

          let prev_line = curr_line
          let l:index += 1
        endwhile
      endif
      let command = get(l:, 'ipycommand', pycommand)
    else
      let command = a:command
    endif
    call g:neoterm.repl.instance().exec(add(command, g:neoterm_eof))
  endfunction

  return funcref('Inner')
endfunction

let g:neoterm.repl.exec = s:store_line()
