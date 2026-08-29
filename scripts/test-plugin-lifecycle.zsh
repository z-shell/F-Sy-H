#!/usr/bin/env zsh

builtin emulate -R zsh
builtin setopt pipe_fail

typeset -r plugin_root=${0:A:h:h}
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

_fsh_test_noninteractive() {
  builtin emulate -L zsh

  local fixture_root name value
  local -a before_fpath before_modules expected_fpath manager_fpath
  local -A before_widgets

  fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-lifecycle.XXXXXXXX") || return 1
  {
    zmodload zsh/parameter zsh/zleparameter ||
      _fsh_test_fail 'required observer modules are unavailable'
    before_widgets=( "${(@kv)widgets}" )
    before_modules=( ${(f)"$(zmodload)"} )

    # Model a plugin manager that has already installed both autoload paths.
    for value in "${fpath[@]}"; do
      [[ $value == "$plugin_root" || $value == "$plugin_root/functions" ]] ||
        manager_fpath+=( "$value" )
    done
    fpath=( "${manager_fpath[@]}" "$plugin_root" "$plugin_root/functions" )
    before_fpath=( "${fpath[@]}" )

    setopt shwordsplit ksharrays globsubst
    typeset -g FAST_WORK_DIR=$fixture_root/work
    typeset -g ZSH_HIGHLIGHT_MAXLENGTH=42
    alias f-sy-h=before
    _zsh_highlight_cursor_moved() { return 6 }

    builtin source "$plugin_path" || _fsh_test_fail 'non-interactive load failed'
    builtin source "$plugin_path" || _fsh_test_fail 'repeated non-interactive load failed'

    [[ -o shwordsplit && -o ksharrays && -o globsubst ]] ||
      _fsh_test_fail 'the entrypoint changed caller options'
    unsetopt shwordsplit ksharrays globsubst
    _fsh_test_count_value fpath "$plugin_root"
    (( REPLY == 1 )) ||
      _fsh_test_fail 'the repository path is not idempotent in fpath'
    _fsh_test_count_value fpath "$plugin_root/functions"
    (( REPLY == 1 )) ||
      _fsh_test_fail 'the functions path is not idempotent in fpath'
    (( ! ${preexec_functions[(Ie)_zsh_highlight_preexec_hook]:-0} )) ||
      _fsh_test_fail 'non-interactive loading installed a preexec hook'

    for name in ${(k)widgets}; do
      [[ ${widgets[$name]} == "${before_widgets[$name]-}" ]] || {
        _fsh_test_fail "non-interactive loading changed widget: $name"
        break
      }
    done

    (( ${+functions[f-sy-h_plugin_unload]} )) ||
      _fsh_test_fail 'the unload function is missing'

    # Changes made after loading belong to the caller and must survive unload.
    typeset -g FAST_HIGHLIGHT_VERSION=user-version
    _zsh_highlight_buffer_modified() { return 7 }
    fpath+=( "$fixture_root/user-fpath" )
    f-sy-h_plugin_unload || _fsh_test_fail 'non-interactive unload failed'

    (( ! ${+functions[f-sy-h_plugin_unload]} )) ||
      _fsh_test_fail 'the unload function did not remove itself'
    [[ $FAST_WORK_DIR == $fixture_root/work ]] ||
      _fsh_test_fail 'unload did not restore FAST_WORK_DIR'
    [[ $ZSH_HIGHLIGHT_MAXLENGTH == 42 ]] ||
      _fsh_test_fail 'unload did not restore ZSH_HIGHLIGHT_MAXLENGTH'
    [[ ${aliases[f-sy-h]} == before ]] ||
      _fsh_test_fail 'unload did not restore the prior alias'
    [[ $FAST_HIGHLIGHT_VERSION == user-version ]] ||
      _fsh_test_fail 'unload removed a post-load parameter change'
    _zsh_highlight_buffer_modified
    (( $? == 7 )) ||
      _fsh_test_fail 'unload removed a post-load function change'
    _zsh_highlight_cursor_moved
    (( $? == 6 )) ||
      _fsh_test_fail 'unload did not restore a prior function'
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

  (( ${preexec_functions[(Ie)_zsh_highlight_preexec_hook]} )) ||
    _fsh_test_fail 'interactive loading did not install the preexec hook'
  [[ ${widgets[self-insert]} == user:_zsh_highlight_widget_* ]] ||
    _fsh_test_fail 'interactive loading did not wrap self-insert'

  zle -N self-insert _fsh_test_widget_after
  alias f-sy-h=after
  f-sy-h_plugin_unload || _fsh_test_fail 'interactive unload failed'

  [[ ${widgets[self-insert]} == user:_fsh_test_widget_after ]] ||
    _fsh_test_fail 'unload overwrote a post-load widget change'
  [[ ${aliases[f-sy-h]} == after ]] ||
    _fsh_test_fail 'unload overwrote a post-load alias change'
  (( ${#${(M)${(k)widgets}:#orig-*}} == 0 )) ||
    _fsh_test_fail 'unload left saved widget copies'
  (( ${#${(M)${(k)functions}:#_zsh_highlight_widget_*}} == 0 )) ||
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
  (( ! ${+functions[f-sy-h_plugin_unload]} )) ||
    _fsh_test_fail 'partial failure left the unload function'
  (( ! ${+parameters[_fsh_lifecycle_started]} )) ||
    _fsh_test_fail 'partial failure left lifecycle state'
  (( ! ${+parameters[FAST_BASE_DIR]} )) ||
    _fsh_test_fail 'partial failure left FAST_BASE_DIR'
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
