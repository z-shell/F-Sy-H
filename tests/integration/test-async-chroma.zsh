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
typeset -gx FSH_ZLE_READY_MARKER=$fixture_root/zle-ready
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
# Test this checkout even when the caller exports another F-Sy-H in FPATH.
fpath=( "$plugin_root"/{functions,completions,chroma} \
  "${(@)fpath:#$plugin_root/(functions|completions|chroma)}" )

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

_fsh_state[chroma-timeout-fixture-pending]=1
_fsh_state[chroma-timeout-fixture-started-at]=$(( SECONDS - _fsh_chroma_timeout_seconds ))
_fsh_state[chroma-timeout-fixture-warned]=1
_fsh_async_command chroma-timeout-fixture command true
(( _fsh_state[chroma-timeout-fixture-disabled] ))
[[ ${_fsh_state[chroma-timeout-fixture-disabled-reason]} == \
  "timeout after ${_fsh_chroma_timeout_seconds}s" ]]

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
  zpty -w "$pty_name" "PS1='FSH_ASYNC> '; unsetopt prompt_cr prompt_sp; zstyle ':fsh:config' work-dir ${(q)fixture_root}/interactive-work; source ${(q)plugin_root}/F-Sy-H.plugin.zsh; autoload -Uz add-zle-hook-widget; _fsh_test_signal_zle_ready() { add-zle-hook-widget -d line-init _fsh_test_signal_zle_ready; : > ${(q)FSH_ZLE_READY_MARKER}; }; print -r -- FSH_ASYNC_LOADED"

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

  # Parser and buffer integration have their own profile. Bind the Git command
  # provider to a test widget so it starts inside active ZLE without depending
  # on prompt repaint timing.
  command rm -f -- "$FSH_ZLE_READY_MARKER"
  zpty -w "$pty_name" "_fsh_chroma_git; _fsh_test_prepare_git_commands() { local -a reply=(); _fsh_chroma_git_get_subcommands; }; zle -N _fsh_test_prepare_git_commands; bindkey '^X^G' _fsh_test_prepare_git_commands; add-zle-hook-widget line-init _fsh_test_signal_zle_ready; print -r -- FSH_GIT_COMMAND_WIDGET_READY"
  output=
  deadline=$(( SECONDS + 10 ))
  while (( SECONDS < deadline )); do
    if zpty -r -t "$pty_name" chunk; then
      output+=$chunk
      [[ -e $FSH_ZLE_READY_MARKER && $output == *FSH_GIT_COMMAND_WIDGET_READY*FSH_ASYNC\>* ]] && break
    else
      command sleep 0.02
    fi
  done
  [[ -e $FSH_ZLE_READY_MARKER ]]
  [[ $output == *FSH_GIT_COMMAND_WIDGET_READY*FSH_ASYNC\>* ]]

  zpty -w -n "$pty_name" $'\C-X\C-G'
  deadline=$(( SECONDS + 10 ))
  while [[ ! -e $FSH_GIT_COMMAND_MARKER ]] && (( SECONDS < deadline )); do
    command sleep 0.02
  done
  [[ -e $FSH_GIT_COMMAND_MARKER ]]
  command sleep 0.3

  # Install the dependent provider only after command discovery finishes, then
  # drive it through the same explicit ZLE widget boundary.
  zpty -w -n "$pty_name" $'\C-U'
  command rm -f -- "$FSH_ZLE_READY_MARKER"
  zpty -w "$pty_name" "_fsh_test_prepare_git_options() { _fsh_state[chroma-git-runtime-safe-subcommands]=commit; _fsh_chroma_git_prepare_runtime_options commit; }; zle -N _fsh_test_prepare_git_options; bindkey '^X^G' _fsh_test_prepare_git_options; add-zle-hook-widget line-init _fsh_test_signal_zle_ready; print -r -- FSH_GIT_OPTION_WIDGET_READY"
  output=
  deadline=$(( SECONDS + 10 ))
  while (( SECONDS < deadline )); do
    if zpty -r -t "$pty_name" chunk; then
      output+=$chunk
      [[ -e $FSH_ZLE_READY_MARKER && $output == *FSH_GIT_OPTION_WIDGET_READY*FSH_ASYNC\>* ]] && break
    else
      command sleep 0.02
    fi
  done
  [[ -e $FSH_ZLE_READY_MARKER ]]
  [[ $output == *FSH_GIT_OPTION_WIDGET_READY*FSH_ASYNC\>* ]]

  zpty -w -n "$pty_name" $'\C-X\C-G'
  deadline=$(( SECONDS + 10 ))
  while [[ ! -e $FSH_GIT_OPTION_MARKER ]] && (( SECONDS < deadline )); do
    command sleep 0.02
  done
  [[ -e $FSH_GIT_OPTION_MARKER ]]
  command sleep 0.3

  zpty -w -n "$pty_name" $'\C-U'
  zpty -w "$pty_name" \
    'print -r -- "FSH_GIT_READY:${_fsh_state[chroma-git-subcommands-cache-ready]}:${_fsh_state[chroma-git-options-commit-cache-ready]}"'

  output=
  deadline=$(( SECONDS + 10 ))
  while (( SECONDS < deadline )); do
    if zpty -r -t "$pty_name" chunk; then
      output+=$chunk
      [[ $output == *FSH_GIT_READY:1:1* ]] && break
    else
      command sleep 0.02
    fi
  done
  [[ $output == *FSH_GIT_READY:1:1* ]]

  # Exercise cache outcomes and partial output through the real widget callback.
  command cat > "$fixture_root/query-worker" <<'SH'
