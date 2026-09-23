#!/usr/bin/env zsh
#
# region_highlight interoperability with zsh-autosuggestions.
#
# Builtin widgets are not wrapped, so the highlighter runs from the
# zle-line-pre-redraw hook: after zsh-autosuggestions' widget wrapper has
# appended the suggestion style behind the buffer. Rebuilding region_highlight
# there used to overwrite the whole array, and the suggestion painted in the
# default foreground on every keystroke (#182). On zsh 5.9 and newer the
# plugin's own entries carry memo=F-Sy-H and a rebuild keeps everything else.
# On zsh 5.8 they are matched by recorded text, and a rebuild keeps foreign
# entries that are memo tagged, P-prefixed, or past the end of BUFFER.

builtin emulate -R zsh
builtin setopt pipe_fail

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
integer test_status=0
# Optional exact upstream source for maintainer verification; never downloaded.
typeset -r upstream_autosuggest=${1:-}
[[ -z $upstream_autosuggest || -r $upstream_autosuggest ]] || exit 2
typeset fixture_home
fixture_home=$(command mktemp -d "${TMPDIR:-/tmp}/fsh-suggest-home.XXXXXXXX") || exit 1
trap 'command rm -rf -- "$fixture_home"' EXIT HUP INT TERM

_fsh_test_fail() {
  builtin print -u2 -r -- "$1"
  test_status=1
}

