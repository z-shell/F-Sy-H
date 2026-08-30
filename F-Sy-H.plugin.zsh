# Copyright (c) 2010-2016 zsh-syntax-highlighting contributors
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice, this list of conditions
#    and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice, this list of
#    conditions and the following disclaimer in the documentation and/or other materials provided
#    with the distribution.
#  * Neither the name of the zsh-syntax-highlighting contributors nor the names of its contributors
#    may be used to endorse or promote products derived from this software without specific prior
#    written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

() {
builtin emulate -L zsh
builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

local -r source_path=${1:a}
local -r plugin_dir=${source_path:h}
local load_status configured_value configured_pattern
local -a lifecycle_collisions lifecycle_modules configured_patterns

lifecycle_modules=( ${(f)"$(zmodload)"} )

(( ${+_fsh_lifecycle_loaded} && _fsh_lifecycle_loaded )) && return 0

lifecycle_collisions=(
  ${(M)${(k)functions}:#(_fsh_lifecycle_*|fsh_plugin_unload)}
)
(( ${+_fsh_lifecycle_started} )) && lifecycle_collisions+=( _fsh_lifecycle_started )
(( ${+_fsh_lifecycle_loaded} )) && lifecycle_collisions+=( _fsh_lifecycle_loaded )
if (( $#lifecycle_collisions )); then
  builtin print -u2 -r -- \
    "f-sy-h: lifecycle state already exists: ${(j:, :)lifecycle_collisions}"
  return 2
fi

if (( ${+ZSH_HIGHLIGHT_STYLES} || ${+ZSH_HIGHLIGHT_HIGHLIGHTERS} )); then
  builtin print -u2 -r -- \
    'f-sy-h: detected unsupported zsh-syntax-highlighting configuration; see README.md: Migrating from zsh-syntax-highlighting'
fi

builtin source -- "$plugin_dir/lib/lifecycle.zsh" || return
_fsh_lifecycle_begin "${lifecycle_modules[@]}" || return
builtin source -- "$plugin_dir/lib/theme-schema.zsh" || {
  load_status=$?
  _fsh_lifecycle_abort "$load_status"
  return $?
}

#
# Resolve the entrypoint without assigning to special parameter 0. Plugin
# managers may provide ZERO as the entrypoint path.
typeset -g _fsh_base_dir=$plugin_dir

# Portable autoload paths. Managers may add the same paths first; exact checks
# keep direct and managed loading idempotent.
(( ${fpath[(Ie)$_fsh_base_dir/functions]} )) || fpath+=( "$_fsh_base_dir/functions" )
(( ${fpath[(Ie)$_fsh_base_dir/completions]} )) || fpath+=( "$_fsh_base_dir/completions" )
(( ${fpath[(Ie)$_fsh_base_dir/chroma]} )) || fpath+=( "$_fsh_base_dir/chroma" )

# Default global variables
typeset -g _fsh_version=1.67.1
typeset -ga _fsh_main_cache

# Holds list of indices pointing at brackets that are complex, i.e. e.g. part of "[[" in [[ ... ]]
typeset -ga _fsh_complex_brackets

# Resolve public configuration through the single :fsh:config zstyle context.
if zstyle -s ':fsh:config' work-dir configured_value; then
  typeset -g _fsh_work_dir=$configured_value
else
  typeset -g _fsh_work_dir=${XDG_CACHE_HOME:-~/.cache}/f-sy-h
fi
_fsh_work_dir=${~_fsh_work_dir}

configured_value=1000
zstyle -s ':fsh:config' max-length configured_value || configured_value=1000
[[ $configured_value == <-> ]] || {
  builtin print -u2 -r -- 'f-sy-h: :fsh:config max-length must be a non-negative integer'
  _fsh_lifecycle_abort 2
  return $?
}
typeset -gi _fsh_max_length=$configured_value

configured_value=5
zstyle -s ':fsh:config' chroma-cache-seconds configured_value || configured_value=5
[[ $configured_value == <-> ]] || {
  builtin print -u2 -r -- 'f-sy-h: :fsh:config chroma-cache-seconds must be a non-negative integer'
  _fsh_lifecycle_abort 2
  return $?
}
typeset -gi _fsh_chroma_cache_seconds=$configured_value

configured_value=2
zstyle -s ':fsh:config' chroma-timeout-seconds configured_value || configured_value=2
[[ $configured_value == <-> && $configured_value -gt 0 ]] || {
  builtin print -u2 -r -- 'f-sy-h: :fsh:config chroma-timeout-seconds must be a positive integer'
  _fsh_lifecycle_abort 2
  return $?
}
typeset -gi _fsh_chroma_timeout_seconds=$configured_value

# Invokes each highlighter that needs updating.
# This function is supposed to be called whenever the ZLE state changes.
_fsh_zle_highlight() {
  # Store the previous command return code to restore it whatever happens.
  local ret=$?
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd localtraps

  # Remove all highlighting in isearch, so that only the underlining done by zsh itself remains.
  # For details see FAQ entry 'Why does syntax highlighting not work while searching history?'.
  if [[ $WIDGET == zle-isearch-update ]] && ! (( $+ISEARCHMATCH_ACTIVE )); then
    _fsh_incremental_reset
    region_highlight=()
    return $ret
  fi

  local REPLY # don't leak $REPLY into global scope
  local -a reply

  # Skip highlighting above the configured buffer-length limit. Long buffers
  # are commonly pasted commands or generated lists.
  if [[ -n ${_fsh_max_length:-} ]] && [[ $#BUFFER -gt $_fsh_max_length ]]; then
    _fsh_incremental_reset
    return $ret
  fi

  # Do not highlight if there are pending inputs (copy/paste).
  if [[ $PENDING -gt 0 ]]; then
    _fsh_incremental_reset
    return $ret
  fi

  # Reset region highlight to build it from scratch
  # may need to remove path_prefix highlighting when the line ends
  if [[ $WIDGET == zle-line-finish ]] || _fsh_buffer_modified; then
    _fsh_highlight_buffer "$PREBUFFER" "$BUFFER"
    (( _fsh_state[use_brackets] )) && {
      _fsh_main_cache=( $reply )
      _fsh_highlight_string_process "$PREBUFFER" "$BUFFER"
    }
    region_highlight=( $reply )
  else
    local char="${BUFFER[CURSOR+1]}"
    if [[ "$char" = ["{([])}"] || "${_fsh_state[prev_char]}" = ["{([])}"] ]]; then
      _fsh_state[prev_char]="$char"
      (( _fsh_state[use_brackets] )) && {
        reply=( $_fsh_main_cache )
        _fsh_highlight_string_process "$PREBUFFER" "$BUFFER"
        region_highlight=( $reply )
      }
    fi
  fi

  {
    local cache_place
    local -a region_highlight_copy

    # Re-apply zle_highlight settings

    # region
    if (( REGION_ACTIVE == 1 )); then
      _fsh_apply_zle_highlight region standout "$MARK" "$CURSOR"
    elif (( REGION_ACTIVE == 2 )); then
      () {
        local needle=$'\n'
        integer min max
        if (( MARK > CURSOR )) ; then
          min=$CURSOR max=$(( MARK + 1 ))
        else
          min=$MARK max=$CURSOR
        fi
        (( min = ${${BUFFER[1,$min]}[(I)$needle]} ))
        (( max += ${${BUFFER:($max-1)}[(i)$needle]} - 1 ))
        _fsh_apply_zle_highlight region standout "$min" "$max"
      }
    fi

    # yank / paste (zsh-5.1.1 and newer)
    (( $+YANK_ACTIVE )) && (( YANK_ACTIVE )) && \
    _fsh_apply_zle_highlight paste standout "$YANK_START" "$YANK_END"

    # isearch
    (( $+ISEARCHMATCH_ACTIVE )) && (( ISEARCHMATCH_ACTIVE )) && \
    _fsh_apply_zle_highlight isearch underline "$ISEARCHMATCH_START" "$ISEARCHMATCH_END"

    # suffix
    (( $+SUFFIX_ACTIVE )) && (( SUFFIX_ACTIVE )) && \
    _fsh_apply_zle_highlight suffix bold "$SUFFIX_START" "$SUFFIX_END"

    return $ret

  } always {
    typeset -g _fsh_prior_buffer="$BUFFER"
    typeset -g _fsh_prior_region_active="$REGION_ACTIVE"
    typeset -gi _fsh_prior_cursor=$CURSOR
  }
}

# Apply highlighting based on entries in the zle_highlight array.
# This function takes four arguments:
# 1. The exact entry (no patterns) in the zle_highlight array:
#    region, paste, isearch, or suffix
# 2. The default highlighting that should be applied if the entry is unset
# 3. and 4. Two integer values describing the beginning and end of the
#    range. The order does not matter.
_fsh_apply_zle_highlight() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

  local entry="$1" default="$2"
  integer first="$3" second="$4"

  # read the relevant entry from zle_highlight
  local region="${zle_highlight[(r)${entry}:*]}"

  if [[ -z "$region" ]]; then
    # entry not specified at all, use default value
    region=$default
  else
    # strip prefix
    region="${region#${entry}:}"

    # no highlighting when set to the empty string or to 'none'
    if [[ -z "$region" ]] || [[ "$region" == none ]]; then
      return
    fi
  fi

  integer start end
  if (( first < second )); then
    start=$first end=$second
  else
    start=$second end=$first
  fi
  region_highlight+=("$start $end $region")
}


# -------------------------------------------------------------------------------------------------
# API/utility functions for highlighters
# -------------------------------------------------------------------------------------------------

# Whether the command line buffer has been modified or not.
#
# Returns 0 if the buffer has changed since _fsh_zle_highlight was last called.
_fsh_buffer_modified() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

  [[ "${_fsh_prior_buffer:-}" != "$BUFFER" ]] || \
  [[ "$REGION_ACTIVE" != "$_fsh_prior_region_active" ]] || \
  { _fsh_cursor_moved && [[ "$REGION_ACTIVE" = 1 || "$REGION_ACTIVE" = 2 ]] }
}

# Whether the cursor has moved or not.
#
# Returns 0 if the cursor has moved since _fsh_zle_highlight was last called.
_fsh_cursor_moved() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

  [[ -n $CURSOR ]] && [[ -n ${_fsh_prior_cursor-} ]] && (($_fsh_prior_cursor != $CURSOR))
}

# -------------------------------------------------------------------------------------------------
# Setup functions
# -------------------------------------------------------------------------------------------------

# Helper for _fsh_bind_widgets
# $1 is name of widget to call
_fsh_call_widget() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

  integer ret
  builtin zle "$@"
  ret=$?
  _fsh_zle_highlight
  return $ret
}

# Rebind all ZLE widgets to invoke the F-Sy-H highlighter.
_fsh_bind_widgets() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd no_ksh_arrays

  local -F2 SECONDS
  local prefix=fsh-orig-s${SECONDS/./}-r$(( RANDOM % 1000 )) # unique for each load

  # Override ZLE widgets to make them invoke _fsh_zle_highlight.
  local -U widgets_to_bind
  widgets_to_bind=(${${(k)widgets}:#(.*|run-help|which-command|beep|set-local-history|yank|zle-line-pre-redraw|zle-keymap-select)})

  # Always wrap special zle-line-finish widget. This is needed to decide if the
  # current line ends and special highlighting logic needs to be applied.
  # E.g. remove cursor imprint, don't highlight partial paths, ...
  widgets_to_bind+=(zle-line-finish)

  # Always wrap special zle-isearch-update widget to be notified of updates in isearch.
  # This is needed because we need to disable highlighting in that case.
  widgets_to_bind+=(zle-isearch-update)

  local cur_widget
  for cur_widget in $widgets_to_bind; do
    case $widgets[$cur_widget] in

    # Already rebound event: do nothing.
    user:_fsh_widget_*);;

    # The "eval"'s are required to make $cur_widget a closure: the value of the parameter at function
    # definition time is used.
    #
    # We can't use ${0/_fsh_widget_} because these widgets are always invoked with
    # NO_function_argzero, regardless of the option's setting here.

    # User defined widget: override and rebind the old one with a private prefix.
    user:*) zle -N -- $prefix-$cur_widget ${widgets[$cur_widget]#*:}
      eval "_fsh_widget_${(q)prefix}-${(q)cur_widget}() { _fsh_call_widget ${(q)prefix}-${(q)cur_widget} -- \"\$@\" }"
      zle -N -- $cur_widget _fsh_widget_$prefix-$cur_widget;;

    # Completion widget: override and rebind old one with private prefix.
    completion:*) zle -C $prefix-$cur_widget ${${(s.:.)widgets[$cur_widget]}[2,3]}
      eval "_fsh_widget_${(q)prefix}-${(q)cur_widget}() { _fsh_call_widget ${(q)prefix}-${(q)cur_widget} -- \"\$@\" }"
      zle -N -- $cur_widget _fsh_widget_$prefix-$cur_widget;;

    # Builtin widget: override and make it call the builtin ".widget".
    builtin) eval "_fsh_widget_${(q)prefix}-${(q)cur_widget}() { _fsh_call_widget .${(q)cur_widget} -- \"\$@\" }"
      zle -N -- $cur_widget _fsh_widget_$prefix-$cur_widget;;

    # Incomplete or nonexistent widget: Bind to z-sy-h directly.
    *)
      if [[ $cur_widget == zle-* ]] && [[ -z $widgets[$cur_widget] ]]; then
        _fsh_widget_${cur_widget}() { :; _fsh_zle_highlight }
        zle -N -- $cur_widget _fsh_widget_$cur_widget
      else
        # Default: unhandled case.
        builtin print -r -- >&2 "zsh-syntax-highlighting: unhandled ZLE widget ${(qq)cur_widget}"
      fi
    esac
  done
}

