#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-git-knowledge.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
command mkdir -p -- "$ZDOTDIR"
zstyle ':fsh:config' work-dir "$fixture_root/work"
typeset -r original_pwd=$PWD

source "$plugin_root/F-Sy-H.plugin.zsh"
_fsh_chroma_git

typeset -a _fsh_git_parse_reply
_fsh_chroma_git_parse_subcommands \
  'Main Porcelain Commands' \
  '   nebula                 Travel through repositories' \
  '   switch                 Switch branches' \
  '   bad;name               must be rejected' \
  'Command aliases' \
  '   shell-alias            !touch /tmp/must-not-run'
[[ ${(j:,:)_fsh_git_parse_reply} == nebula,switch ]]

_fsh_chroma_git_parse_options \
  '    -q, --[no-]quiet      suppress output' \
  '    --[no-]warp[=<speed>]  select warp speed' \
  '    -M, --find-renames[=<n>]  detect renames' \
  '    --evil;run            must be rejected'
[[ ${(j:,:)_fsh_git_parse_reply} == \
  '-q,--quiet,--no-quiet,--warp=,--no-warp=,-M,--find-renames=' ]]

# With no interactive ZLE and no cache, the provider must return its frozen
# fallback without starting a command.
typeset -a reply
_fsh_chroma_git_get_subcommands
(( reply[(Ie)switch] ))
(( ! ${_fsh_state[chroma-git-subcommands-pending]:-0} ))

# A fresh runtime list replaces the fallback and refreshes an already-created
# main chroma hash.
_fsh_state[chroma-git-subcommands-cache]=$'   commit                  Record changes\n   nebula                  Travel through repositories'
_fsh_state[chroma-git-subcommands-cache-ready]=1
_fsh_state[chroma-git-subcommands-cache-born-at]=$SECONDS
typeset alias_cache_key="chroma-git-aliases-${PWD:A}"
_fsh_state[$alias_cache_key-cache]=$'alias.safe commit\nalias.shell-alias !touch /tmp/must-not-run'
_fsh_state[$alias_cache_key-cache-ready]=1
_fsh_state[$alias_cache_key-cache-born-at]=$SECONDS
_fsh_chroma_git_get_subcommands
[[ ${(j:,:)reply} == 'commit,nebula,safe' ]]
(( ! reply[(Ie)shell-alias] ))

# Repository-local aliases from one directory must not leak through the cache
# after changing to another directory.
command mkdir -p -- "$fixture_root/repo-a" "$fixture_root/repo-b"
cd "$fixture_root/repo-a"
alias_cache_key="chroma-git-aliases-${PWD:A}"
_fsh_state[$alias_cache_key-cache]=$'alias.repo-a commit'
_fsh_state[$alias_cache_key-cache-ready]=1
_fsh_state[$alias_cache_key-cache-born-at]=$SECONDS
_fsh_chroma_git_get_subcommands
(( reply[(Ie)repo-a] ))

cd "$fixture_root/repo-b"
_fsh_chroma_git_get_subcommands
(( ! reply[(Ie)repo-a] ))
cd "$original_pwd"

# A failed or unexpectedly empty refresh preserves the last valid runtime
# result instead of replacing it with an empty command surface.
_fsh_state[chroma-git-subcommands-cache]='unexpected layout'
(( ++ _fsh_state[chroma-git-subcommands-cache-born-at] ))
_fsh_chroma_git_get_subcommands
[[ ${(j:,:)reply} == 'commit,nebula,safe' ]]

# The runtime-only option must be inserted before the frozen NO_MATCH set.
_fsh_state[chroma-git-options-commit-cache]=$'    --future-mode       use the future mode'
_fsh_state[chroma-git-options-commit-cache-ready]=1
_fsh_state[chroma-git-options-commit-cache-born-at]=$SECONDS

typeset -g BUFFER='git commit --future-mode' PREBUFFER=
reply=()
_fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
typeset expected_highlights=
expected_highlights="0 3 ${_fsh_styles[command]}"$'\n'\
"4 10 ${_fsh_styles[subcommand]}"$'\n'\
"11 24 ${_fsh_styles[double-hyphen-option]}"
[[ ${(F)reply} == "$expected_highlights" ]]
[[ ${_fsh_chroma_main_git[subcmd:commit]} == \
  *'GIT_RUNTIME_commit_R_#_opt // NO_MATCH_#_opt'* ]]

BUFFER='git commit --stale-mode'
reply=()
_fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
expected_highlights="0 3 ${_fsh_styles[command]}"$'\n'\
"4 10 ${_fsh_styles[subcommand]}"$'\n'\
"11 23 ${_fsh_styles[incorrect-subtle]}"
[[ ${(F)reply} == "$expected_highlights" ]]

typeset git_source=$(<"$plugin_root/chroma/_fsh_chroma_git")
[[ $git_source == *'_fsh_async_command chroma-git-subcommands'* ]]
[[ $git_source == *'_fsh_async_command "$alias_cache_key"'* ]]
[[ $git_source == *'_fsh_async_command --capture-stderr "$key" env LC_ALL=C git "$subcommand" -h'* ]]

fsh_plugin_unload
