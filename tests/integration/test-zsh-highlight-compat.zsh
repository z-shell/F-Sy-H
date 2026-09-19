#!/usr/bin/env zsh
#
# The _zsh_highlight compatibility entry point.
#
# zsh-history-substring-search installs its own stub under that name when it
# cannot find a syntax highlighter, and the stub empties region_highlight on
# every printable keystroke. It is called from a zle-line-pre-redraw hook, so
# it runs after this plugin has filled region_highlight and the line paints
# with no styles at all. Keeping the old name pointed at the highlighter is
# what stops the stub being installed -- and, when that plugin loaded first,
# what replaces it.

builtin emulate -R zsh
builtin setopt pipe_fail

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
integer test_status=0

_fsh_test_fail() {
  builtin print -u2 -r -- "$1"
  test_status=1
}

# The stub zsh-history-substring-search defines when no highlighter is found.
typeset -r hss_stub='_zsh_highlight() {
  if [[ $KEYS == [[:print:]] ]]; then
    region_highlight=()
  fi
}'

# Drive the highlighter the way the pre-redraw hook does: a printable key, a
# buffer, and a region_highlight that must still hold styles afterwards.
typeset -r exercise='
  typeset -g WIDGET=self-insert BUFFER="echo hi" PREBUFFER= KEYS=i
  typeset -gi CURSOR=7 PENDING=0 REGION_ACTIVE=0
  typeset -ga region_highlight=()
  _zsh_highlight
  builtin print -r -- "regions=${#region_highlight}"
'

_fsh_test_case() {
  local name=$1 preamble=$2 expect=$3 out
  out=$(zsh -f -c "
    ${preamble}
    builtin source ${(q)plugin_root}/F-Sy-H.plugin.zsh || exit 1
    ${exercise}
  " 2>/dev/null) || {
    _fsh_test_fail "$name: the shell exited non-zero"
    return
  }
  [[ $out == *"regions=$expect"* ]] || \
    _fsh_test_fail "$name: expected regions=$expect, got ${out:-<no output>}"
}

# 1. Nothing else in play: the name has to exist and reach the highlighter.
_fsh_test_case 'plain load' '' 1

# 2. zsh-history-substring-search loaded first, so its stub is already bound to
#    the name. Loading after it has to take the name back, or every printable
#    keystroke keeps wiping the styles.
_fsh_test_case 'stub installed first' "$hss_stub" 1

# 3. A real zsh-syntax-highlighting owns this name. Leave it alone: it sets
#    ZSH_HIGHLIGHT_VERSION, which is what distinguishes it from the stub.
out=$(zsh -f -c "
  typeset -g ZSH_HIGHLIGHT_VERSION=0.8.0
  ${hss_stub}
  builtin source ${(q)plugin_root}/F-Sy-H.plugin.zsh || exit 1
  ${exercise}
" 2>/dev/null)
[[ $out == *'regions=0'* ]] || \
  _fsh_test_fail "zsh-syntax-highlighting present: expected its own \
_zsh_highlight to be left in place (regions=0), got ${out:-<no output>}"

# 4. Unloading has to hand the name back. The plugin owns _zsh_highlight only
#    for as long as it is loaded; leaving it behind would point the name at a
#    highlighter that no longer exists.
out=$(zsh -f -c "
  builtin source ${(q)plugin_root}/F-Sy-H.plugin.zsh || exit 1
  fsh_plugin_unload 2>/dev/null
  builtin print -r -- \"defined=\${+functions[_zsh_highlight]}\"
" 2>/dev/null)
[[ $out == *'defined=0'* ]] || \
  _fsh_test_fail "unload: expected _zsh_highlight to be gone, got ${out:-<no output>}"

# 5. ... and when something else held the name first, unloading restores that,
#    rather than dropping a function the other plugin is still relying on.
out=$(zsh -f -c "
  ${hss_stub}
  builtin source ${(q)plugin_root}/F-Sy-H.plugin.zsh || exit 1
  fsh_plugin_unload 2>/dev/null
  [[ \${functions[_zsh_highlight]-} == *'region_highlight=()'* ]] && \
    builtin print -r -- 'restored=yes'
" 2>/dev/null)
[[ $out == *'restored=yes'* ]] || \
  _fsh_test_fail "unload: expected the pre-existing stub to be restored, \
got ${out:-<no output>}"

(( test_status == 0 )) && builtin print -r -- 'zsh-highlight compat: ok'
exit $test_status
