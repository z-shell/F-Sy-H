# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

# This private library records the shell resources changed by the entrypoint.
# It has no top-level effects other than defining the lifecycle functions below.

_fsh_lifecycle_function_owned() {
  builtin emulate -L zsh

  case $1 in
    (_fsh_lifecycle_*) return 1 ;;
    # _zsh_highlight is the compatibility name this plugin takes over so
    # that zsh-history-substring-search does not bind its own stub to it;
    # owning it here is what restores whatever held the name before us.
    (_fsh_*|fsh_chroma|fsh_theme|_zsh_highlight|add-zsh-hook|add-zle-hook-widget|azhw:*|is-at-least|colors) return 0 ;;
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
  typeset -ga _fsh_lifecycle_original_zle_hook_types=()
  typeset -gi _fsh_lifecycle_original_zle_hook_types_set=0
  typeset -gi _fsh_lifecycle_widgets_captured=0
  typeset -gi _fsh_lifecycle_refresh_pending=0
  typeset -gi _fsh_lifecycle_started=1
  typeset -gi _fsh_lifecycle_loaded=0

  loaded_modules=( "$@" )
  if (( ${loaded_modules[(Ie)zsh/zutil]} )) &&
      zstyle -a zle-hook types _fsh_lifecycle_original_zle_hook_types; then
    _fsh_lifecycle_original_zle_hook_types_set=1
  fi
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

  local name module entry declaration REPLY
  local -a names loaded_modules

  (( _fsh_lifecycle_started )) || return 1

  names=( ${(k)_fsh_lifecycle_original_function_set} )
  for name in ${(k)functions}; do
    _fsh_lifecycle_function_owned "$name" && names+=( "$name" )
  done
  typeset -U names
  for name in "${names[@]}"; do
    # The compatibility callback is installed once, never by a lazy operation.
    [[ $name == _zsh_highlight ]] && (( _fsh_lifecycle_loaded )) && continue
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
  for entry in "${_fsh_lifecycle_applied_fpath[@]}"; do
    (( ${_fsh_lifecycle_original_fpath[(Ie)$entry]} )) ||
      _fsh_lifecycle_added_fpath+=( "$entry" )
  done
  typeset -U _fsh_lifecycle_added_fpath

  loaded_modules=( ${(f)"$(zmodload)"} )
  for module in "${loaded_modules[@]}"; do
    (( ${+_fsh_lifecycle_original_module_set[$module]} )) ||
      _fsh_lifecycle_owned_modules+=( "$module" )
  done

  # Widgets are installed only during initial load. Lazy function/theme refreshes
  # must not claim widgets subsequently installed or replaced by other plugins.
  if (( _fsh_lifecycle_widgets_captured && ! _fsh_lifecycle_loaded )); then
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

# Accounts for the autoloads that materialized since the last accounting
# without re-enumerating everything _fsh_lifecycle_finalize does. It records
# the new bodies of the pending autoloads and every owned function and
# parameter that did not exist before, and nothing else: re-snapshotting a
# recorded parameter, the search path, or the loaded modules would claim
# whatever the caller changed since loading. This is complete only under the
# invariant that a materializing autoload adds owned functions and parameters
# and writes runtime parameters, and never redefines a recorded function,
# rewrites a recorded non-runtime parameter, changes fpath, or loads a module;
# the lifecycle profile checks the shipped chromas against the full accounting.
_fsh_lifecycle_account_materialized() {
  builtin emulate -L zsh

  local name REPLY

  (( _fsh_lifecycle_started && _fsh_lifecycle_loaded )) || return 1

  for name in ${(k)_fsh_lifecycle_pending_autoloads}; do
    (( ${+functions[$name]} )) || continue
    [[ ${functions[$name]} == "${_fsh_lifecycle_applied_functions[$name]-}" ]] && continue
    _fsh_lifecycle_applied_function_set[$name]=1
    _fsh_lifecycle_applied_functions[$name]=${functions[$name]}
    _fsh_lifecycle_touched_functions[$name]=1
    [[ ${functions[$name]} == *'builtin autoload -X'* ]] ||
      builtin unset "_fsh_lifecycle_pending_autoloads[$name]"
  done

  for name in ${(k)functions}; do
    _fsh_lifecycle_function_owned "$name" || continue
    # The compatibility callback is installed once, never by a lazy operation.
    [[ $name == _zsh_highlight ]] && continue
    (( ${+_fsh_lifecycle_applied_function_set[$name]} ||
      ${+_fsh_lifecycle_original_function_set[$name]} )) && continue
    _fsh_lifecycle_applied_function_set[$name]=1
    _fsh_lifecycle_applied_functions[$name]=${functions[$name]}
    _fsh_lifecycle_touched_functions[$name]=1
    [[ ${functions[$name]} == *'builtin autoload -X'* ]] &&
      _fsh_lifecycle_pending_autoloads[$name]=1
  done

  # Most parameters are the caller's; test ownership only for the namespace.
  for name in ${(M)${(k)parameters}:#_fsh_*}; do
    _fsh_lifecycle_parameter_owned "$name" || continue
    (( ${+_fsh_lifecycle_applied_parameter_set[$name]} ||
      ${+_fsh_lifecycle_original_parameter_set[$name]} )) && continue
    _fsh_lifecycle_parameter_declaration "$name"
    _fsh_lifecycle_applied_parameter_set[$name]=1
    _fsh_lifecycle_applied_parameters[$name]=$REPLY
    _fsh_lifecycle_touched_parameters[$name]=1
  done
}

_fsh_lifecycle_refresh() {
  builtin emulate -L zsh

  local name
  local -A touched_parameters

  (( ${+parameters[_fsh_lifecycle_started]} && _fsh_lifecycle_started )) || return 0
  (( _fsh_lifecycle_refresh_pending )) || {
    _fsh_lifecycle_finalize
    return
  }

  # A materialized autoload may add more plugin-owned shell resources, and
  # highlighting owns the final values of the parameters it introduces.
  touched_parameters=( "${(@kv)_fsh_lifecycle_touched_parameters}" )
  _fsh_lifecycle_account_materialized || return
  for name in ${(k)_fsh_lifecycle_touched_parameters}; do
    (( ${+touched_parameters[$name]} )) ||
      _fsh_lifecycle_runtime_parameters[$name]=1
  done
  _fsh_lifecycle_refresh_pending=0
}

_fsh_lifecycle_checkpoint() {
  builtin emulate -L zsh

  local name

  (( ${+parameters[_fsh_lifecycle_started]} && _fsh_lifecycle_started )) || return 0
  (( _fsh_lifecycle_refresh_pending )) && return 0

  for name in ${(k)_fsh_lifecycle_pending_autoloads}; do
    [[ ${functions[$name]-} == "${_fsh_lifecycle_applied_functions[$name]-}" ]] || {
      _fsh_lifecycle_refresh_pending=1
      # The refresh forks once per owned parameter and regenerates every owned
      # function, which is too slow for a keystroke. When the preexec hook is
      # installed it runs there, before the caller's next command can change
      # plugin state. Without the hook, only unload would run it, and any
      # caller change made before then would be mistaken for the plugin's own,
      # so account for the materialized autoload now.
      (( ${preexec_functions[(Ie)_fsh_preexec_hook]:-0} )) ||
        _fsh_lifecycle_refresh
      return 0
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

_fsh_lifecycle_detach_redraw_hooks() {
  builtin emulate -L zsh
  builtin setopt extended_glob

  local entry descriptor original
  local -a hooks retained
  integer original_set

  (( ${+parameters[widgets]} )) || return 0
  [[ ${widgets[zle-line-pre-redraw]-} == user:azhw:zle-line-pre-redraw ]] || return 0
  zstyle -a zle-line-pre-redraw widgets hooks || return 0

  for entry in "${hooks[@]}"; do
    descriptor=${entry#*:}
    if [[ $descriptor != _fsh_widget_redraw ]]; then
      retained+=( "$entry" )
    fi
  done
  (( $#retained != $#hooks )) || return 0

  original_set=${+_fsh_lifecycle_original_widget_set[zle-line-pre-redraw]}
  original=${_fsh_lifecycle_original_widgets[zle-line-pre-redraw]-}
  if (( ! $#retained )); then
    zstyle -d zle-line-pre-redraw widgets
    _fsh_lifecycle_restore_widget zle-line-pre-redraw "$original" "$original_set"
  elif (( $#retained == 1 && original_set )) &&
      [[ ${retained[1]#*:} == "$original" && $original != builtin ]]; then
    # add-zle-hook-widget saved the original widget under its descriptor. If no
    # other hook remains, collapse the dispatcher back to the captured widget.
    zstyle -d zle-line-pre-redraw widgets
    zle -D "$original" 2>/dev/null || true
    _fsh_lifecycle_restore_widget zle-line-pre-redraw "$original" 1
  else
    # Hooks added by another plugin must keep the shared dispatcher. Preserve
    # only the helper alias add-zle-hook-widget created for the original hook;
    # ordinary callbacks captured before load still need their F-Sy-H wrappers
    # restored below.
    zstyle zle-line-pre-redraw widgets "${retained[@]}"
    builtin unset '_fsh_lifecycle_touched_widgets[zle-line-pre-redraw]'
    for entry in "${retained[@]}"; do
      descriptor=${entry#*:}
      if (( original_set )) && [[ $descriptor == "$original" ]]; then
        builtin unset "_fsh_lifecycle_touched_widgets[$descriptor]"
      fi
    done
  fi
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
        [[ $name == _fsh_orig-* ]] && continue
      else
        [[ $name == _fsh_orig-* ]] || continue
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

_fsh_lifecycle_restore_zle_hook_state() {
  builtin emulate -L zsh

  local name
  local -a hook_widgets=(
    zle-isearch-exit
    zle-isearch-update
    zle-line-pre-redraw
    zle-line-init
    zle-line-finish
    zle-history-line-set
    zle-keymap-select
  )
  integer dispatcher_active=0

  if (( ${+parameters[widgets]} )); then
    for name in "${hook_widgets[@]}"; do
      [[ ${widgets[$name]-} == user:azhw:$name ]] || continue
      dispatcher_active=1
      break
    done
  fi

  if (( dispatcher_active )); then
    # Another plugin still uses the shared dispatcher. Its implementation and
    # registry must outlive F-Sy-H even if this load materialized them first.
    for name in ${(k)_fsh_lifecycle_touched_functions}; do
      [[ $name == add-zle-hook-widget || $name == azhw:* ]] || continue
      builtin unset "_fsh_lifecycle_touched_functions[$name]"
    done
    _fsh_lifecycle_owned_modules=(
      ${_fsh_lifecycle_owned_modules:#(zsh/complete|zsh/parameter|zsh/zle|zsh/zleparameter|zsh/zutil)}
    )
  elif (( _fsh_lifecycle_original_zle_hook_types_set )); then
    zstyle zle-hook types "${_fsh_lifecycle_original_zle_hook_types[@]}"
  else
    zstyle -d zle-hook types
  fi
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
    elif [[ $name == _zsh_highlight ]] &&
        (( ${+functions[_history-substring-search-end]} )); then
      # A later-loaded history-substring-search skipped installing its fallback
      # because our callback existed. Hand it a standalone fallback on unload.
      # Earlier owners and newer replacements are handled above, unchanged.
      _zsh_highlight() {
        builtin emulate -L zsh
        if [[ $KEYS == [[:print:]] ]]; then
          region_highlight=()
        fi
        return 0
      }
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

  local entry
  integer count index candidate

  if _fsh_lifecycle_arrays_equal fpath _fsh_lifecycle_applied_fpath; then
    fpath=( "${_fsh_lifecycle_original_fpath[@]}" )
    return 0
  fi

  for entry in "${_fsh_lifecycle_added_fpath[@]}"; do
    count=0
    index=0
    for (( candidate = 1; candidate <= $#fpath; ++candidate )); do
      [[ ${fpath[candidate]} == "$entry" ]] || continue
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
    # Account for autoloads that materialized since the last command line.
    (( _fsh_lifecycle_refresh_pending )) && _fsh_lifecycle_refresh
    _fsh_lifecycle_cleanup_fds
    if (( ${+functions[add-zsh-hook]} )); then
      add-zsh-hook -d preexec _fsh_preexec_hook 2>/dev/null || true
    fi

    _fsh_lifecycle_detach_redraw_hooks
    _fsh_lifecycle_restore_widgets
    _fsh_lifecycle_restore_zle_hook_state
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
    _fsh_lifecycle_account_materialized
    _fsh_lifecycle_refresh
    _fsh_lifecycle_checkpoint
    _fsh_lifecycle_restore_widget
    _fsh_lifecycle_detach_redraw_hooks
    _fsh_lifecycle_restore_widgets
    _fsh_lifecycle_restore_zle_hook_state
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
  builtin unset _fsh_lifecycle_original_zle_hook_types
  builtin unset _fsh_lifecycle_original_zle_hook_types_set
  builtin unset _fsh_lifecycle_widgets_captured
  builtin unset _fsh_lifecycle_refresh_pending
  builtin unset _fsh_lifecycle_started
  builtin unset _fsh_lifecycle_loaded

  for helper in "${helpers[@]}"; do
    builtin unfunction "$helper" 2>/dev/null || true
  done
  builtin unfunction fsh_plugin_unload
}
