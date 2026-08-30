#!/usr/bin/env zsh

builtin emulate -R zsh
builtin setopt pipe_fail

typeset -r plugin_path=${1:-${${(%):-%N}:a:h:h:h}/F-Sy-H.plugin.zsh}
[[ -r $plugin_path ]] || {
  builtin print -u2 -r -- "plugin is not readable: $plugin_path"
  exit 1
}

typeset test_dir
test_dir=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-completion.XXXXXX") || exit 1

typeset -r pty_name=fsyh-completion
typeset load_output completion_output REPLY
integer test_status=0

_fsh_test_fail() {
  builtin print -u2 -r -- "$1"
  test_status=1
}

_fsh_test_read_until() {
  builtin emulate -L zsh

  local pattern=$1 chunk
  integer read_deadline=$(( SECONDS + 30 ))
  REPLY=

  while (( SECONDS < read_deadline )); do
    if zpty -r -t "$pty_name" chunk; then
      REPLY+=$chunk
      [[ $REPLY == ${~pattern} ]] && return 0
    else
      command sleep 0.02
    fi
  done

  return 1
}

{
  : >| "$test_dir/secondary_theme.zsh" || _fsh_test_fail 'cannot prepare isolated theme cache'
  command mkdir -p -- "$test_dir/home" "$test_dir/zdotdir" || \
    _fsh_test_fail 'cannot prepare isolated shell directories'
  zmodload zsh/zpty || _fsh_test_fail 'zsh/zpty is unavailable'

  if (( test_status == 0 )); then
    zpty -b "$pty_name" \
      "HOME=${(q)test_dir}/home ZDOTDIR=${(q)test_dir}/zdotdir zsh -f" || \
      _fsh_test_fail 'cannot start isolated interactive Zsh'
  fi

  if (( test_status == 0 )); then
    zpty -w "$pty_name" "PS1=''; unsetopt prompt_cr prompt_sp; print -r -- FSH_\${:-READY}_DONE"
    _fsh_test_read_until '*FSH_READY_DONE*' || _fsh_test_fail 'interactive Zsh did not become ready'
  fi

  if (( test_status == 0 )); then
    zpty -w "$pty_name" "zstyle ':fsh:config' work-dir ${(q)test_dir}; source ${(q)plugin_path}; autoload -Uz compinit; compinit -D -i; PS1='FSH_INTERRUPT_READY> '; print -r -- FSH_\${:-LOAD}_NEW:\${+functions[_fsh_highlight_process]}:OLD:\${+functions[-fast-highlight-process]}:CHROMA:\${_comps[fsh_chroma]-}"
    _fsh_test_read_until '*FSH_LOAD_NEW:[01]:OLD:[01]:CHROMA:_fsh_chroma*FSH_INTERRUPT_READY*' || \
      _fsh_test_fail "F-Sy-H did not load in the interactive Zsh: ${(V)REPLY[1,1000]}"
    load_output=$REPLY
  fi

  if (( test_status == 0 )); then
    zpty -w -n "$pty_name" $'time -\t'
    command sleep 0.1
    zpty -w -n "$pty_name" $'\C-C'
    _fsh_test_read_until '*FSH_INTERRUPT_READY*' || \
      _fsh_test_fail "completion probe did not return to the prompt: ${(V)REPLY[1,1000]}"
    completion_output=$REPLY
  fi

  [[ $load_output == *FSH_LOAD_NEW:1:OLD:0* ]] || \
    _fsh_test_fail 'plugin did not expose only the private _fsh helper namespace'
  [[ $load_output == *CHROMA:_fsh_chroma* ]] || \
    _fsh_test_fail 'compinit did not register the fsh_chroma completion'
  [[ $completion_output != *-fast-highlight* && $completion_output != *-fsh_sy_h* ]] || \
    _fsh_test_fail 'dash-prefixed F-Sy-H functions leaked into time completion'
} always {
  (( ${+builtins[zpty]} )) && zpty -d "$pty_name" 2>/dev/null
  command rm -rf -- "$test_dir"
}

exit "$test_status"
