#!/usr/bin/env zsh

emulate -R zsh
setopt no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h}
fpath=( "$plugin_root/functions" $fpath )
source "$plugin_root/lib/theme-schema.zsh"
autoload -Uz _fsh_read_ini _fsh_validate_theme

json_escape() {
  emulate -L zsh

  REPLY=${1//\\/\\\\}
  REPLY=${REPLY//\"/\\\"}
  REPLY=${REPLY//$'\n'/\\n}
  REPLY=${REPLY//$'\r'/\\r}
  REPLY=${REPLY//$'\t'/\\t}
}

typeset -a theme_paths=( "$@" )
(( $#theme_paths )) || theme_paths=( "$plugin_root"/themes/*.ini(N) )

typeset theme_path path_json diagnostic code message code_json message_json
integer exit_status=0
for theme_path in "${theme_paths[@]}"; do
  json_escape "${theme_path:A}"
  path_json=$REPLY
  if _fsh_validate_theme "$theme_path" "$plugin_root/themes"; then
    builtin printf \
      '{"schema":"fsh-theme-validation/v1","path":"%s","status":"ok","code":"ok","message":"","declaredStyles":%d,"resolvedStyles":%d}\n' \
      "$path_json" $_fsh_theme_declared_count $_fsh_theme_resolved_count
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
      '{"schema":"fsh-theme-validation/v1","path":"%s","status":"error","code":"%s","message":"%s","declaredStyles":%d,"resolvedStyles":%d}\n' \
      "$path_json" "$code_json" "$message_json" \
      $_fsh_theme_declared_count $_fsh_theme_resolved_count
  done
done

exit exit_status
