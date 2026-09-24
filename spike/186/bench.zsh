#!/usr/bin/env zsh
# Spike harness for #186. One process per variant:
#   bench.zsh PLUGIN_ROOT unreg|generic|derived [regions]
# Times _fsh_highlight_process on the 9- and 13-word lines, interleaved pass
# by pass, and prints p10 and median in ms over 301 passes. With "regions" it
# prints the region list of each fidelity line instead.

emulate -R zsh
setopt no_unset
zmodload zsh/datetime zsh/mathfunc

typeset -r plugin_root=${1:?plugin root} variant=${2:?variant} mode=${3:-time}
typeset -r spike_root=${${(%):-%N}:A:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-186.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir XDG_CACHE_HOME=$fixture_root/cache-home
command mkdir -p -- "$ZDOTDIR"
zstyle ':fsh:config' work-dir "$fixture_root/work"
zstyle ':fsh:config' bracket-highlighting disabled

source "$plugin_root/F-Sy-H.plugin.zsh"
fpath=( "$plugin_root"/{functions,completions,chroma} "$spike_root/chroma" \
  "${(@)fpath:#$plugin_root/(functions|completions|chroma)}" )
autoload -Uz _fsh_chroma_ghd _fsh_chroma_ghd2 _fsh_chroma_claim
typeset -g _fsh_ghd_path=
typeset -gi _fsh_ghd_want=0 _fsh_ghd_dd=0

source "$spike_root/gh-table.zsh"
typeset -gA _fsh_spike_gh
_fsh_spike_gh=( "${(@kv)table}" )
unset table

typeset cmd=gh
case $variant in
  (unreg) cmd=du ;;
  (generic) [[ ${_fsh_state[chroma-gh]} == _fsh_chroma_subcommand ]] || exit 3 ;;
  (derived) _fsh_state[chroma-gh]=_fsh_chroma_ghd ;;
  (claim) _fsh_state[chroma-gh]=_fsh_chroma_claim ;;
  (derived2) _fsh_state[chroma-gh]=_fsh_chroma_ghd2 ;;
  (*) exit 2 ;;
esac

typeset -a lines=(
  "$cmd pr list -L 5 --state open --author me"
  "$cmd pr list -L 5 --state open --author me --label bug --base main"
)
typeset -a fidelity=(
  "$cmd pr list -L 5 --state open --author me"
  "$cmd pr lisst"
  "$cmd pr list --stat open"
  "$cmd pr list -L \$n --author \"\$x\""
  "$cmd pr list -L5 -dw"
  "$cmd repo clone z-shell/F-Sy-H -- --depth 1"
  "$cmd --version"
  "sudo $cmd pr view 1 | grep x"
)

typeset BUFFER= PREBUFFER=
typeset -a reply
_fsh_highlight_init

if [[ $mode == regions ]]; then
  for BUFFER in $fidelity; do
    reply=()
    _fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
    print -r -- "== $BUFFER"
    print -rl -- $reply
  done
  exit 0
fi

integer run i
float t0
typeset -a s1 s2
for BUFFER in $lines; do reply=(); _fsh_highlight_process "$PREBUFFER" "$BUFFER" 0; done
for run in {1..301}; do
  for i in 1 2; do
    BUFFER=$lines[i]
    reply=()
    t0=$EPOCHREALTIME
    _fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
    # Integer microseconds: (on) compares fractional digits as integers.
    if (( i == 1 )); then s1+=( $(( int((EPOCHREALTIME - t0) * 1e6) )) ); else s2+=( $(( int((EPOCHREALTIME - t0) * 1e6) )) ); fi
  done
done
s1=( ${(on)s1} ) s2=( ${(on)s2} )
(( s1[31] <= s1[151] && s2[31] <= s2[151] )) || exit 4
printf '%-8s 9w p10 %.3f med %.3f | 13w p10 %.3f med %.3f\n' $variant $(( s1[31] / 1e3 )) $(( s1[151] / 1e3 )) $(( s2[31] / 1e3 )) $(( s2[151] / 1e3 ))
