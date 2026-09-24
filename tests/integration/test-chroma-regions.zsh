#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-chromas.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
typeset -gA ZI
command mkdir -p -- "$ZDOTDIR" "$fixture_root/repo/some"
command touch -- "$fixture_root/repo/some/file.lua"
zstyle ':fsh:config' work-dir "$fixture_root/work"
fpath=( "$plugin_root"/{functions,completions,chroma} \
  "${(@)fpath:#$plugin_root/(functions|completions|chroma)}" )

docker() { :; }
deno() { :; }
gh() { :; }
ls() { :; }
kubectl() { :; }
npm() { :; }
hub() { :; }
lab() { :; }
scp() { :; }
zi() { :; }
alias kg='kubectl get --namespace=x'
alias k='kubectl'
alias g='git'
alias st='strace -f'
ZI[cmd-list]='help|light|status'

source "$plugin_root/F-Sy-H.plugin.zsh"
source "$plugin_root/tests/integration/chroma-fixture.zsh"
builtin cd -- "$fixture_root/repo"

_fsh_styles[command]=fg=1
_fsh_styles[function]=fg=1
_fsh_styles[subcommand]=fg=2
_fsh_styles[default]=fg=3
_fsh_styles[single-hyphen-option]=fg=4
_fsh_styles[double-hyphen-option]=fg=5
_fsh_styles[incorrect-subtle]=fg=6
_fsh_styles[correct-subtle]=fg=7
_fsh_styles[unknown-token]=fg=8
_fsh_styles[path]=fg=7
_fsh_styles[optarg-string]=fg=9
_fsh_styles[reserved-word]=fg=10
_fsh_styles[alias]=fg=11
_fsh_styles[case-input]=fg=12
_fsh_styles[case-parentheses]=fg=13
_fsh_styles[case-condition]=fg=14
_fsh_styles[commandseparator]=fg=15
_fsh_styles[redirection]=fg=16
_fsh_styles[precommand]=fg=17

fsh_assert_exact_regions 'git commit some/file.lua' \
  '0 3 fg=1' \
  '4 10 fg=2' \
  '11 24 fg=7'

fsh_assert_exact_regions 'git log some/file.lua' \
  '0 3 fg=1' \
  '4 7 fg=2' \
  '8 21 fg=7'

fsh_assert_exact_regions 'zi help' \
  '0 2 fg=1' \
  '3 7 fg=2'

# Keep Docker validation deterministic and independent of a local daemon.
_fsh_state[chroma-docker-list-cache]=$'deadbeef'
_fsh_state[chroma-docker-list-cache-ready]=1
_fsh_state[chroma-docker-list-cache-born-at]=$SECONDS

fsh_assert_exact_regions 'docker image rm deadbeef' \
  '0 6 fg=1' \
  '7 12 fg=2' \
  '13 15 fg=2' \
  '16 24 fg=7'

fsh_assert_exact_regions 'npm install package' \
  '0 3 fg=1' \
  '4 11 fg=2' \
  '12 19 fg=3'

# The generic handler paints the subcommand only when it is unambiguous and
# paints nothing otherwise; it never guesses which option consumes a word.
fsh_assert_exact_regions 'gh pr list --state open' \
  '0 2 fg=1' \
  '3 5 fg=2' \
  '6 10 fg=3' \
  '11 18 fg=5' \
  '19 23 fg=3'
fsh_assert_exact_regions 'kubectl --namespace=x get pods' \
  '0 7 fg=1' \
  '8 21 fg=5' \
  '20 21 fg=9' \
  '22 25 fg=2' \
  '26 30 fg=3'
# An option that might take a value hides the subcommand: neutral, not a guess.
fsh_assert_exact_regions 'gh --repo o/r pr list' \
  '0 2 fg=1' \
  '3 9 fg=5' \
  '10 13 fg=3' \
  '14 16 fg=3' \
  '17 21 fg=3'
fsh_assert_exact_regions 'npm -g install x' \
  '0 3 fg=1' \
  '4 6 fg=4' \
  '7 14 fg=3' \
  '15 16 fg=3'
# A first operand that is not a plain word is not a verb.
fsh_assert_exact_regions 'deno file.ts' \
  '0 4 fg=1' \
  '5 12 fg=3'
fsh_assert_exact_regions 'deno run file.ts' \
  '0 4 fg=1' \
  '5 8 fg=2' \
  '9 16 fg=3'
# The alias loop dispatches every alias word; a --name=value alias word must
# not re-arm the released takeover and paint the user's first operand.
fsh_assert_exact_regions 'kg pods' \
  '0 2 fg=11' \
  '3 7 fg=3'
fsh_assert_exact_regions 'k get pods' \
  '0 1 fg=11' \
  '2 5 fg=2' \
  '6 10 fg=3'
# The precommand handler follows the same rule: the first operand is the
# command, an option with an attached value or `--` keeps the search going,
# and any other option might consume the next word, so nothing is painted
# as the command.
fsh_assert_exact_regions 'nohup gh pr list' \
  '0 5 fg=17' \
  '6 8 fg=1' \
  '9 11 fg=2' \
  '12 16 fg=3'