# -------------------------------------------------------------------------------------------------
# Setup
# -------------------------------------------------------------------------------------------------

# Reset scratch variables when command line is done.
_fsh_preexec_hook() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

  typeset -g _fsh_prior_buffer=
  typeset -gi _fsh_prior_cursor=0
  typeset -ga _fsh_main_cache
  _fsh_main_cache=()
  _fsh_incremental_reset
}

if [[ -o interactive ]]; then
  zmodload zsh/zleparameter 2>/dev/null || {
    builtin print -u2 -r -- 'f-sy-h: failed loading zsh/zleparameter'
    _fsh_lifecycle_abort 1
    return $?
  }
  _fsh_lifecycle_capture_widgets || {
    builtin print -u2 -r -- 'f-sy-h: failed capturing ZLE widget state'
    _fsh_lifecycle_abort 1
    return $?
  }
  zle -N _fsh_async_command_callback
  _fsh_bind_widgets || {
    builtin print -u2 -r -- 'f-sy-h: failed binding ZLE widgets'
    _fsh_lifecycle_abort 1
    return $?
  }

  builtin autoload -Uz add-zsh-hook
  add-zsh-hook preexec _fsh_preexec_hook 2>/dev/null || {
    builtin print -u2 -r -- 'f-sy-h: failed registering the preexec hook'
    _fsh_lifecycle_abort 1
    return $?
  }
