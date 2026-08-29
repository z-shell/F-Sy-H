#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-entrypoint.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
typeset -gx PMSPEC=0fuUpiPs
command mkdir -p -- "$ZDOTDIR"
zstyle ':fsh:config' work-dir "$fixture_root/work"
zstyle ':fsh:config' max-length 321
zstyle ':fsh:config' chroma-cache-seconds 7
zstyle ':fsh:config' chroma-timeout-seconds 3
zstyle ':fsh:config' bracket-highlighting disabled
zstyle ':fsh:config' path-blocklist '/private/*' '/mnt/slow/**'

count_fpath_entry() {
  emulate -L zsh

  local entry
  integer count=0
  for entry in "${fpath[@]}"; do
    [[ $entry == "$1" ]] && (( ++count ))
  done
  REPLY=$count
}

source "$plugin_root/F-Sy-H.plugin.zsh"

[[ $_fsh_base_dir == $plugin_root ]]
(( _fsh_max_length == 321 ))
(( _fsh_chroma_cache_seconds == 7 ))
(( _fsh_chroma_timeout_seconds == 3 ))
(( _fsh_state[use_brackets] == 0 ))
typeset blocklist_key='/private/*'
(( ${+_fsh_blocklist_patterns[$blocklist_key]} ))
blocklist_key='/mnt/slow/**'
(( ${+_fsh_blocklist_patterns[$blocklist_key]} ))
count_fpath_entry "$plugin_root/functions"
(( REPLY == 1 ))
count_fpath_entry "$plugin_root/completions"
(( REPLY == 1 ))
count_fpath_entry "$plugin_root/chroma"
(( REPLY == 1 ))
[[ ! -e $_fsh_work_dir ]]

autoload -Uz _fsh_chroma_source
[[ ${functions[_fsh_chroma_source]} == *builtin*autoload* ]]

source "$plugin_root/F-Sy-H.plugin.zsh"
count_fpath_entry "$plugin_root/functions"
(( REPLY == 1 ))
count_fpath_entry "$plugin_root/completions"
(( REPLY == 1 ))
count_fpath_entry "$plugin_root/chroma"
(( REPLY == 1 ))

command mkdir -p -- "$_fsh_work_dir"
fsh_theme --secondary --quiet default
[[ -s $_fsh_work_dir/secondary_theme.local.ini ]]
[[ $(<"$_fsh_work_dir/secondary_theme.local.ini") != *'typeset '* ]]
print -r -- 'typeset -g _fsyh_untrusted_theme_executed=1' >| "$_fsh_work_dir/secondary_theme.local.zsh"
print -r -- 'print -r -- fixture' >| "$fixture_root/fixture.zsh"

reply=()
PREBUFFER=
BUFFER="eval 'print fixture'"
_fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
(( ! ${+_fsyh_untrusted_theme_executed} ))

reply=()
PREBUFFER=
BUFFER="source $fixture_root/fixture.zsh"
_fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
[[ ! -e $_fsh_work_dir/fixture.zsh ]]
[[ ! -e $_fsh_work_dir/fixture.zsh.zwc ]]

fsh_theme --quiet clean
[[ -s $_fsh_work_dir/current_theme.ini ]]
[[ $(<"$_fsh_work_dir/current_theme.ini") != *'typeset '* ]]
typeset -r theme_work_dir=$_fsh_work_dir
fsh_plugin_unload

print -r -- 'typeset -g _fsyh_untrusted_theme_executed=1' >| \
  "$theme_work_dir/current_theme.zsh"
source "$plugin_root/F-Sy-H.plugin.zsh"
[[ $_fsh_theme_name == clean ]]
[[ -n ${_fsh_styles[cleancommand]} ]]
(( ! ${+_fsyh_untrusted_theme_executed} ))
fsh_plugin_unload

zstyle ':fsh:config' theme-manager disabled
source "$plugin_root/F-Sy-H.plugin.zsh"
(( ! ${+functions[fsh_theme]} ))
fsh_plugin_unload