# The handler records the command it hands back, so `fsh_chroma` sampling
# still reports that command's handler.
(( ${_fsh_last_commands[(Ie)gh]} )) || {
  builtin print -u2 -r -- "f-sy-h: precommand did not record gh: ${(qqq)_fsh_last_commands}"
  exit 1
}
fsh_assert_exact_regions 'strace -o out.txt gh' \
  '0 6 fg=17' \
  '7 9 fg=4' \
  '10 17 fg=3' \
  '18 20 fg=3'
fsh_assert_exact_regions 'strace -f gh' \
  '0 6 fg=17' \
  '7 9 fg=4' \
  '10 12 fg=3'
# An option value that names a command is still not the command.
fsh_assert_exact_regions 'xargs -I gh gh' \
  '0 5 fg=17' \
  '6 8 fg=4' \
  '9 11 fg=3' \
  '12 14 fg=3'
fsh_assert_exact_regions 'strace -- gh' \
  '0 6 fg=17' \
  '7 9 fg=5' \
  '10 12 fg=1'
# After `--` the next word is the command even when it starts with `-`
# (no `-x` command exists, so it is an unknown token), and the precommand's
# `--` does not turn the options of the command it runs into operands.
fsh_assert_exact_regions 'strace -- -x gh' \
  '0 6 fg=17' \
  '7 9 fg=5' \
  '10 12 fg=8' \
  '13 15 fg=3'
fsh_assert_exact_regions 'strace -- gh pr --state x' \
  '0 6 fg=17' \
  '7 9 fg=5' \
  '10 12 fg=1' \
  '13 15 fg=2' \
  '16 23 fg=5' \
  '24 25 fg=3'
fsh_assert_exact_regions 'systemd-run --unit=x gh' \
  '0 11 fg=17' \
  '12 20 fg=5' \
  '19 20 fg=9' \
  '21 23 fg=1'
fsh_assert_exact_regions 'systemd-run -u name gh' \
  '0 11 fg=17' \
  '12 14 fg=4' \
  '15 19 fg=3' \
  '20 22 fg=3'
# A redirection keeps the search going and is styled as a redirection.
fsh_assert_exact_regions 'nohup 2>/dev/null gh' \
  '0 5 fg=17' \
  '6 8 fg=16' \
  '8 17 fg=7' \
  '18 20 fg=1'
# The alias loop dispatches every alias word; an option inside the alias
# releases the takeover like one typed on the line.
fsh_assert_exact_regions 'st gh' \
  '0 2 fg=11' \
  '3 5 fg=3'
# The case-body bit survives a generic command inside a case item.
fsh_assert_exact_regions 'case x in a) gh pr list ;; esac' \
  '0 4 fg=10' \
  '5 6 fg=12' \
  '7 9 fg=10' \
  '10 11 fg=14' \
  '11 12 fg=13' \
  '13 15 fg=1' \
  '16 18 fg=2' \
  '19 23 fg=3' \
  '24 26 fg=3' \
  '27 31 fg=10'
# The seed runs before the redirection check, and a separator clears the
# takeover while it is still armed; both paths must keep working.
fsh_assert_exact_regions 'gh 2>/dev/null pr list' \
  '0 2 fg=1' \
  '3 5 fg=16' \
  '5 14 fg=7' \
  '15 17 fg=2' \
  '18 22 fg=3'
fsh_assert_exact_regions 'gh && ls' \
  '0 2 fg=1' \
  '3 5 fg=15' \
  '6 8 fg=1'

typeset -ga fsh_test_zle_messages=()
zle() {
  builtin emulate -L zsh
  if [[ $1 == -M ]]; then
    fsh_test_zle_messages+=( "$2" )
    return 0
  fi
  return 1
}
fsh_assert_exact_regions 'scp hostname:123' \
  '0 3 fg=1' \
  '4 16 fg=3'
