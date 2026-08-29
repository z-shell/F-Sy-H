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

docker() { :; }
npm() { :; }
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

fsh_assert_exact_regions 'git commit some/file.lua' \
  '0 3 fg=1' \
  '4 10 fg=2' \
  '11 24 fg=7'

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

fsh_plugin_unload
