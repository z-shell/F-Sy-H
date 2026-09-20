#!/usr/bin/env zsh

builtin emulate -R zsh
builtin setopt pipe_fail

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r plugin_path=$plugin_root/F-Sy-H.plugin.zsh
typeset -r test_case=${1:-noninteractive}
integer test_status=0

_fsh_test_fail() {
  builtin print -u2 -r -- "$1"
  test_status=1
}

_fsh_test_arrays_equal() {
  builtin emulate -L zsh

  local left_name=$1 right_name=$2
  local -a left=( "${(@P)left_name}" ) right=( "${(@P)right_name}" )
  integer index

  (( $#left == $#right )) || return 1
  for (( index = 1; index <= $#left; ++index )); do
    [[ ${left[index]} == "${right[index]}" ]] || return 1
  done
}

_fsh_test_count_value() {
  builtin emulate -L zsh

  local array_name=$1 expected=$2 value
  local -a values=( "${(@P)array_name}" )
  integer count=0

  for value in "${values[@]}"; do
    [[ $value == "$expected" ]] && (( ++count ))
  done
  REPLY=$count
}

_fsh_test_widget_option_boundary() {
  builtin emulate -L zsh

  local fixture_root pty_name=fsyh-widget-options chunk output=
  integer deadline

  fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-widget-options.XXXXXXXX") || return 1
  {
    command mkdir -p -- "$fixture_root/home" "$fixture_root/zdotdir" || return 1
    zmodload zsh/zpty || {
      _fsh_test_fail 'zsh/zpty is unavailable'
      return
    }
    zpty -b "$pty_name" \
      "HOME=${(q)fixture_root}/home ZDOTDIR=${(q)fixture_root}/zdotdir zsh -f -i" || {
        _fsh_test_fail 'cannot start isolated interactive Zsh'
        return
      }

    zpty -w "$pty_name" \
      "PS1='FSH_WIDGET> '; unsetopt prompt_cr prompt_sp warn_create_global; setopt auto_pushd; third_party_widget() { THIRD_PARTY_GLOBAL=1; builtin print -r -- FSH_WIDGET_OPTIONS:\${options[autopushd]}:\${options[warncreateglobal]}; zle .accept-line; }; zle -N third-party-widget third_party_widget; bindkey '^X^O' third-party-widget; source ${(q)plugin_path}; print -r -- FSH_WIDGET_READY"
    deadline=$(( SECONDS + 10 ))
    while (( SECONDS < deadline )); do
      if zpty -r -t "$pty_name" chunk; then
        output+=$chunk
        [[ $output == *FSH_WIDGET_READY*FSH_WIDGET\>* ]] && break
      else
        command sleep 0.02
      fi
    done
    [[ $output == *FSH_WIDGET_READY*FSH_WIDGET\>* ]] || {
      _fsh_test_fail 'interactive widget probe did not become ready'
      return
    }

    output=
    zpty -w -n "$pty_name" $'\C-X\C-O'
    deadline=$(( SECONDS + 10 ))
    while (( SECONDS < deadline )); do
      if zpty -r -t "$pty_name" chunk; then
        output+=$chunk
        [[ $output == *FSH_WIDGET_OPTIONS:*FSH_WIDGET\>* ]] && break
      else
        command sleep 0.02
      fi
    done

    [[ $output == *FSH_WIDGET_OPTIONS:on:off* ]] ||
      _fsh_test_fail "wrapped widget changed caller options: ${(V)output[1,1000]}"
    [[ $output != *'created globally in function third_party_widget'* ]] ||
      _fsh_test_fail 'wrapped widget enabled warn_create_global in third-party code'
  } always {
    (( ${+builtins[zpty]} )) && zpty -d "$pty_name" 2>/dev/null
    command rm -rf -- "$fixture_root"
  }
}

_fsh_test_history_boundary() {
  builtin emulate -L zsh

  local fixture_root pty_name=fsyh-history chunk expected output=
  integer deadline step=0 wrapped

  fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-history.XXXXXXXX") || return 1
  {
    command mkdir -p -- "$fixture_root/home" || return 1
    command cat > "$fixture_root/setup.zsh" <<'ZSH'
builtin emulate -L zsh
PS1='FSH_HISTORY> '
unsetopt prompt_cr prompt_sp
HISTSIZE=100
bindkey -e
autoload -Uz up-line-or-beginning-search
zle -N up-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
source -- "$1" || return
typeset -g _fsh_test_dir=$2
typeset -gi _fsh_test_replies=0

# Model the relevant autosuggestions v0.7.1 binding and async callback contract.
# Upstream: 85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5, src/{bind,config,async}.zsh.
# Private names and orig-* are ignored; an unrecognized saved history widget
# gets a modifying wrapper whose async suggestion interrupts LASTWIDGET (#142).
_fsh_test_suggest() { :; }
zle -N _fsh_test_suggest
_fsh_test_response() {
  builtin emulate -L zsh
  local line
  read -r -u "$1" line
  zle _fsh_test_suggest
  zle -F "$1"
  exec {1}<&-
  (( ++_fsh_test_replies ))
  print -r -- "$_fsh_test_replies" >| "$_fsh_test_dir/replies"
}
_fsh_test_external_widget() {
  builtin emulate -L zsh
  zle _fsh_test_original_search
  local fd
  exec {fd}< <(print -r -- ready)
  zle -F "$fd" _fsh_test_response
}
integer wrapped=0
local name
for name in ${(k)widgets}; do
  [[ $name == (.*|_*|orig-*|autosuggest-*|zle-*|up-line-or-beginning-search) ]] && continue
  [[ ${widgets[$name]} == user:up-line-or-beginning-search ]] || continue
  zle -A "$name" _fsh_test_original_search
  zle -N "$name" _fsh_test_external_widget
  wrapped=1
done
print -r -- "$wrapped" >| "$_fsh_test_dir/wrapped"
_fsh_test_capture() {
  print -r -- "$BUFFER" >| "$_fsh_test_dir/buffer"
}
zle -N zle-line-pre-redraw _fsh_test_capture
zle -N zle-line-init _fsh_test_capture
print -s 'echo FIRST'
print -s 'print SECOND'
print -s 'pwd'
ZSH
    zmodload zsh/zpty || return 1
    zpty -b "$pty_name" \
      "HOME=${(q)fixture_root}/home ZDOTDIR=${(q)fixture_root}/home zsh -f -i" || return 1
    zpty -w "$pty_name" \
      "source ${(q)fixture_root}/setup.zsh ${(q)plugin_path} ${(q)fixture_root}"
    deadline=$(( SECONDS + 10 ))
    while [[ ! -f $fixture_root/buffer ]] && (( SECONDS < deadline )); do
      if zpty -r -t "$pty_name" chunk; then
        output+=$chunk
      else
        command sleep 0.02
      fi
    done
    [[ -f $fixture_root/buffer && -f $fixture_root/wrapped ]] || {
      _fsh_test_fail "history probe did not become ready: ${(V)output[-1000,-1]}"
      return
    }
    wrapped=$(<"$fixture_root/wrapped")

    for expected in pwd 'print SECOND' 'echo FIRST'; do
      (( ++step ))
      zpty -w -n "$pty_name" $'\e[A'
      deadline=$(( SECONDS + 10 ))
      while (( SECONDS < deadline )); do
        if [[ $(<"$fixture_root/buffer") == "$expected" ]]; then
          (( ! wrapped )) && break
          [[ -f $fixture_root/replies && $(<"$fixture_root/replies") == $step ]] && break
        fi
        zpty -r -t "$pty_name" chunk || command sleep 0.02
      done
      [[ $(<"$fixture_root/buffer") == "$expected" ]] || {
        _fsh_test_fail "history navigation stopped at step $step; expected: $expected"
        return
      }
      (( ! wrapped )) || [[ -f $fixture_root/replies && $(<"$fixture_root/replies") == $step ]] || {
        _fsh_test_fail 'history probe did not receive the asynchronous suggestion'
        return
      }
    done
  } always {
    (( ${+builtins[zpty]} )) && zpty -d "$pty_name" 2>/dev/null
    command rm -rf -- "$fixture_root"
  }
}

# Builtin kill and yank widgets must keep the ZLE flags the next
# command reads: consecutive kills join and yank-pop cycles the kill ring in
# both yank directions (#150). Each step is one key sequence and the buffer
# expected after it, read after the plugin's zle-line-pre-redraw widget runs.
_fsh_test_kill_ring_boundary() {
  builtin emulate -L zsh

  local fixture_root pty_name=fsyh-killring chunk expected keymap keys key output=
  integer deadline

  fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-killring.XXXXXXXX") || return 1
  {
    command mkdir -p -- "$fixture_root/home" || return 1
    command cat > "$fixture_root/setup.zsh" <<'ZSH'
builtin emulate -L zsh
PS1='FSH_KILLRING> '
unsetopt prompt_cr prompt_sp
KEYTIMEOUT=1
bindkey -$3
bindkey -M vicmd 'Y' yank-pop
zle -A .backward-kill-word fsh-test-alias-kill
zle -A .yank fsh-test-alias-yank
zle -A .yank-pop fsh-test-alias-yank-pop
# Replacing an existing builtin name is indistinguishable through $widgets
# from its protected canonical builtin. The alias target must still win.
zle -A .forward-char kill-line
bindkey '^Xk' fsh-test-alias-kill
bindkey '^Xy' fsh-test-alias-yank
bindkey '^Xp' fsh-test-alias-yank-pop
bindkey '^Xf' kill-line
source -- "$1" || return
typeset -g _fsh_test_dir=$2
typeset -gi _fsh_test_skip_plugin_redraw=0
zle -A zle-line-pre-redraw fsh-test-plugin-redraw
_fsh_test_capture() {
  if (( ! _fsh_test_skip_plugin_redraw )); then
    zle fsh-test-plugin-redraw || return
    [[ $_fsh_prior_buffer == "$BUFFER" ]] || {
      print -r -- 'stale plugin highlight' >| "$_fsh_test_dir/buffer"
      return
    }
  fi
  print -r -- "$BUFFER" >| "$_fsh_test_dir/buffer"
}
zle -N zle-line-pre-redraw _fsh_test_capture
zle -N zle-line-init _fsh_test_capture
# Native builtin widgets keep their return status; the empty kill ring makes
# yank and yank-pop fail while kill-word succeeds. Report through the buffer.
_fsh_test_status() {
  local -a results
  zle yank; results+=(yank=$?)
  zle yank-pop; results+=(yank-pop=$?)
  zle kill-word; results+=(kill-word=$?)
  zle fsh-test-alias-yank; results+=(alias-yank=$?)
  zle fsh-test-alias-yank-pop; results+=(alias-yank-pop=$?)
  zle fsh-test-alias-kill; results+=(alias-kill=$?)
  results+=(alias-type=${widgets[fsh-test-alias-kill]})
  results+=(shadow-type=${widgets[kill-line]})
  BUFFER=$results
}
zle -N _fsh_test_status
bindkey '^Xs' _fsh_test_status
_fsh_test_unload_alias() {
  local shadow
  _fsh_test_skip_plugin_redraw=1
  zle -D fsh-test-plugin-redraw
  fsh_plugin_unload || return
  BUFFER=abc
  CURSOR=0
  zle kill-line
  LBUFFER+=X
  shadow=$BUFFER
  BUFFER='echo alpha beta'
  CURSOR=$#BUFFER
  zle fsh-test-alias-kill
  BUFFER+="|type=${widgets[fsh-test-alias-kill]}|status=$?|shadow=$shadow"
}
zle -N _fsh_test_unload_alias
bindkey '^Xu' _fsh_test_unload_alias
ZSH
    zmodload zsh/zpty || return 1
    # keymap, key sequence, expected buffer. Every entry in the sequence is one
    # zpty write; pauses keep ESC from joining the following key in vi mode.
    for keymap keys expected in \
        e '^Xs' 'yank=1 yank-pop=1 kill-word=0 alias-yank=1 alias-yank-pop=1 alias-kill=0 alias-type=builtin shadow-type=builtin' \
        e 'echo alpha beta gamma|^W|^W|^W|^Y' 'echo alpha beta gamma' \
        e 'echo alpha beta gamma|^W|^E|^W|^E|^W|^Y|\ey|\ey' 'echo gamma' \
        e 'alpha beta gamma|^A|\ed|^E|^A|\ed|^E|^A|\ed|xy|^B|^Y|\ey|\ey' 'xalphay' \
        e 'echo alpha beta gamma|^Xk|^Xk|^Xk|^Xy' 'echo alpha beta gamma' \
        e 'echo alpha beta gamma|^Xk|^E|^Xk|^E|^Xk|^Xy|^Xp|^Xp' 'echo gamma' \
        e 'alpha beta gamma|^A|\ed|^E|^A|\ed|^E|^A|\ed|xy|^B|^Xy|^Xp|^Xp' 'xalphay' \
        e 'abc|^A|^Xf|X' 'aXbc' \
        e '^Xu' 'echo alpha |type=builtin|status=0|shadow=aXbc' \
        v 'alpha beta gamma|\e|0|dw|dw|dw|i|xy|\e|h|p|Y|Y' 'xalpha y'; do
      command rm -f -- "$fixture_root/buffer"
      zpty -b "$pty_name" \
        "HOME=${(q)fixture_root}/home ZDOTDIR=${(q)fixture_root}/home zsh -f -i" || return 1
      zpty -w "$pty_name" \
        "source ${(q)fixture_root}/setup.zsh ${(q)plugin_path} ${(q)fixture_root} $keymap"
      deadline=$(( SECONDS + 10 ))
      while [[ ! -f $fixture_root/buffer ]] && (( SECONDS < deadline )); do
        if zpty -r -t "$pty_name" chunk; then
          output+=$chunk
        else
          command sleep 0.02
        fi
      done
      [[ -f $fixture_root/buffer ]] || {
        _fsh_test_fail "kill ring probe did not become ready: ${(V)output[-1000,-1]}"
        zpty -d "$pty_name" 2>/dev/null
        return
      }
      for key in "${(@s:|:)keys}"; do
        zpty -w -n "$pty_name" "${(g:c:)key}"
        command sleep 0.05
      done
      deadline=$(( SECONDS + 10 ))
      while [[ $(<"$fixture_root/buffer") != "$expected" ]] && (( SECONDS < deadline )); do
        zpty -r -t "$pty_name" chunk || command sleep 0.02
      done
      zpty -d "$pty_name" 2>/dev/null
      [[ $(<"$fixture_root/buffer") == "$expected" ]] || {
        _fsh_test_fail "kill ring sequence ${(q)keys} left ${(q)$(<"$fixture_root/buffer")}; expected ${(q)expected}"
        return
      }
    done
  } always {
    (( ${+builtins[zpty]} )) && zpty -d "$pty_name" 2>/dev/null
    command rm -rf -- "$fixture_root"
  }
}

_fsh_test_noninteractive() {
  builtin emulate -L zsh

  local fixture_root name value color_name declaration
  local -a before_fpath before_modules expected_fpath manager_fpath
  local -A before_widgets before_owned_functions before_owned_parameters
  local -A before_color_parameter_set before_color_parameters

  fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-lifecycle.XXXXXXXX") || return 1
  {
    zstyle ':fsh:config' work-dir "$fixture_root/work"
    zmodload zsh/parameter zsh/zleparameter ||
      _fsh_test_fail 'required observer modules are unavailable'
    before_widgets=( "${(@kv)widgets}" )
    before_modules=( ${(f)"$(zmodload)"} )
    typeset -gA fg=( sentinel before )
    typeset -g reset_color=before
    for color_name in color colour fg fg_bold fg_no_bold bg bg_bold bg_no_bold reset_color bold_color; do
      declaration=$(builtin typeset -p "$color_name" 2>/dev/null) || continue
      before_color_parameter_set[$color_name]=1
      before_color_parameters[$color_name]=$declaration
    done

    # Model a plugin manager that has already installed both autoload paths.
    for value in "${fpath[@]}"; do
      [[ $value == "$plugin_root/functions" || $value == "$plugin_root/completions" ||
        $value == "$plugin_root/chroma" ]] ||
        manager_fpath+=( "$value" )
    done
    fpath=( "${manager_fpath[@]}" "$plugin_root/functions" \
      "$plugin_root/completions" "$plugin_root/chroma" )
    before_fpath=( "${fpath[@]}" )

    typeset -g _fsh_work_dir=$fixture_root/work
    typeset -g _fsh_max_length=42
    alias f-sy-h=before
    _fsh_cursor_moved() { return 6 }

    for name in ${(k)functions}; do
      case $name in
        (_fsh_*|fsh_chroma|fsh_theme|add-zsh-hook|is-at-least|colors)
          before_owned_functions[$name]=${functions[$name]}
          ;;
      esac
    done

    for name in ${(k)parameters}; do
      case $name in
        (_fsh_*)
          before_owned_parameters[$name]=1
          ;;
      esac
    done

    setopt shwordsplit ksharrays globsubst

    builtin source "$plugin_path" || _fsh_test_fail 'non-interactive load failed'
    builtin source "$plugin_path" || _fsh_test_fail 'repeated non-interactive load failed'

    [[ -o shwordsplit && -o ksharrays && -o globsubst ]] ||
      _fsh_test_fail 'the entrypoint changed caller options'
    unsetopt shwordsplit ksharrays globsubst
    _fsh_test_count_value fpath "$plugin_root/functions"
    (( REPLY == 1 )) ||
      _fsh_test_fail 'the functions path is not idempotent in fpath'
    _fsh_test_count_value fpath "$plugin_root/completions"
    (( REPLY == 1 )) ||
      _fsh_test_fail 'the completions path is not idempotent in fpath'
    _fsh_test_count_value fpath "$plugin_root/chroma"
    (( REPLY == 1 )) ||
      _fsh_test_fail 'the chroma path is not idempotent in fpath'
    (( ! ${preexec_functions[(Ie)_fsh_preexec_hook]:-0} )) ||
      _fsh_test_fail 'non-interactive loading installed a preexec hook'

    command mkdir -p -- "$_fsh_work_dir"
    fsh_chroma list >/dev/null ||
      _fsh_test_fail 'cannot exercise the chroma command before unload'
    fsh_theme --secondary --quiet default ||
      _fsh_test_fail 'cannot exercise lazy theme functions before unload'
    if (( ${+before_owned_functions[colors]} )); then
      [[ ${functions[colors]-} == "${before_owned_functions[colors]}" ]] ||
        _fsh_test_fail 'theme command did not restore the colors function'
    else
      (( ! ${+functions[colors]} )) ||
        _fsh_test_fail 'theme command leaked the colors function'
    fi
    for color_name in color colour fg fg_bold fg_no_bold bg bg_bold bg_no_bold reset_color bold_color; do
      declaration=$(builtin typeset -p "$color_name" 2>/dev/null) || declaration=
      if (( ${+before_color_parameter_set[$color_name]} )); then
        [[ $declaration == "${before_color_parameters[$color_name]}" ]] ||
          _fsh_test_fail "theme command did not restore parameter: $color_name"
      else
        [[ -z $declaration ]] ||
          _fsh_test_fail "theme command leaked parameter: $color_name"
      fi
    done
    local -a reply=()
    local PREBUFFER= BUFFER='git status'
    _fsh_highlight_process "$PREBUFFER" "$BUFFER" 0 ||
      _fsh_test_fail 'cannot exercise lazy chroma functions before unload'
    _fsh_highlight_process '' 'echo changed runtime state' 0 ||
      _fsh_test_fail 'cannot exercise steady-state highlighting before unload'

    for name in ${(k)widgets}; do
      [[ ${widgets[$name]} == "${before_widgets[$name]-}" ]] || {
        _fsh_test_fail "non-interactive loading changed widget: $name"
        break
      }
    done

    (( ${+functions[fsh_plugin_unload]} )) ||
      _fsh_test_fail 'the unload function is missing'

    # Lifecycle accounting must not empty the caller's command hash: a local
    # named `path` would run the path setter on return and drop every entry.
    integer hashed_commands
    : ${+commands[zsh]}
    hashed_commands=${#${(f)"$(builtin hash)"}}
    (( hashed_commands > 0 )) ||
      _fsh_test_fail 'cannot observe the command hash table'
    _fsh_lifecycle_refresh || _fsh_test_fail 'lifecycle refresh failed'
    (( ${#${(f)"$(builtin hash)"}} == hashed_commands )) ||
      _fsh_test_fail 'a lifecycle refresh emptied the command hash table'

    # Without the preexec hook, a materialized chroma is accounted for at once,
    # so a caller change made afterwards is never mistaken for the plugin's.
    [[ ${_fsh_lifecycle_applied_functions[_fsh_chroma_git]-} != *'builtin autoload -X'* ]] ||
      _fsh_test_fail 'the git chroma was not accounted for after its first parse'
    (( ! _fsh_lifecycle_refresh_pending )) ||
      _fsh_test_fail 'a lifecycle refresh was deferred without the preexec hook'
    # Changes made after loading belong to the caller and must survive unload,
    # including when a chroma materializes and is accounted for afterwards.
    typeset -g _fsh_version=user-version
    _fsh_buffer_modified() { return 7 }
    fpath+=( "$fixture_root/user-fpath" )
    integer caller_module_loaded=0
    if ! zmodload -e zsh/mathfunc; then
      zmodload zsh/mathfunc && caller_module_loaded=1
    fi

    # With the hook installed, the accounting waits for the hook.
    typeset -ga preexec_functions=( _fsh_preexec_hook )
    _fsh_highlight_process '' 'grep -r pattern .' 0 ||
      _fsh_test_fail 'cannot exercise a deferred chroma accounting'
    (( _fsh_lifecycle_refresh_pending )) ||
      _fsh_test_fail 'the preexec hook did not defer the lifecycle refresh'
    [[ ${_fsh_lifecycle_applied_functions[_fsh_chroma_grep]-} == *'builtin autoload -X'* ]] ||
      _fsh_test_fail 'the grep chroma was accounted for on the widget path'
    _fsh_preexec_hook
    (( ! _fsh_lifecycle_refresh_pending )) ||
      _fsh_test_fail 'the preexec hook did not run the deferred refresh'
    [[ ${_fsh_lifecycle_applied_functions[_fsh_chroma_grep]-} != *'builtin autoload -X'* ]] ||
      _fsh_test_fail 'the preexec hook did not account for the grep chroma'
    preexec_functions=()

    integer owned_fd owned_pid
    exec {owned_fd}< <(command sleep 30)
    owned_pid=${sysparams[procsubstpid]}
    _fsh_lifecycle_register_fd "$owned_fd" '' "$owned_pid"
    fsh_plugin_unload || _fsh_test_fail 'non-interactive unload failed'

    (( ! ${+functions[fsh_plugin_unload]} )) ||
      _fsh_test_fail 'the unload function did not remove itself'
    command kill -0 "$owned_pid" 2>/dev/null &&
      _fsh_test_fail 'unload left an owned worker running'
    [[ ! -e /dev/fd/$owned_fd ]] ||
      _fsh_test_fail 'unload left an owned file descriptor open'
    [[ $_fsh_work_dir == $fixture_root/work ]] ||
      _fsh_test_fail 'unload did not restore _fsh_work_dir'
    [[ $_fsh_max_length == 42 ]] ||
      _fsh_test_fail 'unload did not restore _fsh_max_length'
    [[ ${aliases[f-sy-h]} == before ]] ||
      _fsh_test_fail 'unload did not restore the prior alias'
    [[ $_fsh_version == user-version ]] ||
      _fsh_test_fail 'unload removed a post-load parameter change'
    _fsh_buffer_modified
    (( $? == 7 )) ||
      _fsh_test_fail 'unload removed a post-load function change'
    _fsh_cursor_moved
    (( $? == 6 )) ||
      _fsh_test_fail 'unload did not restore a prior function'

    for name in ${(k)functions}; do
      case $name in
        (_fsh_*|fsh_chroma|fsh_theme|add-zsh-hook|is-at-least|colors)
          (( ${+before_owned_functions[$name]} )) ||
            [[ $name == _fsh_buffer_modified ]] || {
              _fsh_test_fail "unload left a lazy plugin function: $name"
              break
            }
          ;;
      esac
    done
    for name in ${(k)parameters}; do
      case $name in
        (_fsh_*)
          (( ${+before_owned_parameters[$name]} )) ||
            [[ $name == _fsh_version ]] || {
              _fsh_test_fail "unload left a lazy plugin parameter: $name"
              break
            }
          ;;
      esac
    done
    expected_fpath=( "${before_fpath[@]}" "$fixture_root/user-fpath" )
    _fsh_test_arrays_equal fpath expected_fpath ||
      _fsh_test_fail 'unload did not restore fpath while preserving a post-load change'
    if (( caller_module_loaded )); then
      zmodload -e zsh/mathfunc ||
        _fsh_test_fail 'unload removed a module the caller loaded'
      zmodload -u zsh/mathfunc 2>/dev/null || true
    fi

    local -a after_modules=( ${(f)"$(zmodload)"} )
    [[ ${(j:$'\n':)after_modules} == "${(j:$'\n':)before_modules}" ]] ||
      _fsh_test_fail "unload did not restore modules: before=${(j:,:)before_modules}; after=${(j:,:)after_modules}"
  } always {
    command rm -rf -- "$fixture_root"
  }
}

# The narrow accounting that follows a materialized chroma records only new
# functions and parameters. Prove, for every registered chroma, that this is
# everything the full accounting would have recorded.
_fsh_test_materialized_accounting() {
  builtin emulate -L zsh

  local fixture_root caller_pwd=$PWD key command_name name
  local -a narrow_values full_values
  local -A narrow_applied_parameters before_owned_parameters pending_chromas
  integer compared=0

  fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-accounting.XXXXXXXX") || return 1
  {
    zstyle ':fsh:config' work-dir "$fixture_root/work"
    for name in ${(M)${(k)parameters}:#_fsh_*}; do
      before_owned_parameters[$name]=1
    done
    fpath=( "$plugin_root"/{functions,completions,chroma} \
      "${(@)fpath:#$plugin_root/(functions|completions|chroma)}" )
    builtin source "$plugin_path" || {
      _fsh_test_fail 'accounting fixture load failed'
      return
    }
    typeset -ga preexec_functions=( _fsh_preexec_hook )
    builtin cd -q -- "$fixture_root" || return

    # Every registered chroma that is still an autoload stub must materialize
    # once in the loop below, or the comparison proves nothing about it.
    # A registry value of the form handler%name routes through the shared
    # handler to the _fsh_chroma_<name> definition; both must materialize.
    for key in ${(k)_fsh_state}; do
      [[ $key == chroma-* && ${_fsh_state[$key]} == _fsh_chroma_* ]] || continue
      for name in ${_fsh_state[$key]%\%*} \
          ${${(M)_fsh_state[$key]:#*%?*}:+_fsh_chroma_${_fsh_state[$key]#*%}}; do
        [[ ${functions[$name]-} == *'builtin autoload -X'* ]] &&
          pending_chromas[$name]=1
      done
    done
    (( $#pending_chromas > 0 )) ||
      _fsh_test_fail 'no registered chroma is left to materialize'

    for key in ${(ko)_fsh_state}; do
      [[ $key == chroma-* && ${_fsh_state[$key]} == _fsh_chroma_* ]] || continue
      command_name=${key#chroma-}
      _fsh_highlight_process '' "$command_name argument" 0 ||
        _fsh_test_fail "cannot parse a $command_name command line"
      (( _fsh_lifecycle_refresh_pending )) || continue
      (( ++compared ))
      _fsh_preexec_hook
      (( ! _fsh_lifecycle_refresh_pending )) ||
        _fsh_test_fail "the preexec hook left the $command_name accounting pending"

      # Runtime parameters change with every parse, so their declarations
      # legitimately differ between the two accountings.
      narrow_applied_parameters=()
      for name in ${(k)_fsh_lifecycle_applied_parameters}; do
        (( ${+_fsh_lifecycle_runtime_parameters[$name]} )) ||
          narrow_applied_parameters[$name]=${_fsh_lifecycle_applied_parameters[$name]}
      done
      narrow_values=(
        "${(@kv)_fsh_lifecycle_applied_function_set}"
        "${(@kv)_fsh_lifecycle_applied_functions}"
        "${(@k)_fsh_lifecycle_touched_functions}"
        "${(@k)_fsh_lifecycle_pending_autoloads}"
        "${(@kv)_fsh_lifecycle_applied_parameter_set}"
        "${(@kv)narrow_applied_parameters}"
        "${(@k)_fsh_lifecycle_touched_parameters}"
        "${(@k)_fsh_lifecycle_runtime_parameters}"
        "${(@)_fsh_lifecycle_added_fpath}"
        "${(@u)_fsh_lifecycle_owned_modules}"
      )
      _fsh_lifecycle_finalize || _fsh_test_fail "full accounting failed after $command_name"
      narrow_applied_parameters=()
      for name in ${(k)_fsh_lifecycle_applied_parameters}; do
        (( ${+_fsh_lifecycle_runtime_parameters[$name]} )) ||
          narrow_applied_parameters[$name]=${_fsh_lifecycle_applied_parameters[$name]}
      done
      full_values=(
        "${(@kv)_fsh_lifecycle_applied_function_set}"
        "${(@kv)_fsh_lifecycle_applied_functions}"
        "${(@k)_fsh_lifecycle_touched_functions}"
        "${(@k)_fsh_lifecycle_pending_autoloads}"
        "${(@kv)_fsh_lifecycle_applied_parameter_set}"
        "${(@kv)narrow_applied_parameters}"
        "${(@k)_fsh_lifecycle_touched_parameters}"
        "${(@k)_fsh_lifecycle_runtime_parameters}"
        "${(@)_fsh_lifecycle_added_fpath}"
        "${(@u)_fsh_lifecycle_owned_modules}"
      )
      narrow_values=( "${(@o)narrow_values}" )
      full_values=( "${(@o)full_values}" )
      _fsh_test_arrays_equal narrow_values full_values ||
        _fsh_test_fail "the $command_name chroma changed state the narrow accounting did not record"
    done

    for name in ${(k)pending_chromas}; do
      [[ ${functions[$name]-} != *'builtin autoload -X'* ]] ||
        _fsh_test_fail "the $name chroma never materialized, so it was not compared"
    done
    # One parse can materialize several names, so the count is a floor only.
    (( compared > 0 )) ||
      _fsh_test_fail "compared no accountings for $#pending_chromas pending chromas"

    preexec_functions=()
    fsh_plugin_unload || _fsh_test_fail 'accounting fixture unload failed'
    for name in ${(M)${(k)parameters}:#_fsh_*}; do
      (( ${+before_owned_parameters[$name]} )) || {
        _fsh_test_fail "accounting fixture unload left a parameter: $name"
        break
      }
    done
  } always {
    builtin cd -q -- "$caller_pwd"
    command rm -rf -- "$fixture_root"
  }
}

_fsh_test_interactive() {
  builtin emulate -L zsh

  local name
  local -a before_fpath=( "${fpath[@]}" ) before_hooks before_modules
  local -a before_zle_hook_types after_zle_hook_types
  local -A before_widgets before_zle_hook_functions
  integer before_zle_hook_types_set=0 after_zle_hook_types_set=0

  [[ -o interactive ]] || {
    _fsh_test_fail 'interactive lifecycle case requires zsh -i'
    return
  }

  _fsh_test_widget_option_boundary ||
    _fsh_test_fail 'wrapped widget option boundary probe failed'
  _fsh_test_history_boundary ||
    _fsh_test_fail 'wrapped history widget boundary probe failed'
  _fsh_test_kill_ring_boundary ||
    _fsh_test_fail 'kill ring widget boundary probe failed'

  zmodload zsh/parameter zsh/zleparameter || {
    _fsh_test_fail 'required observer modules are unavailable'
    return
  }
  autoload -Uz +X add-zsh-hook is-at-least || {
    _fsh_test_fail 'cannot prime distributed Zsh helper functions'
    return
  }

  _fsh_test_widget_before() { :; }
  _fsh_test_widget_after() { :; }
  zle -N self-insert _fsh_test_widget_before

  before_widgets=( "${(@kv)widgets}" )
  before_hooks=( "${preexec_functions[@]}" )
  before_modules=( ${(f)"$(zmodload)"} )
  for name in ${(k)functions}; do
    [[ $name == add-zle-hook-widget || $name == azhw:* ]] || continue
    before_zle_hook_functions[$name]=${functions[$name]}
  done
  if (( ${before_modules[(Ie)zsh/zutil]} )); then
    zstyle -a zle-hook types before_zle_hook_types && before_zle_hook_types_set=1
  fi
  alias f-sy-h=before

  builtin source "$plugin_path" || {
    _fsh_test_fail 'interactive load failed'
    return
  }
  builtin source "$plugin_path" ||
    _fsh_test_fail 'repeated interactive load failed'

  (( ${preexec_functions[(Ie)_fsh_preexec_hook]} )) ||
    _fsh_test_fail 'interactive loading did not install the preexec hook'
  [[ ${widgets[self-insert]} == user:_fsh_widget_* ]] ||
    _fsh_test_fail 'interactive loading did not wrap self-insert'

  zle -N self-insert _fsh_test_widget_after
  alias f-sy-h=after
  fsh_plugin_unload || _fsh_test_fail 'interactive unload failed'

  [[ ${widgets[self-insert]} == user:_fsh_test_widget_after ]] ||
    _fsh_test_fail 'unload overwrote a post-load widget change'
  [[ ${aliases[f-sy-h]} == after ]] ||
    _fsh_test_fail 'unload overwrote a post-load alias change'
  (( ${#${(M)${(k)widgets}:#_fsh_orig-*}} == 0 )) ||
    _fsh_test_fail 'unload left saved widget copies'
  (( ${#${(M)${(k)functions}:#_fsh_widget_*}} == 0 )) ||
    _fsh_test_fail 'unload left generated widget wrappers'

  for name in ${(k)functions}; do
    [[ $name == add-zle-hook-widget || $name == azhw:* ]] || continue
    [[ ${functions[$name]} == "${before_zle_hook_functions[$name]-}" &&
      ${+before_zle_hook_functions[$name]} -eq 1 ]] || {
      _fsh_test_fail "unload left shared ZLE hook function: $name"
      break
    }
  done
  for name in ${(k)before_zle_hook_functions}; do
    [[ ${functions[$name]-} == "${before_zle_hook_functions[$name]}" ]] || {
      _fsh_test_fail "unload did not restore shared ZLE hook function: $name"
      break
    }
  done
  for name in ${(k)before_widgets}; do
    [[ $name == self-insert ]] && continue
    [[ ${widgets[$name]-} == "${before_widgets[$name]}" ]] || {
      _fsh_test_fail "unload did not restore widget: $name"
      break
    }
  done
  for name in ${(k)widgets}; do
    [[ $name == self-insert ]] && continue
    (( ${+before_widgets[$name]} )) || {
      _fsh_test_fail "unload left a new widget: $name"
      break
    }
  done

  local -a after_hooks=( "${preexec_functions[@]}" )
  _fsh_test_arrays_equal after_hooks before_hooks ||
    _fsh_test_fail 'unload did not restore preexec hooks'
  _fsh_test_arrays_equal fpath before_fpath ||
    _fsh_test_fail 'interactive unload did not restore fpath'
  local -a after_modules=( ${(f)"$(zmodload)"} )
  [[ ${(j:$'\n':)after_modules} == "${(j:$'\n':)before_modules}" ]] ||
    _fsh_test_fail "interactive unload did not restore modules: before=${(j:,:)before_modules}; after=${(j:,:)after_modules}"
  if (( ${after_modules[(Ie)zsh/zutil]} )); then
    zstyle -a zle-hook types after_zle_hook_types && after_zle_hook_types_set=1
  fi
  (( after_zle_hook_types_set == before_zle_hook_types_set )) &&
      _fsh_test_arrays_equal after_zle_hook_types before_zle_hook_types ||
    _fsh_test_fail 'unload did not restore the shared ZLE hook registry'
}

_fsh_test_partial_failure() {
  builtin emulate -L zsh

  local fixture_root=$1 fixture_plugin=$1/F-Sy-H.plugin.zsh
  local -a before_fpath=( "${fpath[@]}" )

  command mkdir -p -- "$fixture_root/lib" || return 1
  command cp -- "$plugin_path" "$fixture_plugin" || return 1
  command cp -- "$plugin_root/lib/lifecycle.zsh" "$fixture_root/lib/lifecycle.zsh" || return 1

  if builtin source "$fixture_plugin" 2>/dev/null; then
    _fsh_test_fail 'the incomplete fixture unexpectedly loaded'
  fi
  (( ! ${+functions[fsh_plugin_unload]} )) ||
    _fsh_test_fail 'partial failure left the unload function'
  (( ! ${+parameters[_fsh_lifecycle_started]} )) ||
    _fsh_test_fail 'partial failure left lifecycle state'
  (( ! ${+parameters[_fsh_base_dir]} )) ||
    _fsh_test_fail 'partial failure left _fsh_base_dir'
  _fsh_test_arrays_equal fpath before_fpath ||
    _fsh_test_fail 'partial failure did not restore fpath'
}

case $test_case in
  (noninteractive)
    typeset partial_root
    partial_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-partial.XXXXXXXX") || exit 1
    {
      _fsh_test_noninteractive
      _fsh_test_materialized_accounting
      _fsh_test_partial_failure "$partial_root"
    } always {
      command rm -rf -- "$partial_root"
    }
    ;;
  (interactive)
    _fsh_test_interactive
    ;;
  (*)
    builtin print -u2 -r -- "unknown lifecycle test case: $test_case"
    exit 2
    ;;
esac

exit "$test_status"