if (( $#fsh_test_zle_messages )); then
  builtin print -u2 -r -- \
    "f-sy-h: unexpected scp message: ${(qqq)fsh_test_zle_messages}"
  exit 1
fi
unfunction zle

fsh_assert_exact_regions 'scp hostname:123 some/file.lua' \
  '0 3 fg=1' \
  '4 16 fg=3' \
  '17 30 fg=7'
fsh_assert_exact_regions 'scp user@hostname:123 some/file.lua' \
  '0 3 fg=1' \
  '4 21 fg=3' \
  '22 35 fg=7'
fsh_assert_exact_regions 'scp hostname:1234/path some/file.lua' \
  '0 3 fg=1' \
  '4 22 fg=3' \
  '23 36 fg=7'
fsh_assert_exact_regions 'scp -P 2222 hostname:file some/file.lua' \
  '0 3 fg=1' \
  '4 6 fg=4' \
  '12 25 fg=3' \
  '26 39 fg=7'

fsh_assert_exact_regions 'hub issue unknown' \
  '0 3 fg=1' '4 9 fg=2' '10 17 fg=3'
fsh_assert_exact_regions 'lab mr unknown' \
  '0 3 fg=1' '4 6 fg=2' '7 14 fg=3'

# The dispatcher resolves the chroma once per command word, so a later
# command in the same buffer must resolve it again. `zi help; gh pr list`
# switches handler and handler argument, `kubectl ...; git log` switches
# handler, and `k ...; g log` switches through two alias targets. The other
# lines are regression baselines that a stale cache does not change.
fsh_assert_exact_regions 'git commit some/file.lua; zi help' \
  '0 3 fg=1' '4 10 fg=2' '11 24 fg=7' '24 25 fg=15' '26 28 fg=1' '29 33 fg=2'
fsh_assert_exact_regions 'zi help; gh pr list' \
  '0 2 fg=1' '3 7 fg=2' '7 8 fg=15' '9 11 fg=1' '12 14 fg=2' '15 19 fg=3'
fsh_assert_exact_regions 'gh pr list | kubectl get pods' \
  '0 2 fg=1' '3 5 fg=2' '6 10 fg=3' '11 12 fg=15' '13 20 fg=1' '21 24 fg=2' \
  '25 29 fg=3'
fsh_assert_exact_regions 'k get pods; g log some/file.lua' \
  '0 1 fg=11' '2 5 fg=2' '6 10 fg=3' '10 11 fg=15' '12 13 fg=11' '14 17 fg=2' \
  '18 31 fg=7'
fsh_assert_exact_regions 'gh pr list && gh issue list' \
  '0 2 fg=1' '3 5 fg=2' '6 10 fg=3' '11 13 fg=15' '14 16 fg=1' '17 22 fg=2' \
  '23 27 fg=3'
fsh_assert_exact_regions 'kubectl get pods; git log some/file.lua' \
  '0 7 fg=1' '8 11 fg=2' '12 16 fg=3' '16 17 fg=15' '18 21 fg=1' '22 25 fg=2' \
  '26 39 fg=7'

# An end-of-options `--` makes later option-shaped words operands only for
# the command that owns it. Every separator, and a command taken after a
# precommand's `--`, starts a command whose options are options again (#189).
fsh_assert_exact_regions 'gh -- x; ls --all' \
  '0 2 fg=1' '3 5 fg=5' '6 7 fg=3' '7 8 fg=15' '9 11 fg=1' '12 17 fg=5'
fsh_assert_exact_regions 'gh -- --x' \
  '0 2 fg=1' '3 5 fg=5' '6 9 fg=3'
fsh_assert_exact_regions 'ls -- x -a > f --b' \
  '0 2 fg=1' '3 5 fg=5' '6 7 fg=3' '8 10 fg=3' '11 12 fg=16' '13 14 fg=3' \
  '15 18 fg=3'
fsh_assert_exact_regions 'ls -- x && ls -a' \
  '0 2 fg=1' '3 5 fg=5' '6 7 fg=3' '8 10 fg=15' '11 13 fg=1' '14 16 fg=4'
fsh_assert_exact_regions 'ls -- x | ls -a' \
  '0 2 fg=1' '3 5 fg=5' '6 7 fg=3' '8 9 fg=15' '10 12 fg=1' '13 15 fg=4'
fsh_assert_exact_regions $'ls -- x\nls -a' \
  '0 2 fg=1' '3 5 fg=5' '6 7 fg=3' '8 10 fg=1' '11 13 fg=4'
fsh_assert_exact_regions 'command -- ls -a' \
  '0 7 fg=17' '8 10 fg=5' '11 13 fg=1' '14 16 fg=4'
fsh_assert_exact_regions 'sudo -- ls -a' \
  '0 4 fg=17' '5 7 fg=5' '8 10 fg=1' '11 13 fg=4'

if [[ $OSTYPE != darwin* ]]; then
  # Availability and cache outcomes are controlled; no manual database is used.
  command mkdir -p -- "$fixture_root/bin"
  print -r -- $'#!/bin/sh\nexit 1' > "$fixture_root/bin/whatis"
  command chmod 755 "$fixture_root/bin/whatis"
  path=( "$fixture_root/bin" "${path[@]}" )
  rehash
  man() { :; }
  fsh_assert_exact_regions 'man ls' '0 3 fg=1' '4 6 fg=3'
  key="chroma-whatis-${(q)MANPATH}-ls"
  _fsh_state[$key-cache-ready]=1
  _fsh_state[$key-cache]='ls(1) - list files'
  _fsh_state[$key-cache-status]=0
  fsh_assert_exact_regions 'man ls' '0 3 fg=1' '4 6 fg=7'
  _fsh_state[$key-last-status]=7
  fsh_assert_exact_regions 'man ls' '0 3 fg=1' '4 6 fg=7'
  _fsh_state[$key-cache]=
  _fsh_state[$key-cache-status]=16
  fsh_assert_exact_regions 'man ls' '0 3 fg=1' '4 6 fg=6'
fi

fsh_plugin_unload