# Which way the plugin identifies its own entries on this zsh: memo tags
# (5.9 and newer) or recorded text plus position (5.8). Expectations that
# differ between the two are chosen from this.
integer memo_path
memo_path=$(command env -u FPATH HOME="$fixture_home" ZDOTDIR="$fixture_home" zsh -f -c "
  builtin source ${(q)plugin_root}/F-Sy-H.plugin.zsh || exit 1
  builtin print -r -- \$_fsh_region_memo
" 2>/dev/null) || exit 1
[[ $memo_path == (0|1) ]] || exit 1

# Drive the highlighter the way the pre-redraw hook does, with a suggestion
# style already appended behind the buffer, and report what survives. The
# suggestion and foreign fields are (I) subscripts: the position of the last
# matching entry, 0 when there is none.
typeset -r prelude='
  typeset -g WIDGET=self-insert BUFFER="echo hi" PREBUFFER= KEYS=i
  typeset -gi CURSOR=7 PENDING=0 REGION_ACTIVE=0
  typeset -ga region_highlight=()
  _fsh_test_report() {
    builtin print -r -- "regions=${#region_highlight} suggestion=${region_highlight[(I)${1:-7 12 fg=8}]} foreign=${region_highlight[(I)*memo=history-substring-search*]} stale=${region_highlight[(I)1 2 fg=blue]}"
  }
'

_fsh_test_case() {
  local name=$1 script=$2 expect=$3 suggestion=${4:-} out
  out=$(command env -u FPATH HOME="$fixture_home" ZDOTDIR="$fixture_home" zsh -f -c "
    builtin source ${(q)plugin_root}/F-Sy-H.plugin.zsh || exit 1
    ${prelude}
    ${script}
    _fsh_test_report ${(q)suggestion}
  " 2>/dev/null) || {
    _fsh_test_fail "$name: the shell exited non-zero"
    return
  }
  [[ $out == $~expect ]] || \
    _fsh_test_fail "$name: expected ${expect}, got ${out:-<no output>}"
}

# 1. A buffer change rebuilds the styles and keeps the suggestion entry.
_fsh_test_case 'buffer change' '
  region_highlight=( "7 12 fg=8" )
  _fsh_zle_highlight
' 'regions=<2->* suggestion=<1-> foreign=0 stale=0'

# 2. The async chroma callback invalidates the buffer memo to force a repaint.
#    That repaint must not drop the suggestion either, nor duplicate the
#    plugin's own entries.
_fsh_test_case 'stale buffer memo' '
  _fsh_zle_highlight
  integer own=$#region_highlight
  typeset -g _fsh_prior_buffer=
  region_highlight+=( "7 12 fg=8" )
  _fsh_zle_highlight
  (( $#region_highlight == own + 1 )) || region_highlight=()
' 'regions=<2->* suggestion=<1-> foreign=0 stale=0'

# 3. An entry tagged memo= belongs to a plugin that removes it itself
#    (zsh-history-substring-search uses it). An untagged entry inside the
#    buffer is another plugin's on zsh 5.9, where own entries are tagged, and
#    a legacy leftover the highlighter is expected to clear on zsh 5.8.
_fsh_test_case 'foreign entries' '
  region_highlight=( "0 4 fg=red memo=history-substring-search" "1 2 fg=blue" "7 12 fg=8" )
  _fsh_zle_highlight
' "regions=<3->* suggestion=<1-> foreign=<1-> stale=${${memo_path/1/<1->}/0/0}"

# 4. After the buffer shrinks, the plugin's own previous paint lies past the
#    new end of BUFFER. It must go, and only the suggestion may remain there.
_fsh_test_case 'buffer shrink' '
  BUFFER="ls -la /tmp"
  CURSOR=11
  _fsh_zle_highlight
  BUFFER=ls
  CURSOR=2
  region_highlight+=( "2 11 fg=8" )
  _fsh_zle_highlight
  region_highlight=( ${(M)region_highlight:#<2->\ *} )
' 'regions=1 suggestion=1 foreign=0 stale=0' '2 11 fg=8'

# 5. The bracket repaint path rewrites the array as well.
_fsh_test_case 'bracket repaint' '
  BUFFER="echo (hi)"
  CURSOR=9
  _fsh_state[use_brackets]=1
  _fsh_zle_highlight
  region_highlight+=( "9 12 fg=8" )
  CURSOR=5
  _fsh_zle_highlight
' 'regions=<2->* suggestion=<1-> foreign=0 stale=0' '9 12 fg=8'

# 6. zle_highlight decorations are derived from the editor state on every
#    pass: one entry while the region stays active, none once it is gone.
#    The counts are reported through a synthetic entry "<active> <gone> fg=8".
_fsh_test_case 'decoration repaint' '
  typeset -gi MARK=0
  REGION_ACTIVE=1
  _fsh_zle_highlight
  _fsh_zle_highlight
  integer active=${#${(M)region_highlight:#0 7 standout*}}
  REGION_ACTIVE=0
  _fsh_zle_highlight
  integer gone=${#${(M)region_highlight:#0 7 standout*}}
  region_highlight=( "$active $gone fg=8" )
' 'regions=1 suggestion=1 foreign=0 stale=0' '1 0 fg=8'

# 7. Killing the whole line leaves an empty buffer. On zsh 5.8 an untagged
#    leftover starting at 0 is not a POSTDISPLAY decoration and goes with it;
#    on zsh 5.9 it is another plugin's entry and stays.
_fsh_test_case 'empty buffer' '
  _fsh_zle_highlight
  BUFFER=
  CURSOR=0
  region_highlight+=( "0 5 fg=magenta,bold" )
  _fsh_zle_highlight
' "regions=$memo_path suggestion=0 foreign=0 stale=0"

# 8. The P-prefixed form is relative to PREDISPLAY. This plugin never emits
#    it, so such an entry is foreign on either path and survives a rebuild.
_fsh_test_case 'predisplay entry' '
  region_highlight=( "P0 3 fg=red" "7 12 fg=8" )
  _fsh_zle_highlight
  region_highlight=( ${(M)region_highlight:#P*} )
' 'regions=1 suggestion=0 foreign=0 stale=0'

# Wait until the capture hook reports the expected buffer. Reads the caller's
# pty_name, fixture_root, chunk and output, and leaves the line in capture.
_fsh_test_await() {
  local want=$1
  integer deadline=$(( SECONDS + 5 ))
  while (( SECONDS < deadline )); do
    zpty -r -t "$pty_name" chunk && output+=$chunk
    if [[ -f $fixture_root/capture ]]; then
      capture=$(<"$fixture_root/capture")
      [[ $capture == "$want|"* ]] && return 0
    fi
    command sleep 0.02
  done
  return 1
}

# Assert that every entry in the last capture other than the suggestion
# carries the plugin's memo tag. Only meaningful when the memo path is on.
_fsh_test_assert_tagged() {
  local label=$1 entry
  (( tagged )) || return 0
  for entry in ${(s:;:)capture##*|}; do
    [[ $entry == *' fg=8' ]] && continue
    [[ $entry == *memo=F-Sy-H* ]] || {
      _fsh_test_fail "$label: own entry without memo tag: $entry ($capture)"
      return 1
    }
  done
}

# Assert that no entry in the last capture starts at or past the buffer end.
_fsh_test_assert_no_stale() {
  local label=$1 entry
  integer length=$2 stale=0
  local -a fields
  for entry in ${(s:;:)capture##*|}; do
    fields=( ${=entry} )
    [[ ${fields[1]-} == <-> ]] && (( fields[1] >= length )) && (( ++stale ))
  done
  (( stale == 0 )) || {
    _fsh_test_fail "$label: stale paint survived: $capture"
    return 1
  }
}

# $1: load order (first or last). $2: "fallback" forces the zsh 5.8 code path
# so it runs under a real editor on every zsh.
_fsh_test_interactive_compat() {
  builtin emulate -L zsh
  local order=$1 mode=${2:-memo} fixture_root suggest_path chunk output= expected capture canonical
  local -a regions
  # Own entries carry the memo tag only on the memo path; a string compare,
  # since inside (( )) the words would be read as parameter names.
  integer tagged=0
  (( memo_path )) && [[ $mode != fallback ]] && tagged=1
  local pty_name=fsh-suggest-$1-$mode
  integer deadline
  fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsh-suggest.XXXXXXXX") || return 1
  {
    command mkdir -p -- "$fixture_root/home" || return 1
    suggest_path=$upstream_autosuggest
    if [[ -z $suggest_path ]]; then
      suggest_path=$fixture_root/autosuggest.zsh
      # Model the zsh-autosuggestions v0.7.1 widget contract from
      # zsh-users/zsh-autosuggestions 85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5,
      # src/{bind,widgets,highlight}.zsh: the bound widget resets the previous
      # suggestion style, runs the saved original, then appends the style for
      # POSTDISPLAY. The optional argument exercises the actual source instead.
      command cat > "$suggest_path" <<'FIXTURE'
typeset -g _compat_last_highlight=
compat_modify() {
  local original=$1 history_entry='echo history'
  shift
  if [[ -n $_compat_last_highlight ]]; then
    region_highlight=( "${(@)region_highlight:#$_compat_last_highlight}" )
    _compat_last_highlight=
  fi
  POSTDISPLAY=
  zle "$original" -- "$@"
  if [[ -n $BUFFER && $history_entry == "$BUFFER"?* ]]; then
    POSTDISPLAY=${history_entry#$BUFFER}
    _compat_last_highlight="$#BUFFER $(( $#BUFFER + $#POSTDISPLAY )) fg=8"
    region_highlight+=( "$_compat_last_highlight" )
  fi
  zle -R
}
# self-insert and backward-delete-char take the modify action upstream;
# kill-whole-line takes clear, which the empty buffer reduces modify to.
local compat_widget
for compat_widget in self-insert backward-delete-char kill-whole-line; do
  zle -A ".$compat_widget" "compat-orig-$compat_widget"
  functions[compat_bound_$compat_widget]="compat_modify compat-orig-$compat_widget \"\$@\""
  zle -N "$compat_widget" "compat_bound_$compat_widget"
done
FIXTURE
    fi
    command cat > "$fixture_root/setup.zsh" <<'SETUP'
PS1='FSH_SUGGEST> '
unsetopt prompt_cr prompt_sp
bindkey -e
HISTSIZE=100
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
ZSH_AUTOSUGGEST_STRATEGY=( history )
zstyle ':fsh:config' work-dir "${COMPAT_READY:h}/work"
print -s 'echo history'
if [[ $3 == first ]]; then
  source -- "$1" || return
  source -- "$2" || return
else
  source -- "$2" || return
  source -- "$1" || return
fi
# Force the zsh 5.8 code path when asked, after the plugin chose its own.
[[ $4 == fallback ]] && _fsh_region_memo=0
# A style the editor rewrites (attribute before colour): what region_highlight
# reports differs from what the plugin assigned.
_fsh_styles[single-hyphen-option]='bold,fg=cyan'
_fsh_styles[${_fsh_theme_name}single-hyphen-option]='bold,fg=cyan'
# A private name: zsh-autosuggestions wraps every other user widget with its
# modifying action, which would clear POSTDISPLAY before the capture runs.
_compat_capture() {
  print -r -- "$BUFFER|$POSTDISPLAY|${(j:;:)region_highlight}" >| "$COMPAT_CAPTURE"
}
autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-pre-redraw _compat_capture
print -r -- ready >| "$COMPAT_READY"
SETUP
    zmodload zsh/zpty || return 1
    zpty -b "$pty_name" \
      "env -u FPATH HOME=${(q)fixture_root}/home ZDOTDIR=${(q)fixture_root}/home TERM=xterm-256color zsh -f -i" || return 1
    zpty -w "$pty_name" \
      "COMPAT_CAPTURE=${(q)fixture_root}/capture COMPAT_READY=${(q)fixture_root}/ready; source ${(q)fixture_root}/setup.zsh ${(q)plugin_root}/F-Sy-H.plugin.zsh ${(q)suggest_path} ${(q)order} ${(q)mode}"
    deadline=$(( SECONDS + 10 ))
    while [[ ! -f $fixture_root/ready ]] && (( SECONDS < deadline )); do
      zpty -r -t "$pty_name" chunk && output+=$chunk
      command sleep 0.02
    done
    [[ -f $fixture_root/ready ]] || {
      _fsh_test_fail "$order: setup failed: ${(V)output[-1000,-1]}"
      return
    }
    # The upstream plugin binds its wrappers from precmd and fetches
    # suggestions asynchronously: let the first prompt cycle and the first
    # suggestion land before the keystrokes that type through it.
    zpty -w "$pty_name" ''
    command sleep 0.3
    for expected in e ec ech echo; do
      zpty -w -n "$pty_name" "${expected[-1]}"
      deadline=$(( SECONDS + 5 ))
      while (( SECONDS < deadline )); do
        zpty -r -t "$pty_name" chunk && output+=$chunk
        [[ -f $fixture_root/capture && $(<"$fixture_root/capture") == "$expected|"* ]] && break
        command sleep 0.02
      done
      capture=$(<"$fixture_root/capture")
      [[ $capture == "$expected|"* ]] || {
        _fsh_test_fail "$order: no redraw captured for: $expected"
        return
      }
      # The first suggestion may arrive asynchronously after this redraw.
      [[ $expected == e ]] && { command sleep 0.3; continue }
      [[ $capture == "$expected|"?*'|'* ]] || {
        _fsh_test_fail "$order: no suggestion shown for: $expected ($capture)"
        return
      }
      # 'echo history' is 12 characters: the suggestion style spans from the
      # end of the typed prefix to the end of the suggestion.
      regions=( ${(s:;:)capture##*|} )
      (( ${regions[(I)$#expected 12 fg=8]} )) || {
        _fsh_test_fail "$order: suggestion style lost after typing: $expected ($capture)"
        return
      }
      (( $#regions >= 2 )) || {
        _fsh_test_fail "$order: command styles lost after typing: $expected ($capture)"
        return
      }
      _fsh_test_assert_tagged "$order/$mode" || return
    done
    # Shrink with a style the editor rewrites. 'ls -la' paints the option as
    # 'fg=cyan,bold' although 'bold,fg=cyan' was assigned; after deleting back
    # to 'ls' nothing may remain past the end of the buffer.
    zpty -w -n "$pty_name" $'\C-U'
    for expected in l ls 'ls ' 'ls -' 'ls -l' 'ls -la'; do
      zpty -w -n "$pty_name" "${expected[-1]}"
      _fsh_test_await "$expected" || {
        _fsh_test_fail "$order: no redraw captured for: $expected"
        return
      }
    done
    regions=( ${(s:;:)capture##*|} )
    # Either attribute order proves the override is in play; zsh 5.8's
    # canonical order is not pinned here.
    canonical='3 6 (fg=cyan,bold|bold,fg=cyan)*'
    (( ${regions[(I)$canonical]} )) || {
      _fsh_test_fail "$order/$mode: option style not painted as the editor reports it ($capture)"
      return
    }
    _fsh_test_assert_tagged "$order/$mode" || return
    # Each deletion is a rebuild: nothing may remain past the new end.
    for expected in 'ls -l' 'ls -' 'ls ' ls; do
      zpty -w -n "$pty_name" $'\C-?'
      _fsh_test_await "$expected" || {
        _fsh_test_fail "$order/$mode: no redraw captured for: $expected"
        return
      }
      _fsh_test_assert_no_stale "$order/$mode after deleting to '$expected'" $#expected || return
      _fsh_test_assert_tagged "$order/$mode" || return
    done
  } always {
    (( ${+builtins[zpty]} )) && zpty -d "$pty_name" 2>/dev/null
    command rm -rf -- "$fixture_root"
  }
}

_fsh_test_interactive_compat first || _fsh_test_fail 'F-Sy-H first: PTY setup failed'
_fsh_test_interactive_compat last || _fsh_test_fail 'F-Sy-H last: PTY setup failed'
_fsh_test_interactive_compat first fallback || _fsh_test_fail 'F-Sy-H first, 5.8 path: PTY setup failed'
(( test_status == 0 )) && builtin print -r -- 'autosuggest compat: ok'
exit $test_status