fi

# Load zsh/parameter module if available
zmodload zsh/parameter 2>/dev/null
zmodload zsh/system 2>/dev/null

builtin autoload -Uz -- is-at-least \
  _fsh_read_ini _fsh_validate_theme _fsh_run_git_command \
  _fsh_make_targets _fsh_run_command _fsh_read_all \
  _fsh_async_command _fsh_async_command_callback

builtin autoload -Uz -- \
  _fsh_chroma_alias \
  _fsh_chroma_autoload \
  _fsh_chroma_autorandr \
  _fsh_chroma_awk \
  _fsh_chroma_docker \
  _fsh_chroma_fpath_assignment \
  _fsh_chroma_git \
  _fsh_chroma_grep \
  _fsh_chroma_hub \
  _fsh_chroma_ionice \
  _fsh_chroma_lab \
  _fsh_chroma_make \
  _fsh_chroma_nice \
  _fsh_chroma_nmcli \
  _fsh_chroma_node \
  _fsh_chroma_perl \
  _fsh_chroma_precommand \
  _fsh_chroma_printf \
  _fsh_chroma_ruby \
  _fsh_chroma_scp \
  _fsh_chroma_shell \
  _fsh_chroma_source \
  _fsh_chroma_ssh \
  _fsh_chroma_subcommand \
  _fsh_chroma_subversion \
  _fsh_chroma_zi \
  _fsh_chroma_main

