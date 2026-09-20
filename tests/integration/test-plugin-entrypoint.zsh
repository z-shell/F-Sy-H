#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-entrypoint.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx HOME=$fixture_root/home
typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
typeset -gx PMSPEC=0fuUpiPs
command mkdir -p -- "$HOME" "$ZDOTDIR"
zstyle ':fsh:config' work-dir "$fixture_root/work"
zstyle ':fsh:config' max-length 321
zstyle ':fsh:config' git-message-length 60
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

typeset -r migration_warning='f-sy-h: detected unsupported zsh-syntax-highlighting configuration; see README.md: Migrating from zsh-syntax-highlighting'
typeset legacy_case legacy_output
for legacy_case in styles highlighters both; do
  legacy_output=$(
    command zsh -f -c '
      builtin emulate -R zsh
      builtin setopt err_exit no_unset

      case $2 in
        (styles)
          typeset -A ZSH_HIGHLIGHT_STYLES=( comment "fg=201" )
          ;;
        (highlighters)
          typeset -a ZSH_HIGHLIGHT_HIGHLIGHTERS=( main brackets )
          ;;
        (both)
          typeset -A ZSH_HIGHLIGHT_STYLES=( comment "fg=201" )
          typeset -a ZSH_HIGHLIGHT_HIGHLIGHTERS=( main brackets )
          ;;
      esac

      builtin source "$1"
      builtin source "$1"

      if [[ $2 == styles || $2 == both ]]; then
        [[ ${ZSH_HIGHLIGHT_STYLES[comment]} == "fg=201" ]]
      fi
      if [[ $2 == highlighters || $2 == both ]]; then
        [[ ${(j: :)ZSH_HIGHLIGHT_HIGHLIGHTERS} == "main brackets" ]]
      fi

      fsh_plugin_unload

      if [[ $2 == styles || $2 == both ]]; then
        [[ ${ZSH_HIGHLIGHT_STYLES[comment]} == "fg=201" ]]
      fi
      if [[ $2 == highlighters || $2 == both ]]; then
        [[ ${(j: :)ZSH_HIGHLIGHT_HIGHLIGHTERS} == "main brackets" ]]
      fi
    ' zsh "$plugin_root/F-Sy-H.plugin.zsh" "$legacy_case" 2>&1
  )
  [[ $legacy_output == "$migration_warning" ]]
done

typeset comments_transition
for comments_transition in off-to-on on-to-off; do
  command zsh -f -c '
    builtin emulate -R zsh
    builtin setopt err_exit no_unset

    typeset expected_end expected_style option_state PREBUFFER BUFFER
    typeset -a reply

    case $2 in
      (off-to-on)
        builtin unsetopt interactive_comments
        expected_end=9
        expected_style=comment
        ;;
      (on-to-off)
        builtin setopt interactive_comments
        expected_end=1
        expected_style=unknown-token
        ;;
    esac

    builtin source "$1"

    case $2 in
      (off-to-on) builtin setopt interactive_comments;;
      (on-to-off) builtin unsetopt interactive_comments;;
    esac

    option_state=$options[interactivecomments]
    reply=()
    PREBUFFER=
    BUFFER="# comment"
    _fsh_highlight_process "$PREBUFFER" "$BUFFER" 0

    (( ${#reply} == 1 ))
    [[ $reply[1] == "0 $expected_end ${_fsh_styles[${_fsh_theme_name}$expected_style]}" ]]
    [[ $options[interactivecomments] == $option_state ]]
  ' zsh "$plugin_root/F-Sy-H.plugin.zsh" "$comments_transition"
done

source "$plugin_root/F-Sy-H.plugin.zsh"

[[ $_fsh_base_dir == $plugin_root ]]
(( _fsh_max_length == 321 ))
(( _fsh_git_message_length == 60 ))
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
