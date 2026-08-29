#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

# Bare conditions under err_exit abort with no diagnostic, which reduces a CI
# failure to an exit status. Report the failing line so platform-specific
# failures are actionable from the log alone. Only failures raised directly by
# this file are reported; handled non-zero statuses inside the plugin are not
# test failures and must not reach standard error.
typeset -g _fsh_test_file=${${(%):-%N}:A}
TRAPZERR() {
  [[ ${${funcfiletrace[1]%:*}:A} == $_fsh_test_file ]] || return 0
  builtin print -u2 -r -- \
    "f-sy-h: async chroma check failed at line ${funcfiletrace[1]##*:}"
}

zmodload zsh/datetime

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-async.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
typeset -gx FSH_DOCKER_MARKER=$fixture_root/docker-ran
typeset -gx FSH_GIT_COMMAND_MARKER=$fixture_root/git-command-ran
typeset -gx FSH_GIT_OPTION_MARKER=$fixture_root/git-option-ran
typeset -gx PATH=$fixture_root/bin:$PATH
command mkdir -p -- "$ZDOTDIR" "$fixture_root/bin"
{
  builtin print -r -- '#!/bin/sh'
  builtin print -r -- ': > "$FSH_DOCKER_MARKER"'
  builtin print -r -- 'sleep 3'
  builtin print -r -- 'printf "%s\n" deadbeef'
} >| "$fixture_root/bin/docker"
command chmod 755 "$fixture_root/bin/docker"
{
  builtin print -r -- '#!/bin/sh'
  builtin print -r -- 'case "$1 $2" in'
  builtin print -r -- "'help -a')"
  builtin print -r -- '  : > "$FSH_GIT_COMMAND_MARKER"'
  builtin print -r -- '  sleep 0.1'
  builtin print -r -- "  printf '%s\\n' 'Main Porcelain Commands' '   commit                  Record changes' '   nebula                  Travel through repositories'"
  builtin print -r -- '  ;;'
  builtin print -r -- "'config --get-regexp') exit 1 ;;"
  builtin print -r -- "'commit -h')"
  builtin print -r -- '  : > "$FSH_GIT_OPTION_MARKER"'
  builtin print -r -- '  sleep 0.1'
  builtin print -r -- "  printf '%s\\n' 'usage: git commit [options]' '    --future-mode       use the future mode' >&2"
  builtin print -r -- '  ;;'
  builtin print -r -- 'esac'
} >| "$fixture_root/bin/git"
command chmod 755 "$fixture_root/bin/git"
zstyle ':fsh:config' work-dir "$fixture_root/work"

source "$plugin_root/F-Sy-H.plugin.zsh"

typeset docker_source=$(<"$plugin_root/chroma/_fsh_chroma_docker")
[[ $docker_source == *'_fsh_async_command chroma-docker-list docker images -q'* ]]
[[ $docker_source != *'_fsh_run_command'* ]]

typeset BUFFER='docker image rm deadbeef' PREBUFFER=
typeset -a reply=()
float started=$EPOCHREALTIME elapsed
started=$EPOCHREALTIME
_fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
elapsed=$(( EPOCHREALTIME - started ))

(( elapsed < 0.250 ))
[[ ! -e $FSH_DOCKER_MARKER ]]
(( ! ${_fsh_state[chroma-docker-list-pending]:-0} ))

fsh_plugin_unload

# Exercise the actual zle -F callback in an isolated interactive shell.
{
  builtin print -r -- '#!/bin/sh'
  builtin print -r -- ': > "$FSH_DOCKER_MARKER"'
  builtin print -r -- 'sleep 0.1'
  builtin print -r -- 'printf "%s\n" deadbeef'
} >| "$fixture_root/bin/docker"
command rm -f -- "$FSH_DOCKER_MARKER"
command mkdir -p -- "$fixture_root/interactive-zdotdir"

zmodload zsh/zpty
typeset -r pty_name=fsyh-async
typeset chunk output=
integer deadline

