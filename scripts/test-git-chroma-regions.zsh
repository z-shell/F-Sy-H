#!/usr/bin/env zsh

emulate -R zsh

typeset -r plugin_root=${0:A:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-git-chroma.XXXXXXXX")
typeset -r fixture_repo=$fixture_root/repo
typeset -r reported_buffer='(cd ../dir; git diff)|patch -p1'
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
typeset -gx FAST_WORK_DIR=$fixture_root/work
command mkdir -p -- \
  "$ZDOTDIR" \
  "$fixture_repo/some/folder/with/changes"
command touch -- \
  "$fixture_repo/some/file.lua" \
  "$fixture_repo/some/folder/with/changes/changed.lua"

source "$plugin_root/F-Sy-H.plugin.zsh"
builtin cd -- "$fixture_repo"

FAST_HIGHLIGHT_STYLES[correct-subtle]=fg=green
FAST_HIGHLIGHT_STYLES[incorrect-subtle]=fg=red
FAST_HIGHLIGHT_STYLES[global-alias]=fg=cyan
alias -g NOOUT='>/dev/null'
alias -g MESSAGE=subject

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

assert_trailing_token_style() {
  emulate -L zsh

  local expected_buffer=$1 expected_style=$2
  local token=${expected_buffer##* }
  local entry
  local -a fields
  integer matching_regions=0
  integer token_start=$(( ${#expected_buffer} - ${#token} ))

  highlight_and_assert "$expected_buffer" || return

  for entry in "${region_highlight[@]}"; do
    fields=( ${(z)entry} )
    (( fields[1] == token_start && fields[2] == ${#expected_buffer} )) || continue
    (( ++matching_regions ))
    [[ ${fields[3]} == "$expected_style" ]] || {
      builtin print -u2 -r -- \
        "unexpected ${fields[3]} region for trailing token in: $expected_buffer"
      return 1
    }
  done

  (( matching_regions == 1 )) || {
    builtin print -u2 -r -- \
      "expected one $expected_style region for trailing token in: $expected_buffer"
    return 1
  }
}

highlight_and_assert "$reported_buffer" || exit $?
assert_trailing_token_style 'git commit some/file.lua' fg=green || exit $?
assert_trailing_token_style 'git commit some/folder/with/changes/' fg=green || exit $?
assert_trailing_token_style 'git commit missing/path/' fg=red || exit $?
assert_trailing_token_style 'git commit --dry-run NOOUT' fg=cyan || exit $?
assert_trailing_token_style 'git commit --dry-run NOOUT missing/path/' fg=red || exit $?
assert_trailing_token_style 'git commit -m MESSAGE missing/path/' fg=red || exit $?
