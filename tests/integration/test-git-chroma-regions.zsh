#!/usr/bin/env zsh

emulate -R zsh

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-git-chroma.XXXXXXXX")
typeset -r fixture_repo=$fixture_root/repo
typeset -r reported_buffer='(cd ../dir; git diff)|patch -p1'
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
typeset -gx _fsh_work_dir=$fixture_root/work
command mkdir -p -- \
  "$ZDOTDIR" \
  "$fixture_repo/some/folder/with/changes" \
  "$fixture_repo/modules/demo"
command touch -- \
  "$fixture_repo/some/file.lua" \
  "$fixture_repo/some/folder/with/changes/changed.lua" \
  "$fixture_repo/tracked.txt"

command git init -q -b main "$fixture_repo"
builtin cd -- "$fixture_repo"
command git add -- some/file.lua some/folder/with/changes/changed.lua tracked.txt
command git -c user.name=Fixture -c user.email=fixture@example.invalid \
  commit -qm fixture
command git branch topic
command git worktree add -q --detach "$fixture_root/existing-worktree"
builtin print -r -- changed >| tracked.txt
command git stash push -qm fixture -- tracked.txt

source "$plugin_root/F-Sy-H.plugin.zsh"
# Test this checkout even when the caller exports another F-Sy-H in FPATH.
fpath=( "$_fsh_base_dir"/{functions,completions,chroma} "${(@)fpath:#$_fsh_base_dir/(functions|completions|chroma)}" )
source "$plugin_root/tests/integration/chroma-fixture.zsh"

_fsh_styles[correct-subtle]=fg=green
_fsh_styles[incorrect-subtle]=fg=red
_fsh_styles[global-alias]=fg=cyan
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
  _fsh_zle_highlight || {
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

fsh_assert_exact_regions 'git switch topic' \
  "0 3 ${_fsh_styles[command]}" \
  "4 10 ${_fsh_styles[subcommand]}" \
  "11 16 ${_fsh_styles[correct-subtle]}" || exit $?
fsh_assert_exact_regions 'git switch missing' \
  "0 3 ${_fsh_styles[command]}" \
  "4 10 ${_fsh_styles[subcommand]}" \
  "11 18 ${_fsh_styles[incorrect-subtle]}" || exit $?
fsh_assert_exact_regions 'git restore tracked.txt' \
  "0 3 ${_fsh_styles[command]}" \
  "4 11 ${_fsh_styles[subcommand]}" \
  "12 23 ${_fsh_styles[correct-subtle]}" || exit $?
fsh_assert_exact_regions 'git restore missing.txt' \
  "0 3 ${_fsh_styles[command]}" \
  "4 11 ${_fsh_styles[subcommand]}" \
  "12 23 ${_fsh_styles[incorrect-subtle]}" || exit $?
fsh_assert_exact_regions 'git stash pop stash@{0}' \
  "0 3 ${_fsh_styles[command]}" \
  "4 9 ${_fsh_styles[subcommand]}" \
  "10 13 ${_fsh_styles[subcommand]}" \
  "14 23 ${_fsh_styles[correct-subtle]}" || exit $?
fsh_assert_exact_regions 'git stash pop missing' \
  "0 3 ${_fsh_styles[command]}" \
  "4 9 ${_fsh_styles[subcommand]}" \
  "10 13 ${_fsh_styles[subcommand]}" \
  "14 21 ${_fsh_styles[incorrect-subtle]}" || exit $?
fsh_assert_exact_regions 'git rebase main topic' \
  "0 3 ${_fsh_styles[command]}" \
  "4 10 ${_fsh_styles[subcommand]}" \
  "11 15 ${_fsh_styles[correct-subtle]}" \
  "16 21 ${_fsh_styles[correct-subtle]}" || exit $?
fsh_assert_exact_regions 'git rebase main missing' \
  "0 3 ${_fsh_styles[command]}" \
  "4 10 ${_fsh_styles[subcommand]}" \
  "11 15 ${_fsh_styles[correct-subtle]}" \
  "16 23 ${_fsh_styles[incorrect-subtle]}" || exit $?
fsh_assert_exact_regions 'git worktree remove ../existing-worktree' \
  "0 3 ${_fsh_styles[command]}" \
  "4 12 ${_fsh_styles[subcommand]}" \
  "13 19 ${_fsh_styles[subcommand]}" \
  "20 40 ${_fsh_styles[correct-subtle]}" || exit $?
fsh_assert_exact_regions 'git worktree remove ../missing-worktree' \
  "0 3 ${_fsh_styles[command]}" \
  "4 12 ${_fsh_styles[subcommand]}" \
  "13 19 ${_fsh_styles[subcommand]}" \
  "20 39 ${_fsh_styles[incorrect-subtle]}" || exit $?
fsh_assert_exact_regions 'git submodule status modules/demo' \
  "0 3 ${_fsh_styles[command]}" \
  "4 13 ${_fsh_styles[subcommand]}" \
  "14 20 ${_fsh_styles[subcommand]}" \
  "21 33 ${_fsh_styles[correct-subtle]}" || exit $?
fsh_assert_exact_regions 'git submodule status modules/missing' \
  "0 3 ${_fsh_styles[command]}" \
  "4 13 ${_fsh_styles[subcommand]}" \
  "14 20 ${_fsh_styles[subcommand]}" \
  "21 36 ${_fsh_styles[incorrect-subtle]}" || exit $?
fsh_assert_exact_regions 'git branch -d topic' \
  "0 3 ${_fsh_styles[command]}" \
  "4 10 ${_fsh_styles[subcommand]}" \
  "11 13 ${_fsh_styles[single-hyphen-option]}" \
  "14 19 ${_fsh_styles[correct-subtle]}" || exit $?
fsh_assert_exact_regions 'git branch -d missing' \
  "0 3 ${_fsh_styles[command]}" \
  "4 10 ${_fsh_styles[subcommand]}" \
  "11 13 ${_fsh_styles[single-hyphen-option]}" \
  "14 21 ${_fsh_styles[incorrect-subtle]}" || exit $?
