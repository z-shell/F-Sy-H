#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-validator.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset output
output=$(zsh -f "$plugin_root/tools/validate-themes.zsh")
(( ${#${(f)output}} == 12 ))
[[ $output != *'"status":"error"'* ]]
[[ $output == *'"schema":"fsh-theme-validation/v1"'* ]]
[[ $output == *'"declaredStyles":61,"resolvedStyles":60'* ]]

command sed \
  -e 's/^command        = 4$/command        = 999/' \
  -e 's/^builtin        = 4$/builtin        = 0300/' \
  "$plugin_root/themes/base16.ini" >| "$fixture_root/invalid-values.ini"

if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/invalid-values.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: invalid theme values unexpectedly passed validation'
  exit 1
fi
[[ $output == *'"status":"error","code":"invalid-style-value"'* ]]
[[ $output == *'command has invalid color or style element: 999'* ]]
[[ $output == *'builtin has invalid color or style element: 0300'* ]]

{
  builtin print -r -- '[base]'
  builtin print -r -- 'default=none'
  builtin print -r -- 'default=green'
} >| "$fixture_root/duplicate.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/duplicate.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: duplicate theme key unexpectedly passed validation'
  exit 1
fi
[[ $output == *'"status":"error","code":"duplicate-key"'* ]]

{
  builtin print -r -- '[base]'
  builtin print -r -- 'comment=123'
} >| "$fixture_root/sample-overlay.ini"
output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/sample-overlay.ini")
[[ $output == *'"status":"ok"'*'"declaredStyles":1,"resolvedStyles":0'* ]]

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
command mkdir -p -- "$ZDOTDIR"
zstyle ':fsh:config' work-dir "$fixture_root/work"
source "$plugin_root/F-Sy-H.plugin.zsh"
fsh_theme --quiet "$fixture_root/sample-overlay.ini"
[[ -s $fixture_root/work/theme_overlay.ini ]]
if fsh_theme --quiet "$fixture_root/invalid-values.ini" 2>"$fixture_root/theme-error"; then
  builtin print -u2 -r -- 'f-sy-h: invalid theme unexpectedly loaded'
  exit 1
fi
[[ $(<"$fixture_root/theme-error") == *'invalid-style-value'* ]]
[[ ! -e $fixture_root/work/current_theme.ini ]]
fsh_plugin_unload
