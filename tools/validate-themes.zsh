#!/usr/bin/env zsh

emulate -R zsh
setopt no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h}
fpath=( "$plugin_root/functions" $fpath )
source "$plugin_root/lib/theme-schema.zsh"
autoload -Uz _fsh_read_ini _fsh_theme_color_rgb _fsh_theme_color_cvd_lab \
  _fsh_theme_resolve_rendering _fsh_validate_theme_contrast \
  _fsh_validate_theme_cvd_separation _fsh_validate_theme_distinguishability \
  _fsh_validate_theme

json_escape() {
  emulate -L zsh

  REPLY=${1//\\/\\\\}
  REPLY=${REPLY//\"/\\\"}
  REPLY=${REPLY//$'\n'/\\n}
  REPLY=${REPLY//$'\r'/\\r}
  REPLY=${REPLY//$'\t'/\\t}
}

nearcolor_256_json() {
  emulate -L zsh
  setopt extended_glob

  local full_key declared_key value token color mapping
  local -A colors
  local -a sorted_colors

  for full_key in ${(k)_fsh_validated_theme_data}; do
    [[ $full_key == '<theme>_'* ]] && continue
    declared_key=${full_key#*>_}
    [[ $declared_key == secondary ]] && continue
    value=${_fsh_validated_theme_data[$full_key]}
    for token in ${(s:,:)value}; do
      [[ $token == bg:* ]] && token=${token#bg:}
      [[ $token == \#[0-9a-fA-F](#c6,6) ]] || continue
      color=${(L)token}
      colors[$color]=1
    done
  done

  sorted_colors=( ${(ok)colors} )
  if (( ! $#sorted_colors )); then
    REPLY='{}'
    return 0
  fi

  mapping=$(TERM=xterm-256color COLORTERM= command zsh -f -c '
    emulate -R zsh
    zmodload zsh/nearcolor || exit 2

    local color rendered index
    local -a pairs
    for color in "$@"; do
      rendered=${(%)${:-"%F{$color}"}}
      [[ $rendered == $'\''\e[38;5;'\''<->m ]] || exit 3
      index=${rendered#$'\''\e[38;5;'\''}
      index=${index%m}
      pairs+=( "\"$color\":$index" )
    done
    print -rn -- "{${(j:,:)pairs}}"
  ' zsh "${sorted_colors[@]}" 2>/dev/null) || return 1

  REPLY=$mapping
}

typeset -a theme_paths=( "$@" )
(( $#theme_paths )) || theme_paths=( "$plugin_root"/themes/*.ini(N) )

typeset theme_path path_json diagnostic code message code_json message_json validation_mode nearcolor_json
integer exit_status=0
for theme_path in "${theme_paths[@]}"; do
  json_escape "${theme_path:A}"
  path_json=$REPLY
  validation_mode=
  [[ ${theme_path:A:h} == ${plugin_root:A}/themes ]] && validation_mode=shipped
  _fsh_validate_theme "$theme_path" "$plugin_root/themes" "$validation_mode"
  if nearcolor_256_json; then
    nearcolor_json=$REPLY
  else
    nearcolor_json='{}'
    _fsh_theme_validation_errors+=(
      'nearcolor-unavailable|zsh/nearcolor could not calculate 256-color mappings' )
  fi
  if (( ! $#_fsh_theme_validation_errors )); then
    builtin printf \
      '{"schema":"fsh-theme-validation/v1","path":"%s","status":"ok","code":"ok","message":"","declaredStyles":%d,"resolvedStyles":%d,"nearcolor256":%s}\n' \
      "$path_json" $_fsh_theme_declared_count $_fsh_theme_resolved_count "$nearcolor_json"
    continue
  fi

  exit_status=1
  for diagnostic in "${_fsh_theme_validation_errors[@]}"; do
    code=${diagnostic%%|*}
    message=${diagnostic#*|}
    json_escape "$code"
    code_json=$REPLY
    json_escape "$message"
    message_json=$REPLY
    builtin printf \
      '{"schema":"fsh-theme-validation/v1","path":"%s","status":"error","code":"%s","message":"%s","declaredStyles":%d,"resolvedStyles":%d,"nearcolor256":%s}\n' \
      "$path_json" "$code_json" "$message_json" \
      $_fsh_theme_declared_count $_fsh_theme_resolved_count "$nearcolor_json"
  done
done

exit exit_status
