#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-validator.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset output
output=$(zsh -f "$plugin_root/tools/validate-themes.zsh")
(( ${#${(f)output}} == 13 ))
[[ $output != *'"status":"error"'* ]]
[[ $output == *'"schema":"fsh-theme-validation/v1"'* ]]
[[ $output == *'"declaredStyles":61,"resolvedStyles":60'* ]]
[[ $output == *'"nearcolor256":{"#0550ae":25,"#116329":22,"#57606a":59,"#6639ba":98,"#7d4e00":94,"#82071e":52,"#dafbe1":194,"#ddf4ff":195,"#f6f8fa":231,"#fff8c5":230,"#ffffff":231}'* ]]

command sed 's/^double-hyphen-option   = 143$/double-hyphen-option   = 104/' \
  "$plugin_root/themes/q-jmnemonic.ini" >| "$fixture_root/semantic-collision.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/semantic-collision.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: identical semantic styles unexpectedly passed validation'
  exit 1
fi
[[ $output == *'"code":"indistinguishable-styles"'* ]]
[[ $output == *'single-hyphen-option and double-hyphen-option resolve to the same rendering'* ]]

command sed 's/^correct-subtle   = bg:55$/correct-subtle   = bg:0/' \
  "$plugin_root/themes/clean.ini" >| "$fixture_root/cvd-separation-failure.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/cvd-separation-failure.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: CVD-confusable correctness styles unexpectedly passed validation'
  exit 1
fi
[[ $output == *'"code":"cvd-separation-too-low"'* ]]
[[ $output == *'protanopia separation '*' is below 20.0'* ]]

command sed 's/^double-hyphen-option   = cyan,bold$/double-hyphen-option   = 6/' \
  "$plugin_root/themes/default.ini" >| "$fixture_root/canonical-color-collision.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/canonical-color-collision.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: equivalent named and indexed colours unexpectedly passed validation'
  exit 1
fi
[[ $output == *'"code":"indistinguishable-styles"'* ]]

command sed \
  -e 's/^single-hyphen-option         = 104$/single-hyphen-option         = none/' \
  -e 's/^double-hyphen-option   = 143$/double-hyphen-option   = default/' \
  "$plugin_root/themes/q-jmnemonic.ini" >| "$fixture_root/default-color-collision.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/default-color-collision.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: equivalent default renderings unexpectedly passed validation'
  exit 1
fi
[[ $output == *'"code":"indistinguishable-styles"'* ]]

command sed \
  -e 's/^single-hyphen-option         = 104$/single-hyphen-option         = black,bg:104,reverse/' \
  -e 's/^double-hyphen-option   = 143$/double-hyphen-option   = 104/' \
  "$plugin_root/themes/q-jmnemonic.ini" >| "$fixture_root/reverse-collision.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/reverse-collision.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: reverse-equivalent semantic styles unexpectedly passed validation'
  exit 1
fi
[[ $output == *'"code":"indistinguishable-styles"'* ]]

command sed 's/^double-hyphen-option   = 3,bold$/double-hyphen-option   = yellow/' \
  "$plugin_root/themes/base16.ini" >| "$fixture_root/adaptive-collision.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/adaptive-collision.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: equivalent adaptive ANSI colours unexpectedly passed validation'
  exit 1
fi
[[ $output == *'"code":"indistinguishable-styles"'* ]]

command sed \
  -e '/^\[theme\]$/,/^$/d' \
  -e 's/^double-hyphen-option   = cyan,bold$/double-hyphen-option   = 6/' \
  "$plugin_root/themes/default.ini" >| "$fixture_root/metadata-free-collision.ini"
output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/metadata-free-collision.ini")
[[ $output == *'"status":"ok"'* ]]

command sed '1,5d' "$plugin_root/themes/clean.ini" >| "$fixture_root/custom-no-metadata.ini"
output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/custom-no-metadata.ini")
[[ $output == *'"status":"ok"'* ]]

command sed '/^background = #000000$/d' "$plugin_root/themes/clean.ini" >| \
  "$fixture_root/incomplete-metadata.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/incomplete-metadata.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: incomplete theme metadata unexpectedly passed validation'
  exit 1
fi
[[ $output == *'"code":"incomplete-theme-metadata"'* ]]

command sed 's/^comment          = 243$/comment          = #000000/' \
  "$plugin_root/themes/clean.ini" >| "$fixture_root/metadata-contrast-failure.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/metadata-contrast-failure.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: metadata contrast failure unexpectedly passed validation'
  exit 1
fi
[[ $output == *'"code":"contrast-too-low"'*'comment contrast 1.00:1'* ]]

command sed 's/^comment          = 243$/comment          = #747474/' \
  "$plugin_root/themes/clean.ini" >| "$fixture_root/unrounded-boundary.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/unrounded-boundary.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: sub-4.5 contrast unexpectedly passed validation'
  exit 1
fi
[[ $output == *'comment contrast 4.49:1 is below 4.5:1'* ]]

command sed 's/^comment          = 243$/comment          = #757575/' \
  "$plugin_root/themes/clean.ini" >| "$fixture_root/ordinary-boundary-pass.ini"
output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/ordinary-boundary-pass.ini")
[[ $output == *'"status":"ok"'* ]]

command sed 's/^unknown-token    = 210,bold$/unknown-token    = #949494,bold/' \
  "$plugin_root/themes/clean.ini" >| "$fixture_root/critical-boundary-fail.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/critical-boundary-fail.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: sub-7.0 critical contrast unexpectedly passed validation'
  exit 1
fi
[[ $output == *'unknown-token contrast 6.92:1 is below 7.0:1'* ]]

command sed 's/^unknown-token    = 210,bold$/unknown-token    = #959595,bold/' \
  "$plugin_root/themes/clean.ini" >| "$fixture_root/critical-boundary-pass.ini"
output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/critical-boundary-pass.ini")
[[ $output == *'"status":"ok"'* ]]

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

command sed 's/^command        = 4$/command        = 16/' \
  "$plugin_root/themes/base16.ini" >| "$fixture_root/adaptive-out-of-range.ini"
if output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/adaptive-out-of-range.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: adaptive palette accepted xterm cube color'
  exit 1
fi
[[ $output == *'"code":"adaptive-palette-out-of-range"'* ]]

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

{
  builtin print -r -- '[theme]'
  builtin print -r -- 'palette=xterm-256'
  builtin print -r -- 'foreground=#ffffff'
  builtin print -r -- 'background=#000000'
  builtin print -r -- '[base]'
  builtin print -r -- 'comment=#000000'
  builtin print -r -- 'single-hyphen-option=104'
  builtin print -r -- 'double-hyphen-option=104'
} >| "$fixture_root/metadata-overlay.ini"
output=$(zsh -f "$plugin_root/tools/validate-themes.zsh" \
  "$fixture_root/metadata-overlay.ini")
[[ $output == *'"status":"ok"'*'"declaredStyles":3,"resolvedStyles":0'* ]]

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
typeset -gx TERM=xterm-256color
command mkdir -p -- "$ZDOTDIR"
zstyle ':fsh:config' work-dir "$fixture_root/work"
zmodload zsh/termcap
[[ ${termcap[Co]} == <-> ]] && (( termcap[Co] >= 256 ))
source "$plugin_root/F-Sy-H.plugin.zsh"

if _fsh_validate_theme "$fixture_root/custom-no-metadata.ini" \
  "$plugin_root/themes" shipped; then
  builtin print -u2 -r -- 'f-sy-h: shipped validation accepted missing metadata'
  exit 1
fi
[[ ${_fsh_theme_validation_errors[*]} == *'missing-theme-metadata'* ]]

typeset -a reply
_fsh_theme_color_rgb 196 xterm-256
[[ ${reply[*]} == '255 0 0' ]]
_fsh_theme_color_rgb '#123456' xterm-256
[[ ${reply[*]} == '18 52 86' ]]
_fsh_theme_color_cvd_lab '#5f0000' protanopia
typeset cvd_lab_text
builtin printf -v cvd_lab_text '%.2f %.2f %.2f' "${reply[1]}" "${reply[2]}" "${reply[3]}"
[[ $cvd_lab_text == '3.01 -0.43 4.51' ]]

normalize_theme_value() {
  emulate -L zsh
  local value=$1 token result= is_background

  for token in ${(s:,:)value}; do
    if [[ $token == (none|(no-|)(bold|blink|conceal|reverse|standout|underline)) ]]; then
      result+="${result:+,}$token"
      continue
    fi
    is_background=0
    if [[ $token == bg:* ]]; then
      is_background=1
      token=${token#bg:}
    fi
    result+=${result:+,}
    (( is_background )) && result+='bg=' || result+='fg='
    result+=$token
  done
  REPLY=$result
}

typeset style candidate inikey expected
typeset -a candidates
_fsh_validate_theme "$plugin_root/themes/default.ini" "$plugin_root/themes" shipped
for style in "${_fsh_theme_style_order[@]}"; do
  if [[ $style == secondary ]]; then
    inikey=${_fsh_validated_theme_data[(i)<*>_secondary]}
    expected=${_fsh_validated_theme_data[$inikey]}
  else
    candidates=( ${(s. .)_fsh_theme_style_fallbacks[$style]} default )
    inikey=
    for candidate in "${candidates[@]}"; do
      [[ $candidate == - ]] && candidate=$style
      inikey=${_fsh_validated_theme_data[(i)<*>_${candidate}]}
      [[ -n $inikey ]] && break
    done
    normalize_theme_value "${_fsh_validated_theme_data[$inikey]}"
    expected=$REPLY
  fi
  [[ ${_fsh_styles[$style]-} == "$expected" ]] || {
    builtin print -u2 -r -- \
      "f-sy-h: built-in default style drifted: $style (${_fsh_styles[$style]-} != $expected)"
    exit 1
  }
done

typeset -A persisted_free
_fsh_read_ini "$plugin_root/share/free_theme.ini" persisted_free ''
_fsh_validate_theme "$plugin_root/themes/free.ini" "$plugin_root/themes" shipped
for style in "${_fsh_theme_style_order[@]}"; do
  if [[ $style == secondary ]]; then
    inikey=${_fsh_validated_theme_data[(i)<*>_secondary]}
    expected=${_fsh_validated_theme_data[$inikey]}
  else
    candidates=( ${(s. .)_fsh_theme_style_fallbacks[$style]} default )
    inikey=
    for candidate in "${candidates[@]}"; do
      [[ $candidate == - ]] && candidate=$style
      inikey=${_fsh_validated_theme_data[(i)<*>_${candidate}]}
      [[ -n $inikey ]] && break
    done
    normalize_theme_value "${_fsh_validated_theme_data[$inikey]}"
    expected=$REPLY
  fi
  [[ ${persisted_free[<styles>_free${style}]-} == "$expected" ]] || {
    builtin print -u2 -r -- \
      "f-sy-h: packaged free style drifted: $style (${persisted_free[<styles>_free${style}]-} != $expected)"
    exit 1
  }
done

fsh_theme --quiet "$fixture_root/sample-overlay.ini"
[[ -s $fixture_root/work/theme_overlay.ini ]]
if fsh_theme --quiet "$fixture_root/invalid-values.ini" 2>"$fixture_root/theme-error"; then
  builtin print -u2 -r -- 'f-sy-h: invalid theme unexpectedly loaded'
  exit 1
fi
[[ $(<"$fixture_root/theme-error") == *'invalid-style-value'* ]]
[[ ! -e $fixture_root/work/current_theme.ini ]]
fsh_plugin_unload
