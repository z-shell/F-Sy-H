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
npm() { :; }
hub() { :; }
lab() { :; }
scp() { :; }
zi() { :; }
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
