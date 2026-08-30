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

float -r interactive_budget_seconds=0.100
float -r cap_budget_seconds=0.250
integer length run
float started elapsed median budget_seconds
typeset pattern='echo this is a moderately long test command line with several arguments and some paths like /usr/local/bin/foo --verbose --dry-run'
typeset extension=' /usr/local/bin/foo --verbose --dry-run argument'
typeset BUFFER= PREBUFFER= WIDGET=self-insert
integer CURSOR=0 REGION_ACTIVE=0
typeset -a region_highlight samples

(( _fsh_max_length == 1000 ))
(( ! ${+functions[_fsh_highlight_buffer]} ))
(( ! ${+_fsh_incremental_collect} ))

for length in 173 1000; do
  BUFFER=$pattern
  while (( $#BUFFER < length )); do
    BUFFER+=$extension
  done
  BUFFER=${BUFFER[1,length]}
  (( $#BUFFER == length ))

  CURSOR=$#BUFFER
  typeset -g _fsh_prior_buffer=
  region_highlight=()
  _fsh_zle_highlight
  (( $#region_highlight > 0 ))

  samples=()
  for run in {1..9}; do
    typeset -g _fsh_prior_buffer=
    region_highlight=()
    started=$EPOCHREALTIME
    _fsh_zle_highlight
    elapsed=$(( EPOCHREALTIME - started ))
    samples+=( $elapsed )
    (( $#region_highlight > 0 ))
  done

  samples=( ${(on)samples} )
  median=$samples[5]
  (( length == 173 )) && budget_seconds=$interactive_budget_seconds || \
    budget_seconds=$cap_budget_seconds

  if [[ -n ${FSH_BENCHMARK_REPORT-} ]]; then
    builtin printf 'f-sy-h: %d chars median=%.6fs\n' $length $median
  fi
  if (( median > budget_seconds )); then
    builtin printf >&2 \
      'f-sy-h: median highlight time %.3fs exceeds %.3fs at %d characters\n' \
      $median $budget_seconds $length
    exit 1
  fi
done

BUFFER+=$extension
BUFFER=${BUFFER[1,_fsh_max_length + 1]}
(( $#BUFFER == _fsh_max_length + 1 ))
region_highlight=( sentinel )
_fsh_zle_highlight
[[ $region_highlight == sentinel ]]

fsh_plugin_unload
