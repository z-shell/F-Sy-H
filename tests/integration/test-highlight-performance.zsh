#!/usr/bin/env zsh

# Report timing for CI comparisons while enforcing deterministic behavior.

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

integer length run
float started elapsed median
typeset pattern='echo this is a moderately long test command line with several arguments and some paths like /usr/local/bin/foo --verbose --dry-run'
typeset extension=' /usr/local/bin/foo --verbose --dry-run argument'
typeset BUFFER= PREBUFFER= WIDGET=self-insert
integer CURSOR=0 REGION_ACTIVE=0
typeset -a region_highlight samples
typeset lifecycle_refresh_definition=${functions[_fsh_lifecycle_refresh]}
integer lifecycle_refresh_calls=0

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

  if (( length == 173 )); then
    _fsh_lifecycle_refresh() { (( ++lifecycle_refresh_calls )); }
  fi

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

  if [[ -n ${FSH_BENCHMARK_REPORT-} ]]; then
    builtin printf 'f-sy-h: %d chars median=%.6fs\n' $length $median
  fi
done

(( lifecycle_refresh_calls == 0 )) || {
  builtin printf >&2 'f-sy-h: steady-state highlighting performed %d full lifecycle refreshes\n' \
    $lifecycle_refresh_calls
  exit 1
}
functions[_fsh_lifecycle_refresh]=$lifecycle_refresh_definition

BUFFER+=$extension
BUFFER=${BUFFER[1,_fsh_max_length + 1]}
(( $#BUFFER == _fsh_max_length + 1 ))
region_highlight=( sentinel )
_fsh_zle_highlight
[[ $region_highlight == sentinel ]]

fsh_plugin_unload
