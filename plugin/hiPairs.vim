" ============================================================================
" Name:        hiPairs.vim
" Author:      Yggdroot <archofortune@gmail.com>
" Description: Highlight the pair surrounding the current cursor position.
"              The pairs are defined in &matchpairs.
" ============================================================================

if exists('g:loaded_hiPairs') || &compatible || !exists('##CursorMoved')
    finish
endif
let g:loaded_hiPairs = 1

if !exists('g:hiPairs_hl_matchPair')
    let g:hiPairs_hl_matchPair = {
                \ 'term'    : 'underline,bold',
                \ 'cterm'   : 'underline,bold',
                \ 'ctermfg' : 'NONE',
                \ 'ctermbg' : 'NONE',
                \ 'gui'     : 'underline,bold',
                \ 'guifg'   : 'NONE',
                \ 'guibg'   : 'NONE',
                \ }
endif

if !exists('g:hiPairs_hl_unmatchPair')
    let g:hiPairs_hl_unmatchPair = {
                \ 'term'    : 'underline,italic',
                \ 'cterm'   : 'NONE',
                \ 'ctermfg' : '231',
                \ 'ctermbg' : '196',
                \ 'gui'     : 'italic',
                \ 'guifg'   : 'White',
                \ 'guibg'   : 'Red',
                \ }
endif

if !exists('g:hiPairs_enable_matchParen')
    let g:hiPairs_enable_matchParen = 1
endif

if !exists('g:hiPairs_timeout')
    let g:hiPairs_timeout = 20
endif

if !exists('g:hiPairs_insert_timeout')
    let g:hiPairs_insert_timeout = 20
endif

if !exists('g:hiPairs_stopline_more')
    let g:hiPairs_stopline_more = 20000
endif

if !exists('g:hiPairs_skip')
    let g:hiPairs_skip = [
                \   'string',
                \   'character',
                \   'singlequote',
                \   'comment'
                \ ]
endif
let g:hiPairs_exists_matchaddpos = exists('*matchaddpos')

augroup hiPairs
    autocmd!
    autocmd VimEnter * call s:InitColor()

    autocmd CursorHold,InsertLeave,BufWinEnter,WinEnter * call s:HiPairs()
    autocmd InsertEnter,WinLeave,BufWinLeave * silent call s:ClearMatch(1)
augroup END

let s:cpo_save = &cpoptions
set cpoptions&vim

let s:s_skip = '!empty(' .
            \       'filter(' .
            \           'map(' .
            \               'synstack(line("."), col(".")),' .
            \               '''synIDattr(v:val, "name")''' .
            \           '),' .
            \           '''v:val =~? "' . join(g:hiPairs_skip, '\\|') . '"''' .
            \       ')' .
            \ ')'

" a and b is of type [line, col]
function! s:Compare(a, b)
    return a:a[0] == a:b[0] ? a:a[1] - a:b[1] : a:a[0] - a:b[0]
endfunction

" Disable matchparen.vim
function! s:DisableMatchParen()
    if !g:hiPairs_enable_matchParen
        NoMatchParen
    endif
endfunction

" Enable matchparen.vim
function! s:EnableMatchParen()
    if !g:hiPairs_enable_matchParen
        DoMatchParen
    endif
endfunction

function! s:InitColor()
    let l:arguments = ''

    for [l:key, l:value] in items(g:hiPairs_hl_matchPair)
        let l:arguments .= ' ' . l:key . '=' . l:value
    endfor

    exec 'hi default hiPairs_matchPair' . l:arguments

    let l:arguments = ''

    for [l:key, l:value] in items(g:hiPairs_hl_unmatchPair)
        let l:arguments .= ' ' . l:key . '=' . l:value
    endfor

    exec 'hi default hiPairs_unmatchPair' . l:arguments
endfunction

function! s:InitMatchPairs()
    let b:pair_list = split(&l:matchpairs, '.\zs[:,]')
    let b:pair_list_ok = map(
                \   copy(b:pair_list),
                \   '(v:val =~# "]\\|[" ? "\\" . v:val : v:val)'
                \ )
endfunction

