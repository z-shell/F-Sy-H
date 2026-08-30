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

float -r budget_seconds=0.250
float -r incremental_ratio=0.700
integer length run
float started elapsed full_median incremental_median
typeset pattern='echo a; '
typeset BUFFER= PREBUFFER=
typeset suffix_char
typeset -a reply samples
typeset -A full_medians incremental_medians

(( _fsh_max_length == 1000 ))

# Compare full parses with eligible end edits across short, medium, and capped
# buffers. Medians tolerate an isolated noisy runner while preserving a fixed
# per-keystroke ceiling at the configured cap.
for length in 100 500 1000; do
  BUFFER=
  while (( $#BUFFER < length )); do
    BUFFER+=$pattern
  done
  BUFFER=${BUFFER[1,length]}
  (( $#BUFFER == length ))

  _fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
  (( $#reply > 0 ))
  samples=()
  for run in {1..5}; do
    _fsh_incremental_reset
    started=$EPOCHREALTIME
    _fsh_highlight_buffer "$PREBUFFER" "$BUFFER"
    elapsed=$(( EPOCHREALTIME - started ))
    samples+=( $elapsed )
    (( ! _fsh_incremental_last_used ))
    (( $#reply > 0 ))
  done
  samples=( ${(on)samples} )
  full_median=$samples[3]
  full_medians[$length]=$full_median

  _fsh_incremental_reset
  _fsh_highlight_buffer "$PREBUFFER" "$BUFFER"
  samples=()
  for run in {1..5}; do
    (( run % 2 )) && suffix_char=x || suffix_char=y
    BUFFER=${BUFFER[1,-2]}$suffix_char
    started=$EPOCHREALTIME
    _fsh_highlight_buffer "$PREBUFFER" "$BUFFER"
    elapsed=$(( EPOCHREALTIME - started ))
    samples+=( $elapsed )
    (( _fsh_incremental_last_used ))
    (( $#reply > 0 ))
  done
  samples=( ${(on)samples} )
  incremental_median=$samples[3]
  incremental_medians[$length]=$incremental_median

  if [[ -n ${FSH_BENCHMARK_REPORT-} ]]; then
    builtin printf \
      'f-sy-h: %d chars full=%.6fs incremental=%.6fs ratio=%.3f\n' \
      $length $full_median $incremental_median \
      $(( incremental_median / full_median ))
  fi
done

full_median=$full_medians[1000]
incremental_median=$incremental_medians[1000]
if (( full_median > budget_seconds )); then
  builtin printf >&2 \
    'f-sy-h: median full highlight time %.3fs exceeds %.3fs at 1000 characters\n' \
    $full_median $budget_seconds
  exit 1
fi
if (( incremental_median > budget_seconds )); then
  builtin printf >&2 \
    'f-sy-h: median incremental highlight time %.3fs exceeds %.3fs at 1000 characters\n' \
    $incremental_median $budget_seconds
  exit 1
fi
if (( incremental_median > full_median * incremental_ratio )); then
  builtin printf >&2 \
    'f-sy-h: median incremental time %.3fs is not at least 30%% faster than %.3fs at 1000 characters\n' \
    $incremental_median $full_median
  exit 1
fi

BUFFER=
while (( $#BUFFER <= _fsh_max_length )); do
  BUFFER+=$pattern
done
BUFFER=${BUFFER[1,_fsh_max_length + 1]}
(( $#BUFFER == _fsh_max_length + 1 ))
region_highlight=( sentinel )
_fsh_zle_highlight
[[ $region_highlight == sentinel ]]
(( ! _fsh_incremental_cache_valid ))

fsh_plugin_unload
