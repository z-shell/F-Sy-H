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
# Optional exact upstream source for maintainer verification; never downloaded.
typeset -r upstream_hss=${1:-}
[[ -z $upstream_hss || -r $upstream_hss ]] || exit 2
typeset fixture_home
fixture_home=$(command mktemp -d "${TMPDIR:-/tmp}/fsh-compat-home.XXXXXXXX") || exit 1
trap 'command rm -rf -- "$fixture_home"' EXIT HUP INT TERM

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
  out=$(command env -u FPATH HOME="$fixture_home" ZDOTDIR="$fixture_home" zsh -f -c "
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
out=$(command env -u FPATH HOME="$fixture_home" ZDOTDIR="$fixture_home" zsh -f -c "
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
out=$(command env -u FPATH HOME="$fixture_home" ZDOTDIR="$fixture_home" zsh -f -c "
  builtin source ${(q)plugin_root}/F-Sy-H.plugin.zsh || exit 1
  fsh_plugin_unload 2>/dev/null
  builtin print -r -- \"defined=\${+functions[_zsh_highlight]}\"
" 2>/dev/null)
[[ $out == *'defined=0'* ]] || \
  _fsh_test_fail "unload: expected _zsh_highlight to be gone, got ${out:-<no output>}"

# 5. ... and when something else held the name first, unloading restores that,
#    rather than dropping a function the other plugin is still relying on.
out=$(command env -u FPATH HOME="$fixture_home" ZDOTDIR="$fixture_home" zsh -f -c "
  ${hss_stub}
  builtin source ${(q)plugin_root}/F-Sy-H.plugin.zsh || exit 1
  fsh_plugin_unload 2>/dev/null
  [[ \${functions[_zsh_highlight]-} == *'region_highlight=()'* ]] && \
    builtin print -r -- 'restored=yes'
" 2>/dev/null)
[[ $out == *'restored=yes'* ]] || \
  _fsh_test_fail "unload: expected the pre-existing stub to be restored, \
got ${out:-<no output>}"

# A later replacement must remain external even after lazy lifecycle refreshes.
out=$(command env -u FPATH HOME="$fixture_home" ZDOTDIR="$fixture_home" zsh -f -c "
  builtin source ${(q)plugin_root}/F-Sy-H.plugin.zsh || exit 1
  _zsh_highlight() { builtin print -r -- newer; }
  _fsh_lifecycle_refresh
  fsh_plugin_unload || exit 1
  _zsh_highlight
")
[[ $out == newer ]] || _fsh_test_fail 'unload lost the newer callback'

_fsh_test_interactive_compat() {
  builtin emulate -L zsh
  local order=$1 fixture_root hss_path chunk output= expected
  local pty_name=fsh-compat-$1
  integer deadline
  fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsh-compat.XXXXXXXX") || return 1
  {
    command mkdir -p -- "$fixture_root/home" || return 1
    hss_path=$upstream_hss
    if [[ -z $hss_path ]]; then
      hss_path=$fixture_root/hss.zsh
      # Model the upstream callback detection, redraw and search contracts from
      # zsh-users/zsh-history-substring-search a0bdb0d47dbaba31dba2db7af8c48a5d9c74049a.
      # The optional argument exercises the actual source through the same PTY.
      command cat > "$hss_path" <<'FIXTURE'
if (( ! ${+functions[_zsh_highlight]} )); then
  _zsh_highlight() {
    if [[ $KEYS == [[:print:]] ]]; then
      region_highlight=()
    fi
  }
  compat_hss_redraw() { true && _zsh_highlight; }
  autoload -Uz add-zle-hook-widget
  add-zle-hook-widget line-pre-redraw compat_hss_redraw
fi
_history-substring-search-end() { _zsh_highlight; }
history-substring-search-up() {
  BUFFER='echo history'
  CURSOR=$#BUFFER
  _history-substring-search-end
}
zle -N history-substring-search-up
FIXTURE
    fi
    command cat > "$fixture_root/setup.zsh" <<'SETUP'
PS1='FSH_COMPAT> '
unsetopt prompt_cr prompt_sp
bindkey -e
HISTSIZE=100
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_TIMEOUT=0
zstyle ':fsh:config' work-dir "${COMPAT_READY:h}/work"
if [[ $3 == first ]]; then
  source -- "$1" || return
  source -- "$2" || return
else
  source -- "$2" || return
  source -- "$1" || return
fi
bindkey '^P' history-substring-search-up
# Force the real lazy-refresh path, after HSS has installed its widgets.
fsh_theme default >/dev/null || return
print -s 'echo history'
compat_capture() {
  print -r -- "$BUFFER|${#region_highlight}" >| "$COMPAT_CAPTURE"
}
autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-pre-redraw compat_capture
print -r -- ready >| "$COMPAT_READY"
SETUP
    zmodload zsh/zpty || return 1
    zpty -b "$pty_name" \
      "env -u FPATH HOME=${(q)fixture_root}/home ZDOTDIR=${(q)fixture_root}/home TERM=xterm-256color zsh -f -i" || return 1
    zpty -w "$pty_name" \
      "COMPAT_CAPTURE=${(q)fixture_root}/capture COMPAT_READY=${(q)fixture_root}/ready; source ${(q)fixture_root}/setup.zsh ${(q)plugin_root}/F-Sy-H.plugin.zsh ${(q)hss_path} ${(q)order}"
    deadline=$(( SECONDS + 10 ))
    while [[ ! -f $fixture_root/ready ]] && (( SECONDS < deadline )); do
      zpty -r -t "$pty_name" chunk && output+=$chunk
      command sleep 0.02
    done
    [[ -f $fixture_root/ready ]] || {
      _fsh_test_fail "$order: setup failed: ${(V)output[-1000,-1]}"
      return
    }
    for expected in l ls lsx; do
      zpty -w -n "$pty_name" "${expected[-1]}"
      deadline=$(( SECONDS + 5 ))
      while (( SECONDS < deadline )); do
        zpty -r -t "$pty_name" chunk && output+=$chunk
        [[ -f $fixture_root/capture && $(<"$fixture_root/capture") == "$expected|"[1-9]* ]] && break
        command sleep 0.02
      done
      [[ $(<"$fixture_root/capture") == "$expected|"[1-9]* ]] || {
        _fsh_test_fail "$order: printable input lost highlighting: $expected"
        return
      }
    done
    zpty -w -n "$pty_name" $'\C-Ufsh_plugin_unload; print -r -- unloaded >| "$COMPAT_READY"\n'
    deadline=$(( SECONDS + 5 ))
    while (( SECONDS < deadline )); do
      zpty -r -t "$pty_name" chunk && output+=$chunk
      [[ $(<"$fixture_root/ready") == unloaded ]] && break
      command sleep 0.02
    done
    [[ $(<"$fixture_root/ready") == unloaded ]] || {
      _fsh_test_fail "$order: unload did not finish"
      return
    }
    # Type a query then invoke HSS after unloading only F-Sy-H. Its widget,
    # callback and redraw infrastructure must still work without our functions.
    zpty -w -n "$pty_name" $'echo\C-P'
    deadline=$(( SECONDS + 5 ))
    while (( SECONDS < deadline )); do
      zpty -r -t "$pty_name" chunk && output+=$chunk
      [[ $(<"$fixture_root/capture") == 'echo history|'* ]] && break
      command sleep 0.02
    done
    [[ $(<"$fixture_root/capture") == 'echo history|'* ]] ||
      _fsh_test_fail "$order: history search failed after unload: ${(V)output[-1500,-1]}"
    [[ $output != *'command not found: _zsh_highlight'* && $output != *'No such widget'* ]] ||
      _fsh_test_fail "$order: unload left a missing callback or widget"
  } always {
    (( ${+builtins[zpty]} )) && zpty -d "$pty_name" 2>/dev/null
    command rm -rf -- "$fixture_root"
  }
}

_fsh_test_interactive_compat first || _fsh_test_fail 'F-Sy-H first: PTY setup failed'
_fsh_test_interactive_compat last || _fsh_test_fail 'F-Sy-H last: PTY setup failed'
(( test_status == 0 )) && builtin print -r -- 'zsh-highlight compat: ok'
exit $test_status