function! s:ClearMatch(clear_old)
    if exists('w:hiPairs_ids')
        try
            for l:id in w:hiPairs_ids
                call matchdelete(l:id)
            endfor
        catch /^Vim\%((\a\+)\)\=:E803/
        endtry
    endif
    if a:clear_old && exists('b:hiPairs_old_pos')
        unlet! b:hiPairs_old_pos
    endif
    " Store the IDs returned by matchadd
    let w:hiPairs_ids = []
endfunction

function! s:IsBufferChanged()
    if !exists('b:hiPairs_changedtick')
        let b:hiPairs_changedtick = -1
    endif

    if b:hiPairs_changedtick != b:changedtick
        let b:hiPairs_changedtick = b:changedtick
        return 1
    endif

    return 0
endfunction

function! s:searchPair(dir)
endfunction

function! s:HiPairs()
    if !exists('b:pair_list')
        call s:InitMatchPairs()
    endif

    if empty(b:pair_list)
        return
    endif

    " Avoid that we remove the popup menu.
    " Return when there are no colors (looks like the cursor jumps).
    if pumvisible() || (&t_Co < 8 && !has('gui_running'))
        return
    endif

    " Limit the search to lines visible in the window.
    let l:stopline_bottom = line('w$')
    let l:stopline_top = line('w0')

    if !exists('b:hiPairs_old_pos')
        let b:hiPairs_old_pos = [[0, 0], [0, 0]]
    endif
    let l:on_special = 0
    let l:cur_line = line('.')
    let l:cur_col = col('.')
    let l:text = getline('.')
    let l:cur_char = l:text[l:cur_col - 1]
    let l:idx = index(b:pair_list, l:cur_char)
    let l:timeout = g:hiPairs_timeout

    let [l:l_col,l:l_line] = [0, 0]
    let [l:r_col,l:r_line] = [0, 0]

    execute(' if (' . s:s_skip . ') | let l:on_special = 1 | endif')

    " Character under cursor is not bracket
    if l:idx < 0 || l:on_special == 1
        let [l:l_line, l:l_col] = searchpairpos(
                    \   b:pair_list_ok[0],
                    \   '',
                    \   b:pair_list_ok[1],
                    \   'nbW',
                    \   s:s_skip,
                    \   max([l:stopline_top - g:hiPairs_stopline_more, 1]),
                    \   l:timeout,
                    \ )
        let l:k = 0

        for l:i in range(2, len(b:pair_list)-1, 2)
            let l:pos = searchpairpos(
                        \   b:pair_list_ok[l:i],
                        \   '',
                        \   b:pair_list_ok[l:i + 1],
                        \   'nbW',
                        \   s:s_skip,
                        \   max([
                        \       l:l_line,
                        \       l:stopline_top - g:hiPairs_stopline_more,
                        \       1
                        \   ]),
                        \   l:timeout,
                        \ )

            if s:Compare(l:pos, [l:l_line, l:l_col]) > 0
                let [l:l_line, l:l_col] = l:pos
                let l:k = l:i
            endif
        endfor

        if [l:l_line, l:l_col] != [0, 0]
            if s:IsBufferChanged() == 0 &&
                        \ b:hiPairs_old_pos[0] == [l:l_line, l:l_col]
                return
            endif

            let [l:r_line, l:r_col] = searchpairpos(
                        \   b:pair_list_ok[l:k],
                        \   '',
                        \   b:pair_list_ok[l:k + 1],
                        \   'nW',
                        \   s:s_skip,
                        \   l:stopline_bottom + g:hiPairs_stopline_more,
                        \   l:timeout,
                        \ )
        else
            let [l:r_line, l:r_col] = searchpairpos(
                        \   b:pair_list_ok[0],
                        \   '',
                        \   b:pair_list_ok[1],
                        \   'nW',
                        \   s:s_skip,
                        \   l:stopline_bottom + g:hiPairs_stopline_more,
                        \   l:timeout,
                        \ )

            for l:i in range(2, len(b:pair_list) - 1, 2)
                let l:stopline = l:r_line > 0 ?
                            \ l:r_line :
                            \ l:stopline_bottom + g:hiPairs_stopline_more

                let l:pos = searchpairpos(
                            \   b:pair_list_ok[l:i],
                            \   '',
                            \   b:pair_list_ok[l:i + 1],
                            \   'nW',
                            \   s:s_skip,
                            \   l:stopline,
                            \   l:timeout,
                            \ )

                if [l:r_line, l:r_col] == [0, 0] || l:pos != [0, 0] &&
                            \ s:Compare(l:pos, [l:r_line, l:r_col]) < 0

                    let [l:r_line, l:r_col] = l:pos
                endif
            endfor
        endif
    else 
        " Character under cursor is a left bracket
        if l:idx % 2 == 0
            let [l:l_line, l:l_col] = [l:cur_line, l:cur_col]
            if s:IsBufferChanged() == 0 &&
                        \ b:hiPairs_old_pos[0] == [l:l_line, l:l_col]
                return
            endif
            " Search forward
            let [l:r_line, l:r_col] = searchpairpos(
                        \   b:pair_list_ok[l:idx],
                        \   '',
                        \   b:pair_list_ok[l:idx + 1],
                        \   'nW',
                        \   s:s_skip,
                        \   l:stopline_bottom + g:hiPairs_stopline_more,
                        \   l:timeout
                        \ )
        " Character under cursor is a right bracket
        elseif l:idx % 1 == 0
            let [l:r_line, l:r_col] = [l:cur_line, l:cur_col]
            if s:IsBufferChanged() == 0 &&
                        \ b:hiPairs_old_pos[1] == [l:r_line, l:r_col]
                return
            endif
            " Search backward
            let [l:l_line, l:l_col] = searchpairpos(
                        \   b:pair_list_ok[l:idx - 1],
                        \   '',
                        \   b:pair_list_ok[l:idx],
                        \   'nbW',
                        \   s:s_skip,
                        \   max([l:stopline_top - g:hiPairs_stopline_more, 1]),
                        \   l:timeout
                        \ )
        endif
    endif

    let b:hiPairs_old_pos = [[l:l_line, l:l_col], [l:r_line, l:r_col]]

    " Remove any previous match.
    call s:ClearMatch(0)

    if [l:r_line, l:r_col] == [0, 0]
        if [l:l_line, l:l_col] == [0, 0]
            return
        else
            "highlight the left unmatched pair
            if g:hiPairs_exists_matchaddpos
                let l:id = matchaddpos(
                            \   'hiPairs_unmatchPair',
                            \   [[l:l_line, l:l_col]],
                            \ )
            else
                let l:id = matchadd(
                            \   'hiPairs_unmatchPair',
                            \   '\%' . l:l_line . 'l\%' . l:l_col . 'c',
                            \ )
            endif
            call add(w:hiPairs_ids, l:id)
        endif
    else
        if [l:l_line, l:l_col] == [0, 0]
            "highlight the right unmatched pair
            if g:hiPairs_exists_matchaddpos
                let l:id = matchaddpos(
                            \   'hiPairs_unmatchPair',
                            \   [[l:r_line, l:r_col]],
                            \ )
            else
                let l:id = matchadd(
                            \   'hiPairs_unmatchPair',
                            \   '\%' . l:r_line . 'l\%' . l:r_col . 'c',
                            \ )
            endif
            call add(w:hiPairs_ids, l:id)
        else
            if l:l_line < l:stopline_top && l:r_line > l:stopline_bottom
                return
            else
                "highlight the matching pairs
                if g:hiPairs_exists_matchaddpos
                    let l:id = matchaddpos(
                                \   'hiPairs_matchPair',
                                \   [[l:l_line, l:l_col], [l:r_line, l:r_col]],
                                \ )
                else
                    let l:id = matchadd(
                        \ 'hiPairs_matchPair',
                        \ '\(\%' . l:l_line . 'l\%' . l:l_col . 'c\)\|' .
                        \ '\(\%' . l:r_line . 'l\%' . l:r_col . 'c\)',
                    \ )
                endif
                call add(w:hiPairs_ids, l:id)
            endif
        endif
    endif
endfunction

" Define commands that will disable and enable the plugin.
command! HiPairsDisable windo silent! call s:ClearMatch(1) |
            \ unlet! g:loaded_hiPairs |
            \ augroup! hiPairs

command! HiPairsEnable runtime plugin/hiPairs.vim
command! HiPairsToggle
            \ if exists('g:loaded_hiPairs') |
            \   exec 'HiPairsDisable' |
            \ else |
            \   exec 'HiPairsEnable' |
            \ endif

let &cpoptions = s:cpo_save
unlet s:cpo_save
