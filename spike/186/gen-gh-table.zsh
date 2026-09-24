#!/usr/bin/env zsh
# Spike fixture for #186: derive a flat gh knowledge table from argv-only
# probes of the installed gh. Offline and once; never on the ZLE path.
#
# Records (associative array, key "<path>|<word>"):
#   s  subcommand         v  option that takes a value
#   b  boolean option     "<path>|>" = 1 when <path> has subcommands
# <path> is the space-joined subcommand path, "" for the root.
#
# Admission follows ADR 0021 item 5: stable locale, constrained token
# grammar, prose ignored. Extensions, aliases and preview launchers are
# recorded as words but never executed.

emulate -R zsh
setopt extended_glob no_unset pipe_fail

export LC_ALL=C
typeset -r out=${1:?usage: gen-gh-table.zsh OUTPUT}
typeset -gA table
typeset -A skip
typeset -i probes=0
typeset ext_line

# Never execute these: extensions run third-party code, `copilot` launches
# another CLI, aliases expand to other commands.
skip=( copilot 1 )
for ext_line in ${(f)"$(command gh extension list 2>/dev/null)"}; do
  [[ $ext_line == (#b)gh\ ([a-z0-9][a-z0-9-]#)$'\t'* ]] && skip[$match[1]]=1
done

# Words below <path>, from `gh __complete <path> ''`.
children() {
  local line
  local -a argv_path=( ${(s: :)1} )
  reply=()
  (( ++probes ))
  for line in ${(f)"$(command gh __complete $argv_path '' 2>/dev/null)"}; do
    [[ $line == :* ]] && continue
    line=${line%%$'\t'*}
    [[ $line == [a-z][a-z0-9-]# ]] || continue
    reply+=( $line )
  done
}

# Option records for <path>, from the FLAGS and INHERITED FLAGS sections of
# `gh <path> --help`.
options() {
  local line section= name short type key
  local -a argv_path=( ${(s: :)1} )
  (( ++probes ))
  for line in ${(f)"$(command gh $argv_path --help 2>&1)"}; do
    case $line in
      (FLAGS|'INHERITED FLAGS') section=1; continue ;;
      ([A-Z]*) section=; continue ;;
    esac
    [[ -n $section ]] || continue
    # "  -L, --limit int   desc", "      --app string   desc", "  -h, --help   desc"
    if [[ $line == (#b)'  '(-([A-Za-z0-9]),' '|'    '|)--([a-z0-9][a-z0-9-]#)(' '([^ ]##)|)'  '* ]]; then
      short=${match[2]} name=${match[3]} type=${match[5]}
      [[ -n $type ]] && type=v || type=b
      key="$1|--$name"; table[$key]=$type
      [[ -n $short ]] && { key="$1|-$short"; table[$key]=$type; }
    fi
  done
}

walk() {
  local p=$1 word key
  local -a words
  options "$p"
  children "$p"
  words=( $reply )
  (( $#words )) || return 0
  key="$p|>"; table[$key]=1
  for word in $words; do
    key="$p|$word"; table[$key]=s
    # `help` and `completion` take topics, not subcommands; skipped words
    # are recorded but never probed.
    (( ${+skip[$word]} )) && continue
    [[ -z $p && $word == (help|completion) ]] && continue
    walk "${p:+$p }$word"
  done
}

# Aliases and extensions show up in the root listing with a marker description.
for ext_line in ${(f)"$(command gh __complete '' 2>/dev/null)"}; do
  [[ $ext_line == (#b)([a-z0-9-]##)$'\t'(Alias for|Extension)' '* ]] && skip[$match[1]]=1
done

walk ""
typeset -p table > $out
print -r -- "probes=$probes records=${#table} skipped=${(j:,:)${(ok)skip}}"
