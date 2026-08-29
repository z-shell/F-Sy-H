#!/usr/bin/env zsh

builtin emulate -R zsh
builtin setopt pipe_fail

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
integer test_status=0

_fsh_test_fail() {
  builtin print -u2 -r -- "$1"
  test_status=1
}

typeset -gi _fsh_test_perl_invoked=0
typeset -gi _fsh_test_gawk_invoked=0 _fsh_test_ruby_invoked=0
perl() {
  _fsh_test_perl_invoked=1
  return 0
}
gawk() {
  _fsh_test_gawk_invoked=1
  return 0
}
ruby() {
  _fsh_test_ruby_invoked=1
  return 0
}

builtin source "$plugin_root/F-Sy-H.plugin.zsh" || {
  builtin print -u2 -r -- 'cannot load F-Sy-H for passive safety test'
  exit 1
}

typeset -g __arg_type=0 __arg=perl PREBUFFER=
integer in_redirection=0 this_word=0 next_word=0 _start_pos=0 _end_pos=4
typeset -ga reply=()

_fsh_chroma_perl 1 perl 0 4 >/dev/null 2>&1 || true
__arg_type=1
__arg=-e
_fsh_chroma_perl 0 "$__arg" 5 7 >/dev/null 2>&1 || true
__arg='BEGIN { print "must not run" }'
_fsh_chroma_perl 0 "$__arg" 8 $(( 8 + $#__arg )) >/dev/null 2>&1 || true

(( ! _fsh_test_perl_invoked )) ||
  _fsh_test_fail 'passive Perl highlighting invoked the Perl interpreter'

__arg_type=0 __arg=awk
_fsh_chroma_awk 1 awk 0 3 >/dev/null 2>&1 || true
__arg_type=1 __arg='BEGIN { system("must-not-run") }'
_fsh_chroma_awk 0 "$__arg" 4 $(( 4 + $#__arg )) >/dev/null 2>&1 || true

__arg_type=0 __arg=ruby
_fsh_chroma_ruby 1 ruby 0 4 >/dev/null 2>&1 || true
__arg_type=1 __arg=-e
_fsh_chroma_ruby 0 "$__arg" 5 7 >/dev/null 2>&1 || true
__arg='BEGIN { system("must-not-run") }'
_fsh_chroma_ruby 0 "$__arg" 8 $(( 8 + $#__arg )) >/dev/null 2>&1 || true

(( ! _fsh_test_gawk_invoked )) ||
  _fsh_test_fail 'passive AWK highlighting invoked the AWK interpreter'
(( ! _fsh_test_ruby_invoked )) ||
  _fsh_test_fail 'passive Ruby highlighting invoked the Ruby interpreter'

typeset source_text
[[ -r "$plugin_root/chroma/_fsh_chroma_main" ]] ||
  _fsh_test_fail 'main chroma source is not in the expected autoload directory'
source_text=$(<"$plugin_root/F-Sy-H.plugin.zsh")$'\n'$(<"$plugin_root/chroma/_fsh_chroma_main")
[[ $source_text != *'/tmp/reply'* && $source_text != *'/tmp/fsh-dbg'* ]] ||
  _fsh_test_fail 'production highlighting contains fixed temporary debug paths'
[[ $(<"$plugin_root/chroma/_fsh_chroma_main") != *' eval '* ]] ||
  _fsh_test_fail 'the chroma action dispatcher still evaluates action strings'
[[ $(<"$plugin_root/lib/highlight.zsh") != *'{ eval '* ]] ||
  _fsh_test_fail 'the main highlighter still evaluates derived user text'

exit "$test_status"
