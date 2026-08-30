#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -g _fsh_test_file=${${(%):-%N}:A}
TRAPZERR() {
  [[ ${${funcfiletrace[1]%:*}:A} == $_fsh_test_file ]] || return 0
  builtin print -u2 -r -- \
    "f-sy-h: theme persistence check failed at line ${funcfiletrace[1]##*:}"
}

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-themes.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

_fsh_test_read_until() {
  local pty_name=$1 pattern=$2 chunk
  integer deadline=$(( SECONDS + 15 ))
  REPLY=
  while (( SECONDS < deadline )); do
    if zpty -r -t "$pty_name" chunk; then
      REPLY+=$chunk
      [[ $REPLY == ${~pattern} ]] && return 0
    else
      command sleep 0.02
    fi
  done
  return 1
}

typeset theme theme_file theme_work output
for theme_file in "$plugin_root"/themes/*.ini(N); do
  theme=${theme_file:t:r}
  theme_work=$fixture_root/$theme
  command mkdir -p -- "$theme_work/zdotdir"
  output=$(ZDOTDIR=$theme_work/zdotdir XDG_CACHE_HOME=$theme_work/cache-home \
    zsh -f -c '
      fpath=( "$2/functions" $fpath )
      unfunction fsh_theme 2>/dev/null || true
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
    fpath=( "$2/functions" $fpath )
    unfunction fsh_theme 2>/dev/null || true
    zstyle ":fsh:config" work-dir "$1"
    source "$2/F-Sy-H.plugin.zsh"
    fsh_theme --list
    fsh_plugin_unload
  ' zsh "$fixture_root/list-work" "$plugin_root")
[[ $output == *Theme*Background* ]]
[[ $output == *light*'#ffffff'* ]]

theme_work=$fixture_root/inspection-work
output=$(ZDOTDIR=$fixture_root/inspection-zdotdir XDG_CACHE_HOME=$fixture_root/inspection-cache \
  zsh -f -c '
    fpath=( "$2/functions" $fpath )
    unfunction fsh_theme 2>/dev/null || true
    zstyle ":fsh:config" work-dir "$1"
    source "$2/F-Sy-H.plugin.zsh"
    typeset operation
    for operation in --help --info --palette --list --show --reset --ov-reset; do
      fsh_theme "$operation" >/dev/null
    done
    fsh_theme --test --quiet clean
    [[ $_fsh_preview_theme_name == clean ]]
    [[ ! -e $1 ]]
    fsh_plugin_unload
  ' zsh "$theme_work" "$plugin_root" 2>&1) || {
    builtin print -u2 -r -- "f-sy-h: inspection created theme storage: $output"
    exit 1
  }
[[ -z $output ]]

theme_work=$fixture_root/base16/work
output=$(ZDOTDIR=$fixture_root/reload-zdotdir XDG_CACHE_HOME=$fixture_root/reload-cache \
  zsh -f -c '
    setopt err_exit no_unset
    fpath=( "$2/functions" $fpath )
    unfunction fsh_theme 2>/dev/null || true
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

{
  builtin print -r -- '[styles]'
  builtin print -r -- 'command = red'
} >| "$fixture_root/test-overlay.ini"

theme_work=$fixture_root/preview/work
output=$(ZDOTDIR=$fixture_root/preview-zdotdir XDG_CACHE_HOME=$fixture_root/preview-cache \
  zsh -f -c '
    setopt err_exit no_unset
    fpath=( "$2/functions" $fpath )
    unfunction fsh_theme 2>/dev/null || true
    zstyle ":fsh:config" work-dir "$1"
    source "$2/F-Sy-H.plugin.zsh"
    fsh_theme --quiet default
    fsh_theme --quiet "$3"

    typeset show_output=$(fsh_theme --show)
    [[ $show_output == *"Currently active theme:"*default* ]]
    [[ $show_output == *"Active theme source: $2/themes/default.ini"* ]]
    [[ $show_output == *"Main theme (session startup):"*default* ]]
    [[ $show_output == *"Startup theme source: $2/themes/default.ini"* ]]

    typeset before_name=$_fsh_theme_name
    typeset before_styles=$(typeset -p _fsh_styles)
    typeset state_file
    for state_file in current_theme.ini secondary_theme.local.ini theme_overlay.ini; do
      command cp -- "$1/$state_file" "$1/$state_file.before"
    done

    fsh_theme --test --quiet clean
    [[ $_fsh_theme_name == $before_name ]]
    [[ $(typeset -p _fsh_styles) == $before_styles ]]
    [[ $_fsh_preview_theme_name == clean ]]
    [[ ${_fsh_preview_styles[cleancommand]} == fg=109 ]]
    [[ ${_fsh_preview_styles[cleansecondary]} == zdharma ]]
    [[ ${_fsh_preview_styles[zdharmacommand]} == fg=63 ]]
    [[ ${_fsh_preview_styles[clean-path]} == "$2/themes/clean.ini" ]]
    (( ! ${+_fsh_theme_preview_active} ))
    for state_file in current_theme.ini secondary_theme.local.ini theme_overlay.ini; do
      command cmp -s -- "$1/$state_file.before" "$1/$state_file"
    done

    typeset BUFFER=echo PREBUFFER= WIDGET=self-insert
    integer CURSOR=4 PENDING=0 REGION_ACTIVE=0 MARK=0
    typeset -a region_highlight=()
    _fsh_zle_highlight
    [[ ${region_highlight[(r)*fg=109*]} == *fg=109* ]]
    [[ $_fsh_theme_name == $before_name ]]
    [[ $(typeset -p _fsh_styles) == $before_styles ]]

    WIDGET=zle-line-finish
    _fsh_zle_highlight
    (( ! ${+_fsh_preview_theme_name} && ! ${+_fsh_preview_styles} ))
    fsh_plugin_unload
  ' zsh "$theme_work" "$plugin_root" "$fixture_root/test-overlay.ini" 2>&1) || {
    builtin print -u2 -r -- "f-sy-h: theme preview changed persistent or active state: $output"
    exit 1
  }
[[ -z $output ]] || {
  builtin print -u2 -r -- "f-sy-h: theme preview emitted output: $output"
  exit 1
}

command sed \
  's/^; secondary[[:blank:]]*=.*$/secondary = does-not-exist/' \
  "$plugin_root/themes/base16.ini" >| "$fixture_root/invalid.ini"
command mkdir -p -- "$fixture_root/invalid-zdotdir"
if output=$(ZDOTDIR=$fixture_root/invalid-zdotdir XDG_CACHE_HOME=$fixture_root/invalid-cache \
  zsh -f -c '
    fpath=( "$2/functions" $fpath )
    unfunction fsh_theme 2>/dev/null || true
    zstyle ":fsh:config" work-dir "$1"
    source "$2/F-Sy-H.plugin.zsh"
    fsh_theme --quiet "$3"
  ' zsh "$fixture_root/invalid-work" "$plugin_root" "$fixture_root/invalid.ini" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: invalid secondary theme unexpectedly succeeded'
  exit 1
fi
[[ $output == *'missing-secondary: secondary theme does not exist: does-not-exist'* ]] || {
  builtin print -u2 -r -- "f-sy-h: invalid secondary diagnostic mismatch: $output"
  exit 1
}
[[ ! -e $fixture_root/invalid-work/current_theme.ini ]]

zmodload zsh/zpty
typeset -r pty_name=fsyh-theme-preview
typeset -r preview_marker=$fixture_root/preview-render
command mkdir -p -- "$fixture_root/pty-home" "$fixture_root/pty-zdotdir"
zpty -b "$pty_name" \
  "HOME=${(q)fixture_root}/pty-home ZDOTDIR=${(q)fixture_root}/pty-zdotdir zsh -f -i"
{
  zpty -w "$pty_name" \
    "fpath=( ${(q)plugin_root}/functions \$fpath ); unfunction fsh_theme 2>/dev/null || true; zstyle ':fsh:config' work-dir ${(q)fixture_root}/pty-work; source ${(q)plugin_root}/F-Sy-H.plugin.zsh; _fsh_test_capture_preview() { BUFFER=echo; CURSOR=4; _fsh_zle_highlight; builtin print -r -- \"\${_fsh_preview_theme_name-}:\${region_highlight[(r)*fg=109*]-missing}\" >| ${(q)preview_marker}; }; zle -N _fsh_test_capture_preview; bindkey '^X^P' _fsh_test_capture_preview; PS1='FSH_PREVIEW> '; unsetopt prompt_cr prompt_sp; print -r -- FSH_PREVIEW_LOADED"
  _fsh_test_read_until "$pty_name" '*FSH_PREVIEW_LOADED*FSH_PREVIEW>*' || {
    builtin print -u2 -r -- "f-sy-h: preview PTY did not load: ${(V)REPLY[1,1000]}"
    exit 1
  }

  zpty -w "$pty_name" 'fsh_theme --test --quiet clean'
  _fsh_test_read_until "$pty_name" '*fsh_theme --test --quiet clean*./configure*' || {
    builtin print -u2 -r -- "f-sy-h: preview command did not reach ZLE: ${(V)REPLY[1,1000]}"
    exit 1
  }
  zpty -w -n "$pty_name" $'\C-X\C-P'
  integer marker_deadline=$(( SECONDS + 10 ))
  while [[ ! -e $preview_marker ]] && (( SECONDS < marker_deadline )); do
    command sleep 0.02
  done
  [[ -e $preview_marker ]]
  [[ $(<$preview_marker) == 'clean:0 4 fg=109' ]]
  [[ ! -e $fixture_root/pty-work ]]

  zpty -w -n "$pty_name" $'\C-C'
  _fsh_test_read_until "$pty_name" '*FSH_PREVIEW>*' || {
    builtin print -u2 -r -- "f-sy-h: preview abort did not return to the prompt: ${(V)REPLY[1,1000]}"
    exit 1
  }
  zpty -w "$pty_name" 'print -r -- "FSH_ABORT:${+_fsh_preview_theme_name}:${+_fsh_preview_styles}"'
  _fsh_test_read_until "$pty_name" '*FSH_ABORT:0:0*' || {
    builtin print -u2 -r -- "f-sy-h: preview state survived Ctrl-C: ${(V)REPLY[1,1000]}"
    exit 1
  }

  zpty -w "$pty_name" 'fsh_theme --test --quiet clean'
  _fsh_test_read_until "$pty_name" '*fsh_theme --test --quiet clean*./configure*' || {
    builtin print -u2 -r -- "f-sy-h: second preview did not reach ZLE: ${(V)REPLY[1,1000]}"
    exit 1
  }
  zpty -w -n "$pty_name" $'\C-U'
  zpty -w "$pty_name" ':'
  _fsh_test_read_until "$pty_name" '*FSH_PREVIEW>*' || {
    builtin print -u2 -r -- "f-sy-h: preview acceptance did not return to the prompt: ${(V)REPLY[1,1000]}"
    exit 1
  }
  zpty -w "$pty_name" 'print -r -- "FSH_ACCEPT:${+_fsh_preview_theme_name}:${+_fsh_preview_styles}"'
  _fsh_test_read_until "$pty_name" '*FSH_ACCEPT:0:0*' || {
    builtin print -u2 -r -- "f-sy-h: preview state survived acceptance: ${(V)REPLY[1,1000]}"
    exit 1
  }
} always {
  zpty -d "$pty_name" 2>/dev/null || true
}
