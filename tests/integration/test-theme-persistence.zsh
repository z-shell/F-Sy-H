#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-themes.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset theme theme_file theme_work output
for theme_file in "$plugin_root"/themes/*.ini(N); do
  theme=${theme_file:t:r}
  theme_work=$fixture_root/$theme
  command mkdir -p -- "$theme_work/zdotdir"
  output=$(ZDOTDIR=$theme_work/zdotdir XDG_CACHE_HOME=$theme_work/cache-home \
    zsh -f -c '
      zstyle ":fsh:config" work-dir "$1"
      source "$2/F-Sy-H.plugin.zsh"
      fsh_theme --quiet "$3"
      [[ $_fsh_theme_name == "$3" ]]
      [[ -s $1/current_theme.ini ]]
      fsh_plugin_unload
    ' zsh "$theme_work/work" "$plugin_root" "$theme" 2>&1) || {
      builtin print -u2 -r -- "f-sy-h: shipped theme $theme failed: $output"
      exit 1
    }
  [[ -z $output ]] || {
    builtin print -u2 -r -- "f-sy-h: shipped theme $theme emitted output: $output"
    exit 1
  }
done

output=$(ZDOTDIR=$fixture_root/list-zdotdir XDG_CACHE_HOME=$fixture_root/list-cache \
  zsh -f -c '
    zstyle ":fsh:config" work-dir "$1"
    source "$2/F-Sy-H.plugin.zsh"
    fsh_theme --list
    fsh_plugin_unload
  ' zsh "$fixture_root/list-work" "$plugin_root")
[[ $output == *Theme*Background* ]]
[[ $output == *light*'#ffffff'* ]]

theme_work=$fixture_root/base16/work
output=$(ZDOTDIR=$fixture_root/reload-zdotdir XDG_CACHE_HOME=$fixture_root/reload-cache \
  zsh -f -c '
    setopt err_exit no_unset
    zstyle ":fsh:config" work-dir "$1"
    source "$2/F-Sy-H.plugin.zsh"
    [[ $_fsh_theme_name == base16 ]]
    (( ! ${+_fsh_styles[base16secondary]} ))

    typeset -A persisted
    integer style_count=0
    typeset key style_key
    _fsh_read_ini "$1/current_theme.ini" persisted
    [[ ${persisted[<theme>_name]} == base16 ]]
    for key in ${(k)persisted}; do
      [[ $key == "<styles>_"* ]] || continue
      style_key=${key#"<styles>_"}
      [[ ${_fsh_styles[$style_key]} == ${persisted[$key]} ]]
      (( ++style_count ))
    done
    (( style_count > 50 ))
    fsh_plugin_unload
  ' zsh "$theme_work" "$plugin_root" 2>&1) || {
    builtin print -u2 -r -- "f-sy-h: persisted base16 theme did not reload: $output"
    exit 1
  }
[[ -z $output ]] || {
  builtin print -u2 -r -- "f-sy-h: base16 reload emitted output: $output"
  exit 1
}

command sed \
  's/^; secondary[[:blank:]]*=.*$/secondary = does-not-exist/' \
  "$plugin_root/themes/base16.ini" >| "$fixture_root/invalid.ini"
command mkdir -p -- "$fixture_root/invalid-zdotdir"
if output=$(ZDOTDIR=$fixture_root/invalid-zdotdir XDG_CACHE_HOME=$fixture_root/invalid-cache \
  zsh -f -c '
    zstyle ":fsh:config" work-dir "$1"
    source "$2/F-Sy-H.plugin.zsh"
    fsh_theme --quiet "$3"
  ' zsh "$fixture_root/invalid-work" "$plugin_root" "$fixture_root/invalid.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: invalid secondary theme unexpectedly succeeded'
  exit 1
fi
[[ $output == *'missing-secondary: secondary theme does not exist: does-not-exist'* ]]
[[ ! -e $fixture_root/invalid-work/current_theme.ini ]]
