#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-incremental.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
command mkdir -p -- "$ZDOTDIR"
zstyle ':fsh:config' work-dir "$fixture_root/work"
zstyle ':fsh:config' bracket-highlighting disabled

source "$plugin_root/F-Sy-H.plugin.zsh"

typeset -a reply expected_regions actual_regions

full_regions() {
  emulate -L zsh

  _fsh_highlight_init
  reply=()
  _fsh_highlight_process '' "$1" 0
  expected_regions=( "${reply[@]}" )
}

assert_regions() {
  emulate -L zsh

  local buffer=$1
  integer expected_incremental=$2 actual_incremental

  _fsh_highlight_buffer '' "$buffer"
  actual_incremental=$_fsh_incremental_last_used
  actual_regions=( "${reply[@]}" )
  full_regions "$buffer"

  [[ ${(F)actual_regions} == ${(F)expected_regions} ]] || {
    builtin print -u2 -r -- "f-sy-h: incremental region mismatch for ${(qqq)buffer}"
    builtin print -u2 -r -- "expected: ${(qqq)expected_regions}"
    builtin print -u2 -r -- "actual:   ${(qqq)actual_regions}"
    return 1
  }
  (( actual_incremental == expected_incremental )) || {
    builtin print -u2 -r -- \
      "f-sy-h: incremental=$actual_incremental, expected $expected_incremental for ${(qqq)buffer}"
    return 1
  }
}

prime_cache() {
  emulate -L zsh

  _fsh_incremental_reset
  _fsh_highlight_buffer '' "$1"
  (( ! _fsh_incremental_last_used ))
  (( _fsh_incremental_cache_valid ))
  (( $#_fsh_incremental_checkpoints ))
}

typeset old_buffer='echo a; echo b; echo c'
prime_cache "$old_buffer"
assert_regions 'echo a; echo b; echo cx' 1

prime_cache 'echo a; echo b; echo cxx'
assert_regions 'echo a; echo b; echo c' 1

prime_cache 'echo a; '
assert_regions 'echo a;' 1

prime_cache "$old_buffer"
assert_regions 'echo a; echo bx; echo c' 1

prime_cache $'echo a\necho b\necho c'
assert_regions $'echo a\necho b\necho cx' 1

prime_cache "$old_buffer"
assert_regions 'xecho a; echo b; echo c' 0

prime_cache "$old_buffer"
assert_regions 'echo a echo b; echo c' 0

prime_cache "$old_buffer"
assert_regions "echo a; echo b; echo 'c'" 0

prime_cache "$old_buffer"
assert_regions 'echo a; echo b; echo c >out' 0

prime_cache "$old_buffer"
assert_regions 'echo a; echo b; value=1' 0

prime_cache "$old_buffer"
assert_regions 'echo a; echo b; if true; then echo c; fi' 0

prime_cache "$old_buffer"
assert_regions 'echo a; echo b;; echo c' 0

prime_cache "$old_buffer"
assert_regions 'echo a; echo b; echo snowman-☃' 0

prime_cache "$old_buffer"
typeset original_command_style=${_fsh_styles[command]}
_fsh_styles[command]=fg=123
assert_regions 'echo a; echo b; echo cx' 0
_fsh_styles[command]=$original_command_style

prime_cache "$old_buffer"
alias -g b='global-value'
assert_regions 'echo a; echo b; echo cx' 0
unalias 'b'

prime_cache 'cachecmd a; echo c'
alias cachecmd=echo
assert_regions 'cachecmd a; echo cx' 0
unalias cachecmd

prime_cache "$old_buffer"
_fsh_highlight_buffer $'echo prior\n' 'echo c'
(( ! _fsh_incremental_last_used ))
(( ! _fsh_incremental_cache_valid ))

prime_cache "$old_buffer"
_fsh_incremental_reset
(( ! _fsh_incremental_cache_valid ))

prime_cache "$old_buffer"
typeset -g BUFFER=$old_buffer
typeset -gi CURSOR=1 REGION_ACTIVE=0
typeset -g _fsh_prior_buffer=$BUFFER _fsh_prior_region_active=$REGION_ACTIVE
typeset -gi _fsh_prior_cursor=0
! _fsh_buffer_modified
(( _fsh_incremental_cache_valid ))

typeset random_prefix='echo a; echo b; echo '
typeset random_tail=seed random_char left right
typeset random_buffer=$random_prefix$random_tail
typeset -a alphabet=( {a..z} )
integer action position run
RANDOM=9301
prime_cache "$random_buffer"
for run in {1..100}; do
  action=$(( RANDOM % 3 ))
  random_char=$alphabet[$(( RANDOM % $#alphabet + 1 ))]
  case $action in
    (0)
      position=$(( RANDOM % ($#random_tail + 1) ))
      if (( position == 0 )); then
        random_tail=$random_char$random_tail
      elif (( position == $#random_tail )); then
        random_tail+=$random_char
      else
        random_tail=${random_tail[1,position]}$random_char${random_tail[position + 1,-1]}
      fi
      ;;
    (1)
      if (( $#random_tail > 1 )); then
        position=$(( RANDOM % $#random_tail + 1 ))
        left=${random_tail[1,position - 1]}
        right=${random_tail[position + 1,-1]}
        random_tail=$left$right
      else
        random_tail+=$random_char
      fi
      ;;
    (2)
      position=$(( RANDOM % $#random_tail + 1 ))
      left=${random_tail[1,position - 1]}
      right=${random_tail[position + 1,-1]}
      random_tail=$left$random_char$right
      ;;
  esac
  random_buffer=$random_prefix$random_tail
  assert_regions "$random_buffer" 1
done

fsh_plugin_unload
