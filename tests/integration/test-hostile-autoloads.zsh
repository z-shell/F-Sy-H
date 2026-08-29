#!/usr/bin/env zsh

builtin emulate -R zsh
builtin setopt pipe_fail

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset fixture_root
fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-autoload.XXXXXXXX") || exit 1
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

builtin print -r -- $'[section]\nkey=value' >| "$fixture_root/theme.ini"
builtin source "$plugin_root/F-Sy-H.plugin.zsh" || exit 1

typeset -A parsed=()
_fsh_test_ini_parsed() {
  builtin emulate -L zsh
  (( $#parsed == 1 )) && [[ ${(j:,:)${(v)parsed}} == value ]]
}

_fsh_read_ini "$fixture_root/theme.ini" parsed || exit 1
_fsh_test_ini_parsed || {
  builtin print -u2 -r -- 'autoload function failed under default caller options'
  exit 1
}

parsed=()
builtin setopt ksh_arrays sh_word_split glob_subst
_fsh_read_ini "$fixture_root/theme.ini" parsed || exit 1
_fsh_test_ini_parsed || {
  builtin print -u2 -r -- 'autoload function depended on hostile caller options'
  exit 1
}

[[ -o ksharrays && -o shwordsplit && -o globsubst ]] || {
  builtin print -u2 -r -- 'autoload function changed caller options'
  exit 1
}