# Kept in sync with the platform guard in lib/highlight.zsh: macOS `whatis`
# cannot serve this chroma, so it is neither autoloaded nor registered there.
[[ $OSTYPE == darwin* ]] || builtin autoload -Uz -- _fsh_chroma_whatis

configured_patterns=()
if zstyle -a ':fsh:config' chroma-opt-in configured_patterns; then
  for configured_pattern in "${configured_patterns[@]}"; do
    case $configured_pattern in
      vim|which)
        builtin autoload -Uz -- "_fsh_chroma_$configured_pattern"
        ;;
      *)
        builtin print -u2 -r -- \
          "f-sy-h: unsupported :fsh:config chroma-opt-in value: $configured_pattern"
        _fsh_lifecycle_abort 2
        return $?
        ;;
    esac
  done
fi

configured_value=enabled
zstyle -s ':fsh:config' theme-manager configured_value || configured_value=enabled
if [[ $configured_value == (disabled|false|no|off|0) ]]; then
  unset '_comps[fsh_theme]' 2>/dev/null
  unset -f _fsh_chroma_theme 2>/dev/null
else
  builtin autoload -Uz -- fsh_theme _fsh_chroma_theme _fsh_chroma_example
fi

builtin source -- "$_fsh_base_dir/lib/highlight.zsh" || {
  load_status=$?
  _fsh_lifecycle_abort "$load_status"
  return $?
}
builtin source -- "$_fsh_base_dir/lib/string-highlight.zsh" || {
  load_status=$?
  _fsh_lifecycle_abort "$load_status"
  return $?
}