#!/bin/sh
case "$1" in
  valid) printf '%s\n' last-valid ;;
  empty) exit 0 ;;
  failure) printf '%s\n' partial-error; exit 7 ;;
  help) printf '%s\n' help-output >&2; exit 129 ;;
  streaming)
    printf '%s\n' first
    while [ ! -e "$2/stream-release" ]; do sleep 0.02; done
    printf '%s\n' last ;;
  slow) printf '%s\n' "$$" > "$2/slow-pid"; exec sleep 20 ;;
esac
SH
  command chmod 755 "$fixture_root/query-worker"
  command cat > "$fixture_root/query-setup.zsh" <<'ZSH'
typeset -g _fsh_test_query_dir=$1 _fsh_test_query_key _fsh_test_query_mode
builtin autoload +X _fsh_async_command_callback
functions[_fsh_test_real_callback]=$functions[_fsh_async_command_callback]
_fsh_async_command_callback() {
  builtin emulate -L zsh
  local key=${_fsh_state[_fsh-async-fd-$1-key]-}
  _fsh_test_real_callback "$@"
  if [[ -n $key && ${_fsh_state[$key-pending]:-0} == 0 ]]; then
    print -r -- "$key:${_fsh_state[$key-cache-ready]:-0}:${_fsh_state[$key-last-status]:-unset}:${_fsh_state[$key-cache]-}" >| "$_fsh_test_query_dir/completed"
  fi
}
_fsh_test_query_widget() {
  _fsh_async_command --capture-stderr "$_fsh_test_query_key" "$_fsh_test_query_dir/query-worker" "$_fsh_test_query_mode" "$_fsh_test_query_dir"
  print -r -- "${_fsh_state[$_fsh_test_query_key-cache]-}" >| "$_fsh_test_query_dir/returned"
}
zle -N _fsh_test_query_widget
bindkey '^X^G' _fsh_test_query_widget
ZSH

  _fsh_test_query_command() {
    local chunk output=
    command rm -f -- "$FSH_ZLE_READY_MARKER"
    zpty -w -n "$pty_name" $'\C-U'
    zpty -w "$pty_name" "$1; add-zle-hook-widget line-init _fsh_test_signal_zle_ready"
    local deadline=$(( SECONDS + 10 ))
    while [[ ! -e $FSH_ZLE_READY_MARKER ]] && (( SECONDS < deadline )); do
      if zpty -r -t "$pty_name" chunk; then
        output+=$chunk
      else
        command sleep 0.02
      fi
    done
    [[ -e $FSH_ZLE_READY_MARKER ]] || {
      print -u2 -r -- "f-sy-h: query command did not return: $1: ${(V)output[-1000,-1]}"
      return 1
    }
  }
  _fsh_test_query_start() {
    _fsh_test_query_command "_fsh_test_query_key=$1; _fsh_test_query_mode=$2; unset '_fsh_state[$1-checked-at]'; _fsh_state[$1-cache-born-at]=-10000"
    command rm -f -- "$fixture_root/returned" "$fixture_root/completed" "$fixture_root/slow-pid"
    zpty -w -n "$pty_name" $'\C-X\C-G'
    local deadline=$(( SECONDS + 10 ))
    while [[ ! -e $fixture_root/returned ]] && (( SECONDS < deadline )); do
      command sleep 0.02
    done
    [[ -e $fixture_root/returned ]]
  }
  _fsh_test_query_complete() {
    local deadline=$(( SECONDS + 10 ))
    while [[ ! -e $fixture_root/completed ]] && (( SECONDS < deadline )); do
      command sleep 0.02
    done
    [[ -e $fixture_root/completed && $(<"$fixture_root/completed") == "$1" ]]
  }

  _fsh_test_query_command "source ${(q)fixture_root}/query-setup.zsh ${(q)fixture_root}"
  _fsh_test_query_start fixture-valid valid
  _fsh_test_query_complete 'fixture-valid:1:0:last-valid'
  _fsh_test_query_start fixture-valid failure
  [[ $(<"$fixture_root/returned") == last-valid ]]
  _fsh_test_query_complete 'fixture-valid:1:7:last-valid'
  _fsh_test_query_start fixture-failure failure
  _fsh_test_query_complete 'fixture-failure:0:7:'
  _fsh_test_query_start fixture-valid empty
  _fsh_test_query_complete 'fixture-valid:1:0:'
  _fsh_test_query_command "_fsh_state[fixture-help-success-statuses]='0 129'"
  _fsh_test_query_start fixture-help help
  _fsh_test_query_complete 'fixture-help:1:129:help-output'
  _fsh_test_query_start fixture-stream streaming
  # The first chunk must not block the callback until the producer finishes.
  _fsh_test_query_command "print -r -- responsive > ${(q)fixture_root}/responsive"
  [[ ! -e $fixture_root/completed ]]
  print -r -- release > "$fixture_root/stream-release"
  _fsh_test_query_complete $'fixture-stream:1:0:first\nlast'
  _fsh_test_query_start fixture-timeout slow
  deadline=$(( SECONDS + 10 ))
  while [[ ! -e $fixture_root/slow-pid ]] && (( SECONDS < deadline )); do
    command sleep 0.02
  done
  [[ -e $fixture_root/slow-pid ]]
  integer slow_pid=$(<"$fixture_root/slow-pid")
  _fsh_test_query_command "_fsh_state[fixture-timeout-started-at]=-10000; _fsh_state[fixture-timeout-warned]=1"
  zpty -w -n "$pty_name" $'\C-X\C-G'
  _fsh_test_query_command "print -r -- \"\${_fsh_state[fixture-timeout-disabled]}:\${_fsh_state[fixture-timeout-pending]}\" > ${(q)fixture_root}/timeout"
  [[ $(<"$fixture_root/timeout") == 1:0 ]]
  deadline=$(( SECONDS + 10 ))
  while builtin kill -0 "$slow_pid" 2>/dev/null && (( SECONDS < deadline )); do
    command sleep 0.02
  done
  ! builtin kill -0 "$slow_pid" 2>/dev/null
  _fsh_test_query_start fixture-unload slow
  deadline=$(( SECONDS + 10 ))
  while [[ ! -e $fixture_root/slow-pid ]] && (( SECONDS < deadline )); do
    command sleep 0.02
  done
  [[ -e $fixture_root/slow-pid ]]
  slow_pid=$(<"$fixture_root/slow-pid")
  zpty -w -n "$pty_name" $'\C-U'
  zpty -w "$pty_name" "fsh_plugin_unload; zle -F > ${(q)fixture_root}/handlers"
  deadline=$(( SECONDS + 10 ))
  while [[ ! -e $fixture_root/handlers ]] && (( SECONDS < deadline )); do
    zpty -r -t "$pty_name" chunk || command sleep 0.02
  done
  [[ -e $fixture_root/handlers ]]
  [[ ! -s $fixture_root/handlers ]]
  while builtin kill -0 "$slow_pid" 2>/dev/null && (( SECONDS < deadline )); do
    command sleep 0.02
  done
  ! builtin kill -0 "$slow_pid" 2>/dev/null
} always {
  zpty -d "$pty_name" 2>/dev/null || true
}
