# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

# This private library records the shell resources changed by the entrypoint.
# It has no top-level effects other than defining the lifecycle functions below.

_fsh_lifecycle_function_owned() {
  builtin emulate -L zsh

  case $1 in
    (_fsh_lifecycle_*) return 1 ;;
    (_fsh_*|fsh_chroma|fsh_theme|add-zsh-hook|is-at-least|colors) return 0 ;;
    (*) return 1 ;;
  esac
}

_fsh_lifecycle_parameter_owned() {
  builtin emulate -L zsh

  case $1 in
    (_fsh_lifecycle_*) return 1 ;;
    (_fsh_*) return 0 ;;
    (*) return 1 ;;
  esac
}

_fsh_lifecycle_parameter_declaration() {
  builtin emulate -L zsh

  REPLY=$(builtin typeset -p "$1" 2>/dev/null) || REPLY=
}

_fsh_lifecycle_arrays_equal() {
  builtin emulate -L zsh

  local left_name=$1 right_name=$2
  local -a left=( "${(@P)left_name}" ) right=( "${(@P)right_name}" )
  integer index

  (( $#left == $#right )) || return 1
  for (( index = 1; index <= $#left; ++index )); do
    [[ ${left[index]} == "${right[index]}" ]] || return 1
  done
}

_fsh_lifecycle_register_fd() {
  builtin emulate -L zsh

  local fd=$1 handler=${2-} pid=${3-}
  [[ $fd == <-> ]] || return 1
  _fsh_lifecycle_owned_fd_handlers[$fd]=$handler
  _fsh_lifecycle_owned_fd_pids[$fd]=$pid
}

_fsh_lifecycle_release_fd() {
  builtin emulate -L zsh

  local fd=$1
  builtin unset "_fsh_lifecycle_owned_fd_handlers[$fd]"
  builtin unset "_fsh_lifecycle_owned_fd_pids[$fd]"
}

_fsh_lifecycle_cleanup_fds() {
  builtin emulate -L zsh

  local fd pid
  integer owned_fd
  for fd in ${(k)_fsh_lifecycle_owned_fd_handlers}; do
    pid=${_fsh_lifecycle_owned_fd_pids[$fd]-}
    if (( ${+builtins[zle]} )); then
      zle -F -w "$fd" 2>/dev/null || zle -F "$fd" 2>/dev/null || true
    fi
    if [[ $pid == <-> ]] && (( pid > 1 && pid != $$ )); then
      builtin kill -TERM "$pid" 2>/dev/null || true
      builtin wait "$pid" 2>/dev/null || true
    fi
    owned_fd=$fd
    { exec {owned_fd}<&- } 2>/dev/null || true
  done
  _fsh_lifecycle_owned_fd_handlers=()
  _fsh_lifecycle_owned_fd_pids=()
}

_fsh_lifecycle_begin() {
  builtin emulate -L zsh

  local name module REPLY
  local -a loaded_modules

  typeset -gA _fsh_lifecycle_original_function_set=()
  typeset -gA _fsh_lifecycle_original_functions=()
  typeset -gA _fsh_lifecycle_applied_function_set=()
  typeset -gA _fsh_lifecycle_applied_functions=()
  typeset -gA _fsh_lifecycle_pending_autoloads=()
  typeset -gA _fsh_lifecycle_touched_functions=()
  typeset -gA _fsh_lifecycle_original_parameter_set=()
  typeset -gA _fsh_lifecycle_original_parameters=()
  typeset -gA _fsh_lifecycle_applied_parameter_set=()
  typeset -gA _fsh_lifecycle_applied_parameters=()
  typeset -gA _fsh_lifecycle_touched_parameters=()
  # Highlighting owns the final values of these private runtime parameters.
  typeset -gA _fsh_lifecycle_runtime_parameters=(
    _fsh_assigns_seen 1
    _fsh_command_output 1
    _fsh_command_type_cache 1
    _fsh_complex_brackets 1
    _fsh_last_commands 1
    _fsh_main_cache 1
    _fsh_prior_buffer 1
    _fsh_prior_cursor 1
    _fsh_prior_region_active 1
    _fsh_state 1
    _fsh_style_ranges 1
    _fsh_styles 1
    _fsh_theme_name 1
    _fsh_token_types 1
  )
  typeset -gA _fsh_lifecycle_original_module_set=()
  typeset -ga _fsh_lifecycle_owned_modules=()
  typeset -ga _fsh_lifecycle_original_fpath=( "${fpath[@]}" )
  typeset -ga _fsh_lifecycle_applied_fpath=()
  typeset -ga _fsh_lifecycle_added_fpath=()
  typeset -gA _fsh_lifecycle_original_widget_set=()
  typeset -gA _fsh_lifecycle_original_widgets=()
  typeset -gA _fsh_lifecycle_applied_widget_set=()
  typeset -gA _fsh_lifecycle_applied_widgets=()
  typeset -gA _fsh_lifecycle_touched_widgets=()
  typeset -gA _fsh_lifecycle_owned_fd_handlers=()
  typeset -gA _fsh_lifecycle_owned_fd_pids=()
  typeset -gi _fsh_lifecycle_widgets_captured=0
  typeset -gi _fsh_lifecycle_started=1
  typeset -gi _fsh_lifecycle_loaded=0

  loaded_modules=( "$@" )
  for module in "${loaded_modules[@]}"; do
    _fsh_lifecycle_original_module_set[$module]=1
  done

  for name in ${(k)functions}; do
    _fsh_lifecycle_function_owned "$name" || continue
    _fsh_lifecycle_original_function_set[$name]=1
    _fsh_lifecycle_original_functions[$name]=${functions[$name]}
  done

  for name in ${(k)parameters}; do
    _fsh_lifecycle_parameter_owned "$name" || continue
    _fsh_lifecycle_parameter_declaration "$name"
    _fsh_lifecycle_original_parameter_set[$name]=1
    _fsh_lifecycle_original_parameters[$name]=$REPLY
  done

}

_fsh_lifecycle_capture_widgets() {
  builtin emulate -L zsh

  local name
  (( _fsh_lifecycle_widgets_captured )) && return 0
  (( ${+parameters[widgets]} )) || return 1

  for name in ${(k)widgets}; do
    _fsh_lifecycle_original_widget_set[$name]=1
    _fsh_lifecycle_original_widgets[$name]=${widgets[$name]}
  done
  _fsh_lifecycle_widgets_captured=1
}

_fsh_lifecycle_finalize() {
  builtin emulate -L zsh

  local name module path declaration REPLY
  local -a names loaded_modules

  (( _fsh_lifecycle_started )) || return 1

  names=( ${(k)_fsh_lifecycle_original_function_set} )
  for name in ${(k)functions}; do
    _fsh_lifecycle_function_owned "$name" && names+=( "$name" )
  done
  typeset -U names
  for name in "${names[@]}"; do
    if (( ${+functions[$name]} )); then
      [[ ${functions[$name]} == "${_fsh_lifecycle_original_functions[$name]-}" &&
        ${+_fsh_lifecycle_original_function_set[$name]} -eq 1 ]] && continue
      _fsh_lifecycle_applied_function_set[$name]=1
      _fsh_lifecycle_applied_functions[$name]=${functions[$name]}
    else
      (( ${+_fsh_lifecycle_original_function_set[$name]} )) || continue
      _fsh_lifecycle_applied_function_set[$name]=0
      _fsh_lifecycle_applied_functions[$name]=
    fi
    _fsh_lifecycle_touched_functions[$name]=1
  done

  _fsh_lifecycle_pending_autoloads=()
  for name in ${(k)_fsh_lifecycle_touched_functions}; do
    [[ ${_fsh_lifecycle_applied_functions[$name]-} == *'builtin autoload -X'* ]] &&
      _fsh_lifecycle_pending_autoloads[$name]=1
  done

  names=( ${(k)_fsh_lifecycle_original_parameter_set} )
  for name in ${(k)parameters}; do
    _fsh_lifecycle_parameter_owned "$name" && names+=( "$name" )
  done
  typeset -U names
  for name in "${names[@]}"; do
    if (( ${+parameters[$name]} )); then
      _fsh_lifecycle_parameter_declaration "$name"
      declaration=$REPLY
      [[ $declaration == "${_fsh_lifecycle_original_parameters[$name]-}" &&
        ${+_fsh_lifecycle_original_parameter_set[$name]} -eq 1 ]] && continue
      _fsh_lifecycle_applied_parameter_set[$name]=1
      _fsh_lifecycle_applied_parameters[$name]=$declaration
    else
      (( ${+_fsh_lifecycle_original_parameter_set[$name]} )) || continue
      _fsh_lifecycle_applied_parameter_set[$name]=0
      _fsh_lifecycle_applied_parameters[$name]=
    fi
    _fsh_lifecycle_touched_parameters[$name]=1
  done

  _fsh_lifecycle_applied_fpath=( "${fpath[@]}" )
  for path in "${_fsh_lifecycle_applied_fpath[@]}"; do
    (( ${_fsh_lifecycle_original_fpath[(Ie)$path]} )) ||
      _fsh_lifecycle_added_fpath+=( "$path" )
  done
  typeset -U _fsh_lifecycle_added_fpath

  loaded_modules=( ${(f)"$(zmodload)"} )
  for module in "${loaded_modules[@]}"; do
    (( ${+_fsh_lifecycle_original_module_set[$module]} )) ||
      _fsh_lifecycle_owned_modules+=( "$module" )
  done

  if (( _fsh_lifecycle_widgets_captured )); then
    names=( ${(k)_fsh_lifecycle_original_widget_set} ${(k)widgets} )
    typeset -U names
    for name in "${names[@]}"; do
      if (( ${+widgets[$name]} )); then
        [[ ${widgets[$name]} == "${_fsh_lifecycle_original_widgets[$name]-}" &&
          ${+_fsh_lifecycle_original_widget_set[$name]} -eq 1 ]] && continue
        _fsh_lifecycle_applied_widget_set[$name]=1
        _fsh_lifecycle_applied_widgets[$name]=${widgets[$name]}
      else
        (( ${+_fsh_lifecycle_original_widget_set[$name]} )) || continue
        _fsh_lifecycle_applied_widget_set[$name]=0
        _fsh_lifecycle_applied_widgets[$name]=
      fi
      _fsh_lifecycle_touched_widgets[$name]=1
    done
  fi

  _fsh_lifecycle_loaded=1
}

_fsh_lifecycle_refresh() {
  builtin emulate -L zsh

  (( ${+parameters[_fsh_lifecycle_started]} && _fsh_lifecycle_started )) || return 0
  _fsh_lifecycle_finalize
}

_fsh_lifecycle_checkpoint() {
  builtin emulate -L zsh

  local name
  local -A touched_parameters

  (( ${+parameters[_fsh_lifecycle_started]} && _fsh_lifecycle_started )) || return 0

  for name in ${(k)_fsh_lifecycle_pending_autoloads}; do
    [[ ${functions[$name]-} == "${_fsh_lifecycle_applied_functions[$name]-}" ]] || {
      # A materialized autoload may add more plugin-owned shell resources.
      touched_parameters=( "${(@kv)_fsh_lifecycle_touched_parameters}" )
      _fsh_lifecycle_refresh
      for name in ${(k)_fsh_lifecycle_touched_parameters}; do
        (( ${+touched_parameters[$name]} )) ||
          _fsh_lifecycle_runtime_parameters[$name]=1
      done
      return
    }
  done
}

_fsh_lifecycle_restore_widget() {
  builtin emulate -L zsh

  local name=$1 descriptor=$2 rest widget_type function_name
  integer was_set="${3:-0}"

  if (( ! was_set )) || [[ -z $descriptor ]]; then
    zle -D "$name" 2>/dev/null || true
    return 0
  fi

  case $descriptor in
    (builtin)
      zle -A ".$name" "$name"
      ;;
    (user:*)
      zle -N "$name" "${descriptor#user:}"
      ;;
    (completion:*:*)
      rest=${descriptor#completion:}
      widget_type=${rest%%:*}
      function_name=${rest#*:}
      zle -C "$name" "$widget_type" "$function_name"
      ;;
    (*)
      zle -D "$name" 2>/dev/null || true
      ;;
  esac
}

_fsh_lifecycle_restore_widgets() {
  builtin emulate -L zsh

  local name current applied original
  integer original_set applied_set pass

  (( _fsh_lifecycle_widgets_captured )) || return 0
  (( ${+parameters[widgets]} )) || return 0

  for pass in 1 2; do
    for name in ${(k)_fsh_lifecycle_touched_widgets}; do
      if (( pass == 1 )); then
        [[ $name == fsh-orig-* ]] && continue
      else
        [[ $name == fsh-orig-* ]] || continue
      fi

      applied_set=${_fsh_lifecycle_applied_widget_set[$name]:-0}
      current=${widgets[$name]-}
      applied=${_fsh_lifecycle_applied_widgets[$name]-}
      if (( applied_set )); then
        (( ${+widgets[$name]} )) && [[ $current == "$applied" ]] || continue
      else
        (( ${+widgets[$name]} )) && continue
      fi

      original_set=${+_fsh_lifecycle_original_widget_set[$name]}
      original=${_fsh_lifecycle_original_widgets[$name]-}
      _fsh_lifecycle_restore_widget "$name" "$original" "$original_set" || return
    done
  done
}

_fsh_lifecycle_restore_functions() {
  builtin emulate -L zsh

  local name applied original
  integer applied_set original_set

  for name in ${(k)_fsh_lifecycle_touched_functions}; do
    applied_set=${_fsh_lifecycle_applied_function_set[$name]:-0}
    applied=${_fsh_lifecycle_applied_functions[$name]-}
    if (( applied_set )); then
      (( ${+functions[$name]} )) && [[ ${functions[$name]} == "$applied" ]] || continue
    else
      (( ${+functions[$name]} )) && continue
    fi

    original_set=${+_fsh_lifecycle_original_function_set[$name]}
    original=${_fsh_lifecycle_original_functions[$name]-}
    if (( original_set )); then
      functions[$name]=$original
    else
      builtin unfunction "$name" 2>/dev/null || true
    fi
  done
}

_fsh_lifecycle_restore_parameters() {
  builtin emulate -L zsh

  local name current applied original REPLY
  integer applied_set original_set

  for name in ${(k)_fsh_lifecycle_touched_parameters}; do
    applied_set=${_fsh_lifecycle_applied_parameter_set[$name]:-0}
    applied=${_fsh_lifecycle_applied_parameters[$name]-}
    if (( ! ${+_fsh_lifecycle_runtime_parameters[$name]} )); then
      if (( applied_set )); then
        (( ${+parameters[$name]} )) || continue
        _fsh_lifecycle_parameter_declaration "$name"
        current=$REPLY
        [[ $current == "$applied" ]] || continue
      else
        (( ${+parameters[$name]} )) && continue
      fi
    fi

    original_set=${+_fsh_lifecycle_original_parameter_set[$name]}
    original=${_fsh_lifecycle_original_parameters[$name]-}
    if (( original_set )); then
      builtin unset "$name" 2>/dev/null || true
      # The declaration is generated by Zsh from trusted in-process state.
      builtin eval "$original"
    else
      builtin unset "$name" 2>/dev/null || true
    fi
  done
}

_fsh_lifecycle_restore_fpath() {
  builtin emulate -L zsh

  local path
  integer count index candidate

  if _fsh_lifecycle_arrays_equal fpath _fsh_lifecycle_applied_fpath; then
    fpath=( "${_fsh_lifecycle_original_fpath[@]}" )
    return 0
  fi

  for path in "${_fsh_lifecycle_added_fpath[@]}"; do
    count=0
    index=0
    for (( candidate = 1; candidate <= $#fpath; ++candidate )); do
      [[ ${fpath[candidate]} == "$path" ]] || continue
      (( ++count ))
      index=$candidate
    done
    (( count == 1 )) || continue
    (( index )) && fpath[$index]=()
  done
}

_fsh_lifecycle_abort() {
  builtin emulate -L zsh

  local load_status=${1:-1}
  _fsh_lifecycle_finalize 2>/dev/null || true
  fsh_plugin_unload 2>/dev/null || true
  return "$load_status"
}

fsh_plugin_unload() {
  builtin emulate -L zsh

  local module helper
  local -a helpers

  if (( ${+parameters[_fsh_lifecycle_started]} && _fsh_lifecycle_started )); then
    _fsh_lifecycle_cleanup_fds
    if (( ${+functions[add-zsh-hook]} )); then
      add-zsh-hook -d preexec _fsh_preexec_hook 2>/dev/null || true
    fi

    _fsh_lifecycle_restore_widgets
    _fsh_lifecycle_restore_fpath
    _fsh_lifecycle_restore_functions
    _fsh_lifecycle_restore_parameters

    for module in "${(@Oa)_fsh_lifecycle_owned_modules}"; do
      zmodload -ui "$module" 2>/dev/null || true
    done
  fi

  helpers=(
    _fsh_lifecycle_function_owned
    _fsh_lifecycle_parameter_owned
    _fsh_lifecycle_parameter_declaration
    _fsh_lifecycle_arrays_equal
    _fsh_lifecycle_register_fd
    _fsh_lifecycle_release_fd
    _fsh_lifecycle_cleanup_fds
    _fsh_lifecycle_begin
    _fsh_lifecycle_capture_widgets
    _fsh_lifecycle_finalize
    _fsh_lifecycle_refresh
    _fsh_lifecycle_checkpoint
    _fsh_lifecycle_restore_widget
    _fsh_lifecycle_restore_widgets
    _fsh_lifecycle_restore_functions
    _fsh_lifecycle_restore_parameters
    _fsh_lifecycle_restore_fpath
    _fsh_lifecycle_abort
  )

  builtin unset _fsh_lifecycle_original_function_set
  builtin unset _fsh_lifecycle_original_functions
  builtin unset _fsh_lifecycle_applied_function_set
  builtin unset _fsh_lifecycle_applied_functions
  builtin unset _fsh_lifecycle_pending_autoloads
  builtin unset _fsh_lifecycle_touched_functions
  builtin unset _fsh_lifecycle_original_parameter_set
  builtin unset _fsh_lifecycle_original_parameters
  builtin unset _fsh_lifecycle_applied_parameter_set
  builtin unset _fsh_lifecycle_applied_parameters
  builtin unset _fsh_lifecycle_touched_parameters
  builtin unset _fsh_lifecycle_runtime_parameters
  builtin unset _fsh_lifecycle_original_module_set
  builtin unset _fsh_lifecycle_owned_modules
  builtin unset _fsh_lifecycle_original_fpath
  builtin unset _fsh_lifecycle_applied_fpath
  builtin unset _fsh_lifecycle_added_fpath
  builtin unset _fsh_lifecycle_original_widget_set
  builtin unset _fsh_lifecycle_original_widgets
  builtin unset _fsh_lifecycle_applied_widget_set
  builtin unset _fsh_lifecycle_applied_widgets
  builtin unset _fsh_lifecycle_touched_widgets
  builtin unset _fsh_lifecycle_owned_fd_handlers
  builtin unset _fsh_lifecycle_owned_fd_pids
  builtin unset _fsh_lifecycle_widgets_captured
  builtin unset _fsh_lifecycle_started
  builtin unset _fsh_lifecycle_loaded

  for helper in "${helpers[@]}"; do
    builtin unfunction "$helper" 2>/dev/null || true
  done
  builtin unfunction fsh_plugin_unload
}