for configured_pattern in "${configured_patterns[@]}"; do
  _fsh_state[chroma-$configured_pattern]="_fsh_chroma_$configured_pattern"
done

configured_value=enabled
zstyle -s ':fsh:config' bracket-highlighting configured_value || configured_value=enabled
[[ $configured_value == (disabled|false|no|off|0) ]] &&
  _fsh_state[use_brackets]=0 || _fsh_state[use_brackets]=1

if zstyle -a ':fsh:config' path-blocklist configured_patterns; then
  _fsh_blocklist_patterns=()
  for configured_pattern in "${configured_patterns[@]}"; do
    _fsh_blocklist_patterns[$configured_pattern]=1
  done
fi

[[ ( "${+termcap}" != 1 || "${termcap[Co]}" != <-> || "${termcap[Co]}" -lt "256" ) && "${_fsh_theme_name:-default}" = default ]] && {
  _fsh_styles[defaultvariable]="none"
  _fsh_styles[defaultglobbing-ext]="fg=blue,bold"
  _fsh_styles[defaulthere-string-text]="bg=blue"
  _fsh_styles[defaulthere-string-var]="fg=cyan,bg=blue"
  _fsh_styles[defaultcorrect-subtle]="bg=blue"
  _fsh_styles[defaultsubtle-bg]="bg=blue"
  [[ "${_fsh_styles[variable]}" = "fg=113" ]] && _fsh_styles[variable]="none"
  [[ "${_fsh_styles[globbing-ext]}" = "fg=13" ]] && _fsh_styles[globbing-ext]="fg=blue,bold"
  [[ "${_fsh_styles[here-string-text]}" = "bg=18" ]] && _fsh_styles[here-string-text]="bg=blue"
  [[ "${_fsh_styles[here-string-var]}" = "fg=cyan,bg=18" ]] && _fsh_styles[here-string-var]="fg=cyan,bg=blue"
  [[ "${_fsh_styles[correct-subtle]}" = "fg=12" ]] && _fsh_styles[correct-subtle]="bg=blue"
  [[ "${_fsh_styles[subtle-bg]}" = "bg=18" ]] && _fsh_styles[subtle-bg]="bg=blue"
}

_fsh_highlight_fill_option_variables

[[ $COLORTERM == (24bit|truecolor) || ${terminfo[colors]} -eq 16777216 ]] || zmodload zsh/nearcolor &>/dev/null || true

_fsh_lifecycle_finalize || {
  load_status=$?
  _fsh_lifecycle_abort "$load_status"
  return $?
}
} "${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
