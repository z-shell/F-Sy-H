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

    # Changes made after loading belong to the caller and must survive unload.
    typeset -g _fsh_version=user-version
    _fsh_buffer_modified() { return 7 }
    fpath+=( "$fixture_root/user-fpath" )

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

    local -a after_modules=( ${(f)"$(zmodload)"} )
    [[ ${(j:$'\n':)after_modules} == "${(j:$'\n':)before_modules}" ]] ||
      _fsh_test_fail "unload did not restore modules: before=${(j:,:)before_modules}; after=${(j:,:)after_modules}"
  } always {
    command rm -rf -- "$fixture_root"
  }
}

_fsh_test_interactive() {
  builtin emulate -L zsh

  local name
  local -a before_fpath=( "${fpath[@]}" ) before_hooks before_modules
  local -A before_widgets

  [[ -o interactive ]] || {
    _fsh_test_fail 'interactive lifecycle case requires zsh -i'
    return
  }

  _fsh_test_widget_option_boundary ||
    _fsh_test_fail 'wrapped widget option boundary probe failed'

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
  (( ${#${(M)${(k)widgets}:#fsh-orig-*}} == 0 )) ||
    _fsh_test_fail 'unload left saved widget copies'
  (( ${#${(M)${(k)functions}:#_fsh_widget_*}} == 0 )) ||
    _fsh_test_fail 'unload left generated widget wrappers'

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
