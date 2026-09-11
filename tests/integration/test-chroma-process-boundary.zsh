#!/usr/bin/env zsh

builtin emulate -R zsh
builtin setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-process.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM
typeset -gx HOME=$fixture_root ZDOTDIR=$fixture_root XDG_CACHE_HOME=$fixture_root/cache
fpath=( "$plugin_root"/{functions,completions,chroma} "${fpath[@]}" )
source "$plugin_root/F-Sy-H.plugin.zsh"
cd -- "$fixture_root"
print -r -- $'ROOT = /usr\nPREFIX := $(ROOT)/local\n$(PREFIX)/install:\nplain:' > Makefile

typeset -a samples
typeset key command_name BUFFER PREBUFFER=
typeset -a reply
integer auditing=0
for key in ${(k)_fsh_state}; do
  [[ $key == chroma-* && $_fsh_state[$key] == _fsh_chroma_* ]] || continue
  command_name=${key#chroma-}
  samples+=( "$command_name argument" )
done
samples+=(
  'git push origin main' 'git checkout HEAD' 'git checkout missing'
  'git tag -d v1' 'git remote remove origin' 'git branch new-branch'
  'git reset HEAD' 'git log HEAD..main' 'git stash pop stash@{0}'
  'docker image rm deadbeef' 'make /usr/local/install' 'man ls'
)

# DEBUG also runs in native command substitutions. Observing the whole parse
# catches synchronous forks even when no external executable is involved.
TRAPDEBUG() {
  if (( auditing )); then
    local -a words=( ${(z)ZSH_DEBUG_CMD} )
    while [[ ${words[1]-} == [a-zA-Z_][a-zA-Z0-9_]#=* ]]; do
      words[1]=()
    done
    local word=${(Q)words[1]-}
    if (( ZSH_SUBSHELL > 0 )) ||
        [[ $ZSH_DEBUG_CMD == command\ * && $ZSH_DEBUG_CMD != command\ -[vV]\ * ]] ||
        { (( ! ${+builtins[$word]} && ! ${+functions[$word]} )) &&
          { (( ${+commands[$word]} )) || [[ $word == /* && -x $word ]]; }; }; then
      print -r -- "$BUFFER: $ZSH_DEBUG_CMD" >> "$fixture_root/violations"
    fi
  fi
}
_fsh_run_command() { print -r -- 'synchronous command helper' >> "$fixture_root/violations"; }
_fsh_run_git_command() { print -r -- 'synchronous Git helper' >> "$fixture_root/violations"; }
_fsh_highlight_init
for BUFFER in "${samples[@]}"; do
  reply=()
  auditing=1
  _fsh_highlight_process "$PREBUFFER" "$BUFFER" 0
  auditing=0
done
if [[ -s $fixture_root/violations ]]; then
  print -u2 -r -- "$(<"$fixture_root/violations")"
  exit 1
fi
fsh_plugin_unload
