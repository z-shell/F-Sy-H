# Shared exact-region assertion for chroma integration profiles. The caller
# loads the full plugin and supplies an isolated buffer plus expected regions.

fsh_assert_exact_regions() {
  emulate -L zsh
  setopt no_unset

  local buffer=$1
  shift
  local -a expected=( "$@" )

  typeset -g BUFFER=$buffer PREBUFFER=
  typeset -ga reply=()
  _fsh_highlight_process "$PREBUFFER" "$BUFFER" 0 || {
    builtin print -u2 -r -- "f-sy-h: highlighter failed for ${(qqq)buffer}"
    return 1
  }

  if (( $#reply != $#expected )) || [[ ${(F)reply} != ${(F)expected} ]]; then
    builtin print -u2 -r -- "f-sy-h: region mismatch for ${(qqq)buffer}"
    builtin print -u2 -r -- "expected: ${(qqq)expected}"
    builtin print -u2 -r -- "actual:   ${(qqq)reply}"
    return 1
  fi
}
