#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

zmodload zsh/datetime

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-budget.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
command mkdir -p -- "$ZDOTDIR"
zstyle ':fsh:config' work-dir "$fixture_root/work"
zstyle ':fsh:config' bracket-highlighting disabled

source "$plugin_root/F-Sy-H.plugin.zsh"

integer -r buffer_length=1000
float -r budget_seconds=0.250
integer run
float started elapsed median
typeset pattern='echo a; '
typeset BUFFER= PREBUFFER=
typeset -a reply samples

(( _fsh_max_length == buffer_length ))

while (( $#BUFFER < buffer_length )); do
  BUFFER+=$pattern
done
BUFFER=${BUFFER[1,buffer_length]}
(( $#BUFFER == buffer_length ))

# Warm caches before collecting five samples. The median tolerates an isolated
# noisy runner while preserving a fixed per-keystroke regression ceiling.
_fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
(( $#reply > 0 ))

for run in {1..5}; do
  reply=()
  started=$EPOCHREALTIME
  _fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
  elapsed=$(( EPOCHREALTIME - started ))
  samples+=( $elapsed )
  (( $#reply > 0 ))
done

samples=( ${(on)samples} )
median=$samples[3]
if (( median > budget_seconds )); then
  builtin printf >&2 \
    'f-sy-h: median highlight time %.3fs exceeds %.3fs at %d characters\n' \
    $median $budget_seconds $buffer_length
  exit 1
fi

BUFFER+=x
region_highlight=( sentinel )
_fsh_zle_highlight
[[ $region_highlight == sentinel ]]

fsh_plugin_unload
