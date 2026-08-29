#!/usr/bin/env zsh

emulate -R zsh

typeset -r plugin_root=${0:A:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-git-chroma.XXXXXXXX")
typeset -r reported_buffer='(cd ../dir; git diff)|patch -p1'
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
typeset -gx FAST_WORK_DIR=$fixture_root/work
command mkdir -p -- "$ZDOTDIR"

source "$plugin_root/F-Sy-H.plugin.zsh"

assert_region_contract() {
  emulate -L zsh
  setopt extended_glob

  local entry
  local -a fields

  (( ${#region_highlight} > 0 )) || {
    builtin print -u2 -r -- 'git chroma produced no highlight regions'
    return 1
  }

  for entry in "${region_highlight[@]}"; do
    fields=( ${(z)entry} )
    (( ${#fields} >= 3 )) || {
      builtin print -u2 -r -- "malformed region_highlight entry: ${(qqq)entry}"
      return 1
    }
    [[ ${fields[1]} == <-> && ${fields[2]} == <-> ]] || {
      builtin print -u2 -r -- "non-numeric region_highlight offsets: ${(qqq)entry}"
      return 1
    }
    (( fields[1] <= fields[2] && fields[2] <= ${#BUFFER} )) || {
      builtin print -u2 -r -- "out-of-range region_highlight entry: ${(qqq)entry}"
      return 1
    }
  done

  return 0
}

highlight_and_assert() {
  emulate -L zsh

  local expected_buffer=$1

  typeset -g BUFFER=$expected_buffer PREBUFFER= WIDGET=self-insert
  typeset -gi CURSOR=${#BUFFER} PENDING=0 REGION_ACTIVE=0
  typeset -gi YANK_ACTIVE=0 ISEARCHMATCH_ACTIVE=0 SUFFIX_ACTIVE=0
  typeset -ga region_highlight=()

  # The highlighter preserves the status of the command that invoked it.
  builtin true
  _zsh_highlight || {
    builtin print -u2 -r -- 'git chroma highlighter returned a failure status'
    return 1
  }

  [[ $BUFFER == "$expected_buffer" ]] || {
    builtin print -u2 -r -- 'git chroma changed the command buffer'
    return 1
  }
  assert_region_contract
}

highlight_and_assert "$reported_buffer" || exit $?