zpty -b "$pty_name" \
  "ZDOTDIR=${(q)fixture_root}/interactive-zdotdir FSH_DOCKER_MARKER=${(q)FSH_DOCKER_MARKER} PATH=${(q)fixture_root}/bin:\$PATH zsh -f -i"
{
  zpty -w "$pty_name" "PS1='FSH_ASYNC> '; unsetopt prompt_cr prompt_sp; zstyle ':fsh:config' work-dir ${(q)fixture_root}/interactive-work; source ${(q)plugin_root}/F-Sy-H.plugin.zsh; _fsh_test_prepare_git_options() { _fsh_state[chroma-git-runtime-safe-subcommands]=commit; _fsh_chroma_git_prepare_runtime_options commit; }; zle -N _fsh_test_prepare_git_options; bindkey '^X^G' _fsh_test_prepare_git_options; print -r -- FSH_ASYNC_LOADED"

  deadline=$(( SECONDS + 10 ))
  while (( SECONDS < deadline )); do
    if zpty -r -t "$pty_name" chunk; then
      output+=$chunk
      [[ $output == *FSH_ASYNC_LOADED*FSH_ASYNC\>* ]] && break
    else
      command sleep 0.02
    fi
  done
  [[ $output == *FSH_ASYNC_LOADED*FSH_ASYNC\>* ]]

  zpty -w -n "$pty_name" 'docker image rm deadbeef'
  deadline=$(( SECONDS + 10 ))
  while [[ ! -e $FSH_DOCKER_MARKER ]] && (( SECONDS < deadline )); do
    command sleep 0.02
  done
  [[ -e $FSH_DOCKER_MARKER ]]
  command sleep 0.3

  zpty -w -n "$pty_name" $'\C-U'
  zpty -w "$pty_name" \
    'print -r -- "FSH_ASYNC_READY:${_fsh_state[chroma-docker-list-cache-ready]}:${_fsh_state[chroma-docker-list-pending]}:${_fsh_state[chroma-docker-list-cache]}"'

  output=
  deadline=$(( SECONDS + 10 ))
  while (( SECONDS < deadline )); do
    if zpty -r -t "$pty_name" chunk; then
      output+=$chunk
      [[ $output == *FSH_ASYNC_READY:1:0:deadbeef* ]] && break
    else
      command sleep 0.02
    fi
  done
  [[ $output == *FSH_ASYNC_READY:1:0:deadbeef* ]]

  zpty -w -n "$pty_name" 'git commit --future-mode'
  deadline=$(( SECONDS + 10 ))
  while [[ ! -e $FSH_GIT_COMMAND_MARKER ]] && (( SECONDS < deadline )); do
    command sleep 0.02
  done
  [[ -e $FSH_GIT_COMMAND_MARKER ]]
  command sleep 0.3

  # Drive the dependent option provider through a test-only ZLE widget. Parser
  # integration is covered separately; this profile owns the asynchronous
  # worker and callback boundary and must not depend on repaint scheduling.
  zpty -w -n "$pty_name" $'\C-X\C-G'
  deadline=$(( SECONDS + 10 ))
  while [[ ! -e $FSH_GIT_OPTION_MARKER ]] && (( SECONDS < deadline )); do
    command sleep 0.02
  done
  [[ -e $FSH_GIT_OPTION_MARKER ]]
  command sleep 0.3

  zpty -w -n "$pty_name" $'\C-U'
  zpty -w "$pty_name" \
    'print -r -- "FSH_GIT_READY:${_fsh_state[chroma-git-subcommands-cache-ready]}:${_fsh_state[chroma-git-options-commit-cache-ready]}:${_fsh_chroma_main_git[subcmd:commit]}"'

  output=
  deadline=$(( SECONDS + 10 ))
  while (( SECONDS < deadline )); do
    if zpty -r -t "$pty_name" chunk; then
      output+=$chunk
      [[ $output == *FSH_GIT_READY:1:1:*GIT_RUNTIME_commit_R_\#_opt* ]] && break
    else
      command sleep 0.02
    fi
  done
  [[ $output == *FSH_GIT_READY:1:1:*GIT_RUNTIME_commit_R_\#_opt* ]]
} always {
  zpty -d "$pty_name" 2>/dev/null || true
}
