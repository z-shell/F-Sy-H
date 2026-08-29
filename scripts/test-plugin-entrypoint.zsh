#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset posix_argzero

typeset -r plugin_root=${0:A:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-entrypoint.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
typeset -gx FAST_WORK_DIR=$fixture_root/work
typeset -gx PMSPEC=0fuUpiPs
command mkdir -p -- "$ZDOTDIR"

source "$plugin_root/F-Sy-H.plugin.zsh"

[[ $FAST_BASE_DIR == $plugin_root ]]
(( ${#${(M)fpath:#$plugin_root}} == 1 ))
(( ${#${(M)fpath:#$plugin_root/functions}} == 1 ))
[[ ! -e $FAST_WORK_DIR ]]

autoload -Uz chroma/-source.ch
[[ ${functions[chroma/-source.ch]} == *builtin*autoload* ]]

source "$plugin_root/F-Sy-H.plugin.zsh"
(( ${#${(M)fpath:#$plugin_root}} == 1 ))
(( ${#${(M)fpath:#$plugin_root/functions}} == 1 ))

command mkdir -p -- "$FAST_WORK_DIR"
fast-theme --secondary --quiet default
[[ -s $FAST_WORK_DIR/secondary_theme.local.zsh ]]
print -r -- 'typeset -g _fsyh_untrusted_theme_executed=1' >| "$FAST_WORK_DIR/secondary_theme.zsh"
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
[[ ! -e $FAST_WORK_DIR/fixture.zsh ]]
[[ ! -e $FAST_WORK_DIR/fixture.zsh.zwc ]]
