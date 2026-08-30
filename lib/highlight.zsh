# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------
# Copyright (c) 2010-2016 zsh-syntax-highlighting contributors
# Copyright (c) 2016-2019 Sebastian Gniazdowski (modifications)
# Copyright (c) 2021-present Salvydas Lukosius (modifications)
# All rights reserved.
#
# The only licensing for this file follows.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice, this list of conditions
#    and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice, this list of
#    conditions and the following disclaimer in the documentation and/or other materials provided
#    with the distribution.
#  * Neither the name of the zsh-syntax-highlighting contributors nor the names of its contributors
#    may be used to endorse or promote products derived from this software without specific prior
#    written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# -------------------------------------------------------------------------------------------------

typeset -gA _fsh_command_type_cache _fsh_blocklist_patterns
typeset -g _fsh_work_dir

: ${_fsh_work_dir:=$_fsh_base_dir}
_fsh_work_dir=${~_fsh_work_dir}

() {
  # Emulate zsh options in the current shell.
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob no_short_loops rc_quotes no_auto_pushd
  local -A map
  map=( "CONFIG:" "${XDG_CONFIG_HOME:-$HOME/.config}/f-sy-h/"
        "CACHE:"  "${XDG_CACHE_HOME:-$HOME/.cache}/f-sy-h/"
        "LOCAL:"  "/usr/local/share/f-sy-h/"
        "HOME:" "$HOME/.f-sy-h/"
        "OPT:"  "/opt/local/share/f-sy-h/"
  )
  _fsh_work_dir=${${_fsh_work_dir/(#m)(#s)(CONFIG|CACHE|LOCAL|HOME|OPT):(#c0,1)/${map[${MATCH%:}:]}}%/}
}

# Define default styles. You can set this after loading the plugin in
# Zshrc and use 256 colors via numbers, like: fg=150
typeset -gA _fsh_styles
# Built-in theme.
: ${_fsh_styles[default]:=none}
: ${_fsh_styles[unknown-token]:=fg=red,bold}
: ${_fsh_styles[reserved-word]:=fg=yellow}
: ${_fsh_styles[subcommand]:=fg=yellow}
: ${_fsh_styles[alias]:=fg=green}
: ${_fsh_styles[suffix-alias]:=fg=green}
: ${_fsh_styles[global-alias]:=bg=blue}
: ${_fsh_styles[builtin]:=fg=green}
: ${_fsh_styles[function]:=fg=green}
: ${_fsh_styles[command]:=fg=green}
: ${_fsh_styles[precommand]:=fg=green}
: ${_fsh_styles[commandseparator]:=none}
: ${_fsh_styles[hashed-command]:=fg=green}
: ${_fsh_styles[path]:=fg=magenta}
: ${_fsh_styles[path-to-dir]:=fg=magenta,underline}
: ${_fsh_styles[path_pathseparator]:=}
: ${_fsh_styles[globbing]:=fg=blue,bold}
: ${_fsh_styles[globbing-ext]:=fg=13}
: ${_fsh_styles[history-expansion]:=fg=blue,bold}
: ${_fsh_styles[single-hyphen-option]:=fg=cyan}
: ${_fsh_styles[double-hyphen-option]:=fg=cyan}
: ${_fsh_styles[back-quoted-argument]:=none}
: ${_fsh_styles[single-quoted-argument]:=fg=yellow}
: ${_fsh_styles[double-quoted-argument]:=fg=yellow}
: ${_fsh_styles[dollar-quoted-argument]:=fg=yellow}
: ${_fsh_styles[back-or-dollar-double-quoted-argument]:=fg=cyan}
: ${_fsh_styles[back-dollar-quoted-argument]:=fg=cyan}
: ${_fsh_styles[assign]:=none}
: ${_fsh_styles[redirection]:=none}
: ${_fsh_styles[comment]:=fg=243}
: ${_fsh_styles[variable]:=fg=113}
: ${_fsh_styles[mathvar]:=fg=blue,bold}
: ${_fsh_styles[mathnum]:=fg=magenta}
: ${_fsh_styles[matherr]:=fg=red}
: ${_fsh_styles[assign-array-bracket]:=fg=green}
: ${_fsh_styles[for-loop-variable]:=none}
: ${_fsh_styles[for-loop-operator]:=fg=yellow}
: ${_fsh_styles[for-loop-number]:=fg=magenta}
: ${_fsh_styles[for-loop-separator]:=fg=yellow,bold}
: ${_fsh_styles[here-string-tri]:=fg=yellow}
: ${_fsh_styles[here-string-text]:=bg=18}
: ${_fsh_styles[here-string-var]:=fg=cyan,bg=18}
: ${_fsh_styles[case-input]:=fg=green}
: ${_fsh_styles[case-parentheses]:=fg=yellow}
: ${_fsh_styles[case-condition]:=bg=blue}
: ${_fsh_styles[paired-bracket]:=bg=blue}
: ${_fsh_styles[bracket-level-1]:=fg=green,bold}
: ${_fsh_styles[bracket-level-2]:=fg=yellow,bold}
: ${_fsh_styles[bracket-level-3]:=fg=cyan,bold}
: ${_fsh_styles[single-sq-bracket]:=fg=green}
: ${_fsh_styles[double-sq-bracket]:=fg=green}
: ${_fsh_styles[double-paren]:=fg=yellow}
: ${_fsh_styles[correct-subtle]:=fg=12}
: ${_fsh_styles[incorrect-subtle]:=fg=red}
: ${_fsh_styles[subtle-separator]:=fg=green}
: ${_fsh_styles[subtle-bg]:=bg=18}
: ${_fsh_styles[secondary]:=free}

_fsh_theme_load_data() {
  builtin emulate -L zsh
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

  local file=$1 set_name=${2:-0} key style_key
  local -A theme_data

  _fsh_read_ini "$file" theme_data '' || return
  if (( set_name )) && [[ -n ${theme_data[<theme>_name]-} ]]; then
    typeset -g _fsh_theme_name=${theme_data[<theme>_name]}
  fi
  for key in ${(k)theme_data}; do
    [[ $key == '<styles>_'* ]] || continue
    style_key=${key#'<styles>_'}
    [[ $style_key == [-[:alnum:]_]## ]] || continue
    _fsh_styles[$style_key]=${theme_data[$key]}
  done
}

# Saved theme state is declarative data. Legacy generated .zsh cache files are
# deliberately ignored so loading never executes writable cache content.
typeset -g _fsh_theme_name=
[[ -r $_fsh_work_dir/current_theme.ini ]] &&
  _fsh_theme_load_data "$_fsh_work_dir/current_theme.ini" 1
[[ -r $_fsh_work_dir/theme_overlay.ini ]] &&
  _fsh_theme_load_data "$_fsh_work_dir/theme_overlay.ini" 0

typeset -gA _fsh_token_types

_fsh_token_types=(

  # Precommand

  'builtin'     1
  'command'     1
  'exec'        1
  'nocorrect'   1
  'noglob'      1
  'pkexec'      1 # immune to #121 because it's usually not passed --option flags

  # Control flow
  # Tokens that, at (naively-determined) "command position", are followed by
  # a de jure command position.  All of these are reserved words.

  $'\x7b'   2 # block '{'
  $'\x28'   2 # subshell '('
  '()'      2 # anonymous function
  'while'   2
  'until'   2
  'if'      2
  'then'    2
  'elif'    2
  'else'    2
  'do'      2
  'time'    2
  'coproc'  2
  '!'       2 # reserved word; unrelated to $histchars[1]

  # Command separators

  '|'   3
  '||'  3
  ';'   3
  '&'   3
  '&&'  3
  '|&'  3
  '&!'  3
  '&|'  3
  # ### 'case' syntax, but followed by a pattern, not by a command
  # ';;' ';&' ';|'
)

# A hash instead of multiple globals
typeset -gA _fsh_state

# Brackets highlighter active by default
: ${_fsh_state[use_brackets]:=1}
() {
local -a registry=(
  chroma-fsh_theme    _fsh_chroma_theme
  chroma-alias         _fsh_chroma_alias
  chroma-autoload      _fsh_chroma_autoload
  chroma-autorandr     _fsh_chroma_autorandr
  chroma-docker        _fsh_chroma_docker
  chroma-ionice        _fsh_chroma_ionice
  chroma-make          _fsh_chroma_make
  chroma-nice          _fsh_chroma_nice
  chroma-nmcli         _fsh_chroma_nmcli
  chroma-node          _fsh_chroma_node
  chroma-perl          _fsh_chroma_perl
  chroma-printf        _fsh_chroma_printf
  chroma-ruby          _fsh_chroma_ruby
  chroma-scp           _fsh_chroma_scp
  chroma-ssh           _fsh_chroma_ssh

  chroma-git           _fsh_chroma_main%git
  chroma-hub           _fsh_chroma_hub
  chroma-lab           _fsh_chroma_lab
  chroma-svn           _fsh_chroma_subversion
  chroma-svnadmin      _fsh_chroma_subversion
  chroma-svndumpfilter _fsh_chroma_subversion

  chroma-egrep         _fsh_chroma_grep
  chroma-fgrep         _fsh_chroma_grep
  chroma-grep          _fsh_chroma_grep

  chroma-awk           _fsh_chroma_awk
  chroma-gawk          _fsh_chroma_awk
  chroma-mawk          _fsh_chroma_awk

  chroma-source        _fsh_chroma_source
  chroma-.             _fsh_chroma_source

  chroma-bash          _fsh_chroma_shell
  chroma-fish          _fsh_chroma_shell
  chroma-sh            _fsh_chroma_shell
  chroma-zsh           _fsh_chroma_shell

  chroma--             _fsh_chroma_precommand
  chroma-xargs         _fsh_chroma_precommand
  chroma-nohup         _fsh_chroma_precommand
  chroma-strace        _fsh_chroma_precommand
  chroma-ltrace        _fsh_chroma_precommand

  chroma-hg            _fsh_chroma_subcommand
  chroma-cvs           _fsh_chroma_subcommand
  chroma-pip           _fsh_chroma_subcommand
  chroma-pip2          _fsh_chroma_subcommand
  chroma-pip3          _fsh_chroma_subcommand
  chroma-gem           _fsh_chroma_subcommand
  chroma-bundle        _fsh_chroma_subcommand
  chroma-yard          _fsh_chroma_subcommand
  chroma-cabal         _fsh_chroma_subcommand
  chroma-npm           _fsh_chroma_subcommand
  chroma-pnpm          _fsh_chroma_subcommand
  chroma-nvm           _fsh_chroma_subcommand
  chroma-yarn          _fsh_chroma_subcommand
  chroma-brew          _fsh_chroma_subcommand
  chroma-port          _fsh_chroma_subcommand
  chroma-yum           _fsh_chroma_subcommand
  chroma-dnf           _fsh_chroma_subcommand
  chroma-tmux          _fsh_chroma_subcommand
  chroma-pass          _fsh_chroma_subcommand
  chroma-aws           _fsh_chroma_subcommand
  chroma-apt           _fsh_chroma_subcommand
  chroma-apt-get       _fsh_chroma_subcommand
  chroma-apt-cache     _fsh_chroma_subcommand
  chroma-aptitude      _fsh_chroma_subcommand
  chroma-keyctl        _fsh_chroma_subcommand
  chroma-systemctl     _fsh_chroma_subcommand
  chroma-asciinema     _fsh_chroma_subcommand
  chroma-ipfs          _fsh_chroma_subcommand
  chroma-aspell        _fsh_chroma_subcommand
  chroma-bspc          _fsh_chroma_subcommand
  chroma-cryptsetup    _fsh_chroma_subcommand
  chroma-diskutil      _fsh_chroma_subcommand
  chroma-exercism      _fsh_chroma_subcommand
  chroma-gulp          _fsh_chroma_subcommand
  chroma-i3-msg        _fsh_chroma_subcommand
  chroma-openssl       _fsh_chroma_subcommand
  chroma-solargraph    _fsh_chroma_subcommand
  chroma-subliminal    _fsh_chroma_subcommand
  chroma-travis        _fsh_chroma_subcommand
  chroma-udisksctl     _fsh_chroma_subcommand
  chroma-xdotool       _fsh_chroma_subcommand
  chroma-zmanage       _fsh_chroma_subcommand
  chroma-zsystem       _fsh_chroma_subcommand
  chroma-zypper        _fsh_chroma_subcommand

  chroma-zi            _fsh_chroma_main%zi

  chroma-fpath+=\(     _fsh_chroma_fpath_assignment
  chroma-fpath=\(      _fsh_chroma_fpath_assignment
  chroma-FPATH+=       _fsh_chroma_fpath_assignment
  chroma-FPATH=        _fsh_chroma_fpath_assignment
)

# The whatis chroma probes `whatis`, whose macOS implementation reports
# "nothing appropriate" for every query and cannot drive the highlighter.
# Skip registration there so the registry never advertises an entry the
# platform cannot serve.
if [[ $OSTYPE != darwin* ]]; then
  registry+=(
    chroma-whatis        _fsh_chroma_whatis
    chroma-man           _fsh_chroma_whatis
  )
fi

local -A seen
local key
integer index
for (( index = 1; index <= $#registry; index += 2 )); do
  key=$registry[index]
  if (( ${+seen[$key]} )); then
    builtin print -u2 -r -- "f-sy-h: duplicate chroma registry key: $key"
    return 1
  fi
  seen[$key]=1
done
_fsh_state+=( "${registry[@]}" )
} || return

# Assignments seen, to know if math parameter exists
typeset -gA _fsh_assigns_seen

# Exposing tokens found on command position,
# for other scripts to process
typeset -ga _fsh_last_commands

# Conservative incremental-highlighting state. Checkpoints are emitted by the
# main parser only for complete simple-command prefixes. Anything outside that
# narrow grammar makes the full parser the sole source of highlighting output.
typeset -gi _fsh_incremental_cache_valid=0
typeset -gi _fsh_incremental_collect=0
typeset -gi _fsh_incremental_last_used=0
typeset -gi _fsh_incremental_parse_safe=0
typeset -g _fsh_incremental_buffer=
typeset -g _fsh_incremental_fingerprint=
typeset -g _fsh_incremental_prebuffer=
typeset -ga _fsh_incremental_checkpoints
typeset -ga _fsh_incremental_checkpoint_command_counts
typeset -ga _fsh_incremental_checkpoint_region_counts
typeset -gA _fsh_incremental_command_types
typeset -ga _fsh_incremental_commands
typeset -ga _fsh_incremental_parse_checkpoints
typeset -ga _fsh_incremental_parse_command_counts
typeset -ga _fsh_incremental_parse_region_counts
typeset -ga _fsh_incremental_regions

# Get the type of a command.
#
# Uses the zsh/parameter module if available to avoid forks, and a
# wrapper around 'type -w' as fallback.
#
# Takes a single argument.
#
# The result will be stored in REPLY.
_fsh_highlight_main_type() {
  REPLY=$_fsh_command_type_cache[(e)$1]
  [[ -z $REPLY ]] && {
    if zmodload -e zsh/parameter; then
      if (( $+aliases[(e)$1] )); then
        REPLY=alias
      elif (( ${+galiases[(e)${(Q)1}]} )); then
        REPLY="global alias"
      elif (( $+functions[(e)$1] )); then
        REPLY=function
      elif (( $+builtins[(e)$1] )); then
        REPLY=builtin
      elif (( $+commands[(e)$1] )); then
        REPLY=command
      elif (( $+saliases[(e)${1##*.}] )); then
        REPLY='suffix alias'
      elif (( $reswords[(Ie)$1] )); then
        REPLY=reserved
      # zsh 5.2 and older have a bug whereby running 'type -w ./sudo' implicitly
      # runs 'hash ./sudo=/usr/local/bin/./sudo' (assuming /usr/local/bin/sudo
      # exists and is in $PATH).  Avoid triggering the bug, at the expense of
      # falling through to the $() below, incurring a fork.  (Issue #354.)
      #
      # The second disjunct mimics the isrelative() C call from the zsh bug.
      elif [[ $1 != */* || ${+ZSH_ARGZERO} = "1" ]] && ! builtin type -w -- $1 >/dev/null 2>&1; then
        REPLY=none
      fi
    fi
    [[ -z $REPLY ]] && REPLY="${$(LC_ALL=C builtin type -w -- $1 2>/dev/null)##*: }"
    [[ $REPLY = "none" ]] && {
      [[ -n ${_fsh_blocklist_patterns[(k)${${(M)1:#/*}:-$PWD/$1}]} ]] || {
        [[ -d $1 ]] && REPLY="dirpath" || {
          for cdpath_dir in $cdpath; do
            [[ -d $cdpath_dir/$1 ]] && { REPLY="dirpath"; break; }
          done
        }
      }
    }
    _fsh_command_type_cache[(e)$1]=$REPLY
  }
}

# Below are variables that must be defined in outer
# scope so that they are reachable in *-process()
_fsh_highlight_fill_option_variables() {
  if [[ -o ignore_braces ]] ||
    (( ${+options[ignoreclosebraces]} && options[ignoreclosebraces] )); then
    _fsh_state[right_brace_is_recognised_everywhere]=0
  else
    _fsh_state[right_brace_is_recognised_everywhere]=1
  fi

  if [[ -o path_dirs ]]; then
    _fsh_state[path_dirs_was_set]=1
  else
    _fsh_state[path_dirs_was_set]=0
  fi

  if [[ -o multi_func_def ]]; then
    _fsh_state[multi_func_def]=1
  else
    _fsh_state[multi_func_def]=0
  fi

  if [[ -o interactive_comments ]]; then
    _fsh_state[ointeractive_comments]=1
  else
    _fsh_state[ointeractive_comments]=0
  fi
}



# Main syntax highlighting function.
_fsh_highlight_process() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global bare_glob_qual no_nomatch typeset_silent no_short_loops rc_quotes no_auto_pushd localtraps
  builtin trap '_fsh_lifecycle_refresh' EXIT

  [[ $CONTEXT == "select" ]] && return 0

  (( _fsh_state[path_dirs_was_set] )) && setopt PATH_DIRS
  (( _fsh_state[ointeractive_comments] )) && local interactive_comments= # _set_ to empty

  # Variable declarations and initializations
  # in_array_assignment true between 'a=(' and the matching ')'
  # braces_stack: "R" for round, "Q" for square, "Y" for curly
  # _mybuf, cdpath_dir are used in sub-functions
  local _start_pos=$3 _end_pos __start __end highlight_glob=1 __arg __style in_array_assignment=0 MATCH REPLY expanded_path braces_stack __buf=$1$2 _mybuf __workbuf cdpath_dir active_command alias_target _was_double_hyphen=0 __nul=$'\0' __tmp
  # __arg_type can be 0, 1, 2 or 3, i.e. precommand, control flow, command separator
  # __idx and _end_idx are used in sub-functions
  # for this_word and next_word look below at commented integers and at state machine description
  integer __arg_type=0 MBEGIN MEND in_redirection __len=${#__buf} __PBUFLEN=${#1} already_added offset __idx _end_idx this_word=1 next_word=0 __pos  __asize __delimited=0 itmp iitmp incremental_collect=$_fsh_incremental_collect
  integer chroma_global_alias chroma_reply_count chroma_start_pos chroma_already_added chroma_status
  local -a match mbegin mend __inputs __list

  # This comment explains the numbers:
  # BIT_for - word after reserved-word-recognized `for'
  # BIT_afpcmd - word after a precommand that can take options, like `command' and `exec'
  # integer BIT_start=1 BIT_regular=2 BIT_sudo_opt=4 BIT_sudo_arg=8 BIT_always=16 BIT_for=32 BIT_afpcmd=64
  # integer BIT_chroma=8192

  integer BIT_case_preamble=512 BIT_case_item=1024 BIT_case_nempty_item=2048 BIT_case_code=4096

  # Braces stack
  # T - typeset, local, etc.

  # State machine
  #
  # The states are:
  # - :__start:      Command word
  # - :sudo_opt:   A leading-dash option to sudo (such as "-u" or "-i")
  # - :sudo_arg:   The argument to a sudo leading-dash option that takes one,
  #                when given as a separate word; i.e., "foo" in "-u foo" (two
  #                words) but not in "-ufoo" (one word).
  # - :regular:    "Not a command word", and command delimiters are permitted.
  #                Mainly used to detect premature termination of commands.
  # - :always:     The word 'always' in the «{ foo } always { bar }» syntax.
  #
  # When the kind of a word is not yet known, $this_word / $next_word may contain
  # multiple states.  For example, after "sudo -i", the next word may be either
  # another --flag or a command name, hence the state would include both :__start:
  # and :sudo_opt:.
  #
  # The tokens are always added with both leading and trailing colons to serve as
  # word delimiters (an improvised array); [[ $x == *:foo:* ]] and x=${x//:foo:/}
  # will DTRT regardless of how many elements or repetitions $x has..
  #
  # Handling of redirection: upon seeing a redirection token, we must stall
  # the current state --- that is, the value of $this_word --- for two iterations
  # (one for the redirection operator, one for the word following it representing
  # the redirection target).  Therefore, we set $in_redirection to 2 upon seeing a
  # redirection operator, decrement it each iteration, and stall the current state
  # when it is non-zero.  Thus, upon reaching the next word (the one that follows
  # the redirection operator and target), $this_word will still contain values
  # appropriate for the word immediately following the word that preceded the
  # redirection operator.
  #
  # The "the previous word was a redirection operator" state is not communicated
  # to the next iteration via $next_word/$this_word as usual, but via
  # $in_redirection.  The value of $next_word from the iteration that processed
  # the operator is discarded.
  #

  # Command exposure for other scripts
  _fsh_last_commands=()
  # Restart observing of assigns
  _fsh_assigns_seen=()
  # Restart function's gathering
  _fsh_state[chroma-autoload-elements]=""
  # Restart FPATH elements gathering
  _fsh_state[chroma-fpath_peq-elements]=""
  # Restart svn zi's ICE gathering
  _fsh_state[chroma-zi-ice-elements-svn]=0
  _fsh_state[chroma-zi-ice-elements-id-as]=""

  [[ -n $ZCALC_ACTIVE ]] && {
    (( incremental_collect )) && _fsh_incremental_parse_safe=0
    _start_pos=0; _end_pos=__len; __arg=$__buf
    _fsh_highlight_math_string
    return 0
  }

  # Processing buffer
  local proc_buf=$__buf needle
  for __arg in ${interactive_comments-${(z)__buf}} ${interactive_comments+${(zZ+c+)__buf}}; do

    # Initialize $next_word to its default value?
    (( in_redirection = in_redirection > 0 ? in_redirection - 1 : in_redirection ));
    (( next_word = (in_redirection == 0) ? 2 : next_word )) # else Stall $next_word.
    (( next_word = next_word | (this_word & (BIT_case_code|8192)) ))

    # If we have a good delimiting construct just ending, and '{'
    # occurs, then respect this and go for alternate syntax, i.e.
    # treat '{' (\x7b) as if it's on command position
    [[ $__arg = '{' && $__delimited = 2 ]] && { (( this_word = (this_word & ~2) | 1 )); __delimited=0; }

    __asize=${#__arg}

    # Reset state of working variables
    already_added=0
    __style=${_fsh_theme_name}unknown-token
    (( this_word & 1 )) && { in_array_assignment=0; [[ $__arg == 'noglob' ]] && highlight_glob=0; }

    # Compute the new $_start_pos and $_end_pos, skipping over whitespace in $__buf.
    if [[ $__arg == ';' ]] ; then
      braces_stack=${braces_stack#T}
      __delimited=0

      # Both ; and \n are rendered as a ";" (SEPER) by the ${(z)..} flag.
      needle=$';\n'
      [[ $proc_buf = (#b)[^$needle]#([$needle]##)* ]] && offset=${mbegin[1]}-1
      (( _start_pos += offset ))
      (( _end_pos = _start_pos + __asize ))

      # Prepare next loop cycle
      (( this_word & BIT_case_item )) || { (( in_array_assignment )) && (( this_word = 2 | (this_word & BIT_case_code) )) || { (( this_word = 1 | (this_word & BIT_case_code) )); highlight_glob=1; }; }
      in_redirection=0

      # Chance to highlight ';'
      [[ ${proc_buf[offset+1]} != $'\n' ]] && {
        [[ ${_fsh_styles[${_fsh_theme_name}commandseparator]} != "none" ]] && \
          (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && \
            reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}commandseparator]}")
      }

      proc_buf=${proc_buf[offset + __asize + 1,__len]}
      _start_pos=$_end_pos
      if (( incremental_collect && _fsh_incremental_parse_safe &&
        ! in_array_assignment && this_word == 1 )) && [[ -z $braces_stack ]]; then
        _fsh_incremental_parse_checkpoints+=( $(( _end_pos - __PBUFLEN )) )
        _fsh_incremental_parse_region_counts+=( $#reply )
        _fsh_incremental_parse_command_counts+=( $#_fsh_last_commands )
      fi
      continue
    else
      offset=0
      if [[ $proc_buf = (#b)(#s)(([[:space:]]|\\[[:space:]])##)* ]]; then
          # The first, outer parenthesis
          offset=${mend[1]}
      fi
      (( _start_pos += offset ))
      (( _end_pos = _start_pos + __asize ))

      # No-hit will result in value 0
      __arg_type=${_fsh_token_types[$__arg]}
    fi

    (( this_word & 1 )) && _fsh_last_commands+=( $__arg );

    proc_buf=${proc_buf[offset + __asize + 1,__len]}

    # Handle the INTERACTIVE_COMMENTS option.
    #
    # We use the (Z+c+) flag so the entire comment is presented as one token in $__arg.
    if [[ -n ${interactive_comments+'set'} && $__arg == ${histchars[3]}* ]]; then
      if (( this_word & 3 )); then
        __style=${_fsh_theme_name}comment
      else
        __style=${_fsh_theme_name}unknown-token # prematurely terminated
      fi
      # ADD
      (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[$__style]}")
      _start_pos=$_end_pos
      continue
    fi

    # Redirection?
    [[ $__arg == (<0-9>|)(\<|\>)* && $__arg != (\<|\>)$'\x28'* && $__arg != "<<<" ]] && \
      in_redirection=2

    # Special-case the first word after 'sudo'.
    if (( ! in_redirection )); then
      (( this_word & 4 )) && [[ $__arg != -* ]] && (( this_word = this_word ^ 4 ))

      # Parse the sudo command line
      if (( this_word & 4 )); then
        case $__arg in
          # Flag that requires an argument
          '-'[Cgprtu])
                       (( this_word = this_word & ~1 ))
                       (( next_word = 8 | (this_word & BIT_case_code) ))
                       ;;
          # This prevents misbehavior with sudo -u -otherargument
          '-'*)
                       (( this_word = this_word & ~1 ))
                       (( next_word = next_word | 1 | 4 ))
                       ;;
        esac
      elif (( this_word & 8 )); then
        (( next_word = next_word | 4 | 1 ))
      elif (( this_word & 64 )); then
        [[ $__arg = -[pvV-]## && $active_command = "command" ]] && (( this_word = (this_word & ~1) | 2, next_word = (next_word | 65) & ~2 ))
        [[ $__arg = -[cla-]## && $active_command = "exec" ]] && (( this_word = (this_word & ~1) | 2, next_word = (next_word | 65) & ~2 ))
        [[ $__arg = \{[a-zA-Z_][a-zA-Z0-9_]#\} && $active_command = "exec" ]] && {
          # Highlight {descriptor} passed to exec
          (( this_word = (this_word & ~1) | 2, next_word = (next_word | 65) & ~2 ))
          (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}exec-descriptor]}")
          already_added=1
        }
      fi
   fi

   if (( this_word & 8192 )); then
     (( incremental_collect )) && _fsh_incremental_parse_safe=0
     __list=( ${(z@)${aliases[$active_command]:-${active_command##*/}}##[[:space:]]#(command|builtin|exec|noglob|nocorrect|pkexec)[[:space:]]#} )
     (( chroma_global_alias = ${+galiases[(e)${(Q)__arg}]} ))
     if (( chroma_global_alias )); then
       # Preserve chroma parser state, but let the generic path style global aliases.
       (( chroma_reply_count = ${#reply}, chroma_start_pos = _start_pos,
          chroma_already_added = already_added ))
     fi
     ${${_fsh_state[chroma-${__list[1]}]}%\%*} ${(M)_fsh_state[chroma-${__list[1]}]%\%*} 0 "$__arg" $_start_pos $_end_pos 2>/dev/null
     chroma_status=$?
     if (( chroma_global_alias )); then
       (( ${#reply} > chroma_reply_count )) && reply[$(( chroma_reply_count + 1 )),-1]=()
       (( _start_pos = chroma_start_pos, already_added = chroma_already_added ))
     elif (( chroma_status == 0 )); then
       continue
     fi
   fi

   (( this_word & 1 )) && {
     # !in_redirection needed particularly for exec {A}>b {C}>d
     (( !in_redirection )) && active_command=$__arg
     _mybuf=${${aliases[$active_command]:-${active_command##*/}}##[[:space:]]#(command|builtin|exec|noglob|nocorrect|pkexec)[[:space:]]#}
     [[ "$_mybuf" = (#b)(FPATH+(#c0,1)=)* ]] && _mybuf="${match[1]} ${(j: :)${(s,:,)${_mybuf#FPATH+(#c0,1)=}}}"
     [[ -n ${_fsh_state[chroma-${_mybuf%% *}]} ]] && {
       (( incremental_collect )) && _fsh_incremental_parse_safe=0
       __list=( ${(z@)_mybuf} )
       if (( ${#__list} > 1 )) || [[ $active_command != $_mybuf ]]; then
         __style=${_fsh_theme_name}alias
         (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[$__style]}")

         ${${_fsh_state[chroma-${__list[1]}]}%\%*} ${(M)_fsh_state[chroma-${__list[1]}]%\%*} 1 "${__list[1]}" "-100000" $_end_pos 2>/dev/null || \
           (( this_word = next_word, next_word = 2 ))

         for _mybuf in "${(@)__list[2,-1]}"; do
           (( next_word = next_word | (this_word & (BIT_case_code|8192)) ))
           ${${_fsh_state[chroma-${__list[1]}]}%\%*} ${(M)_fsh_state[chroma-${__list[1]}]%\%*} 0 "$_mybuf" "-100000" $_end_pos 2>/dev/null || \
             (( this_word = next_word, next_word = 2 ))
         done

         # This might have been done multiple times in chroma, but
         # as _end_pos doesn't change, it can be done one more time
         _start_pos=$_end_pos

         continue
       else
         ${${_fsh_state[chroma-${__list[1]}]}%\%*} ${(M)_fsh_state[chroma-${__list[1]}]%\%*} 1 "$__arg" $_start_pos $_end_pos 2>/dev/null && continue
       fi
     } || (( 1 ))
  }

  expanded_path=""

  # The Great Fork: is this a command word?  Is this a non-command word?
  if (( this_word & 16 )) && [[ $__arg == 'always' ]]; then
    # try-always construct
    __style=${_fsh_theme_name}reserved-word # de facto a reserved word, although not de jure
    (( next_word = 1 | (this_word & BIT_case_code) ))
  elif (( (this_word & 1) && (in_redirection == 0) )) || [[ $braces_stack = T* ]]; then # T - typedef, etc.
    if (( __arg_type == 1 )); then
      (( incremental_collect )) && _fsh_incremental_parse_safe=0
      __style=${_fsh_theme_name}precommand
      [[ $__arg = "command" || $__arg = "exec" ]] && (( next_word = next_word | 64 ))
    elif [[ $__arg = (sudo|doas) ]]; then
      (( incremental_collect )) && _fsh_incremental_parse_safe=0
      __style=${_fsh_theme_name}precommand
      (( next_word = (next_word & ~2) | 4 | 1 ))
    else
      _mybuf=${${(Q)__arg}#\"}
      if (( ${+parameters} )) && \
          [[ $_mybuf = (#b)(*)(*)\$([a-zA-Z_][a-zA-Z0-9_]#|[0-9]##)(*) || \
            $_mybuf = (#b)(*)(*)\$\{([a-zA-Z_][a-zA-Z0-9_:-]#|[0-9]##)(*) ]] && \
              (( ${+parameters[${match[3]%%:-*}]} ))
      then
        _fsh_highlight_main_type ${match[1]}${match[2]}${(P)match[3]%%:-*}${match[4]#\}}
      elif [[ $braces_stack = T* ]]; then # T - typedef, etc.
        REPLY=none
      else
        : ${expanded_path::=${~_mybuf}}
        _fsh_highlight_main_type $expanded_path
      fi

      case $REPLY in
        reserved)       # reserved word
          (( incremental_collect )) && _fsh_incremental_parse_safe=0
          [[ $__arg = "[[" ]] && __style=${_fsh_theme_name}double-sq-bracket || __style=${_fsh_theme_name}reserved-word
          if [[ $__arg == $'\x7b' ]]; then # Y - '{'
            braces_stack='Y'$braces_stack

          elif [[ $__arg == $'\x7d' && $braces_stack = Y* ]]; then # Y - '}'
            # We're at command word, so no need to check right_brace_is_recognised_everywhere
            braces_stack=${braces_stack#Y}
            __style=${_fsh_theme_name}reserved-word
            (( next_word = next_word | 16 ))

          elif [[ $__arg == "[[" ]]; then  # A - [[
            braces_stack='A'$braces_stack

            # Counting complex brackets (for brackets-highlighter): 1. [[ as command
            _fsh_complex_brackets+=( $(( _start_pos-__PBUFLEN )) $(( _start_pos-__PBUFLEN + 1 )) )
          elif [[ $__arg == "for" ]]; then
            (( next_word = next_word | 32 )) # BIT_for

          elif [[ $__arg == "case" ]]; then
            (( next_word = BIT_case_preamble ))

          elif [[ $__arg = (typeset|declare|local|float|integer|export|readonly) ]]; then
            braces_stack='T'$braces_stack
          fi
        ;;
        'suffix alias')
          (( incremental_collect )) && _fsh_incremental_parse_safe=0
          __style=${_fsh_theme_name}suffix-alias
          ;;
        'global alias')
          (( incremental_collect )) && _fsh_incremental_parse_safe=0
          __style=${_fsh_theme_name}global-alias
          ;;
        alias)
          (( incremental_collect )) && _fsh_incremental_parse_safe=0
          if [[ $__arg = ?*'='* ]]; then
            # The so called (by old code) "insane_alias"
            __style=${_fsh_theme_name}unknown-token
          else
            __style=${_fsh_theme_name}alias
            (( ${+aliases} )) && alias_target=${aliases[$__arg]} || alias_target="${"$(alias -- $__arg)"#*=}"
            [[ ${_fsh_token_types[$alias_target]} = "1" && $__arg_type != "1" ]] && _fsh_token_types[$__arg]="1"
          fi
        ;;
        builtin)
          [[ $__arg = "[" ]] && {
            __style=${_fsh_theme_name}single-sq-bracket
            _fsh_complex_brackets+=( $(( _start_pos-__PBUFLEN )) )
          } || __style=${_fsh_theme_name}builtin
          # T - typeset, etc. mode
          [[ $__arg = (typeset|declare|local|float|integer|export|readonly) ]] && braces_stack='T'$braces_stack
          [[ $__arg = eval ]] && (( next_word = next_word | 256 ))
        ;;
        function)       __style=${_fsh_theme_name}function;;
        command)        __style=${_fsh_theme_name}command;;
        hashed)         __style=${_fsh_theme_name}hashed-command;;
        dirpath)        __style=${_fsh_theme_name}path-to-dir;;
        none)           # Assign?
          if [[ $__arg == [a-zA-Z_][a-zA-Z0-9_]#(|\[[^\]]#\])(|[^\]]#\])(|[+])=* || $__arg == [0-9]##(|[+])=* || ( $braces_stack = T* && ${__arg_type} != 3 ) ]] {
            __style=${_fsh_theme_name}assign
            _fsh_assigns_seen[${__arg%%=*}]=1

            # Handle array assignment
            [[ $__arg = (#b)*=(\()*(\))* || $__arg = (#b)*=(\()* ]] && {
              (( __start=_start_pos-__PBUFLEN+${mbegin[1]}-1, __end=__start+1, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}assign-array-bracket]}")
              # Counting complex brackets (for brackets-highlighter): 2. ( in array assign
              _fsh_complex_brackets+=( $__start )
              (( mbegin[2] >= 1 )) && {
                (( __start=_start_pos-__PBUFLEN+${mbegin[2]}-1, __end=__start+1, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}assign-array-bracket]}")
                # Counting complex brackets (for brackets-highlighter): 3a. ) in array assign
                _fsh_complex_brackets+=( $__start )
              } || in_array_assignment=1
            } || { [[ ${braces_stack[1]} != 'T' ]] && (( next_word = (next_word | 1) & ~2 )); }

            # Handle no-string highlight, string "/' highlight, math mode highlight
            local ctmp="\"" dtmp="'"
            itmp=${__arg[(i)$ctmp]}-1 iitmp=${__arg[(i)$dtmp]}-1
            integer jtmp=${__arg[(b:itmp+2:i)$ctmp]} jjtmp=${__arg[(b:iitmp+2:i)$dtmp]}
            (( itmp < iitmp && itmp <= __asize - 1 )) && (( jtmp > __asize && (jtmp = __asize), 1 > 0 )) && \
            (( __start=_start_pos-__PBUFLEN+itmp, __end=_start_pos-__PBUFLEN+jtmp, __start >= 0 )) && \
            reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}double-quoted-argument]}") && \
            { itmp=${__arg[(i)=]}; __arg=${__arg[itmp,__asize]}; (( _start_pos += itmp - 1 )); _fsh_highlight_string; \
            (( _start_pos = _start_pos - itmp + 1, 1 > 0 )); } || \
            { (( iitmp <= __asize - 1 )) && (( jjtmp > __asize && (jjtmp = __asize), 1 > 0 )) && \
            (( __start=_start_pos-__PBUFLEN+iitmp, __end=_start_pos-__PBUFLEN+jjtmp, __start >= 0 )) && \
            reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}single-quoted-argument]}")
            } || {
              itmp=${__arg[(i)=]}; __arg=${__arg[itmp,__asize]}; (( _start_pos += itmp - 1 ));
              [[ ${__arg[2,4]} = '$((' ]] && {
                _fsh_highlight_math_string; (( __start=_start_pos-__PBUFLEN+2, __end=__start+2, __start >= 0 )) && \
                reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}double-paren]}")
                # Counting complex brackets (for brackets-highlighter): 4. $(( in assign argument
                _fsh_complex_brackets+=( $__start $(( __start + 1 )) )
                (( jtmp = ${__arg[(I)\)\)]}-1, jtmp > 0 )) && {
                  (( __start=_start_pos-__PBUFLEN+jtmp, __end=__start+2, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}double-paren]}")
                  # Counting complex brackets (for brackets-highlighter): 5. )) in assign argument
                  _fsh_complex_brackets+=( $__start $(( __start + 1 )) )
                }
              } || _fsh_highlight_string; (( _start_pos = _start_pos - itmp + 1, 1 > 0 ))
            }
          } elif [[ $__arg = ${histchars[1]}* && -n ${__arg[2]} ]] {
            __style=${_fsh_theme_name}history-expansion

          } elif [[ $__arg == ${histchars[2]}* ]] {
            __style=${_fsh_theme_name}history-expansion

          } elif (( __arg_type == 3 )) {
            # This highlights empty commands (semicolon follows nothing) as an error.
            # Zsh accepts them, though.
            (( this_word & 3 )) && __style=${_fsh_theme_name}commandseparator

          } elif [[ $__arg[1,2] == '((' ]] {
            # Arithmetic evaluation.
            #
            # Note: prior to zsh-5.1.1-52-g4bed2cf (workers/36669), the ${(z)...}
            # splitter would only output the '((' token if the matching '))' had
            # been typed.  Therefore, under those versions of zsh, BUFFER="(( 42"
            # would be highlighted as an error until the matching "))" are typed.
            #
            # We highlight just the opening parentheses, as a reserved word; this
            # is how [[ ... ]] is highlighted, too.

            # ADD
            (( __start=_start_pos-__PBUFLEN, __end=__start+2, __start >= 0 )) && \
            reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}double-paren]}")
            already_added=1

            # Counting complex brackets (for brackets-highlighter): 6. (( as command
            _fsh_complex_brackets+=( $__start $(( __start + 1 )) )
            _fsh_highlight_math_string

            # ADD
            [[ $__arg[-2,-1] == '))' ]] && {
              (( __start=_end_pos-__PBUFLEN-2, __end=__start+2, __start >= 0 )) && \
              reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}double-paren]}")
              (( __delimited = __delimited ? 2 : __delimited ))
              # Counting complex brackets (for brackets-highlighter): 7. )) for as-command ((
              _fsh_complex_brackets+=( $__start $(( __start + 1 )) )
            }
          } elif [[ $__arg == '()' ]] {
            _fsh_complex_brackets+=( $(( _start_pos-__PBUFLEN )) $(( _start_pos-__PBUFLEN + 1 )) )
            # anonymous function
            __style=${_fsh_theme_name}reserved-word
          } elif [[ $__arg == $'\x28' ]] {
            # subshell '(', stack: letter 'R'
            __style=${_fsh_theme_name}reserved-word
            braces_stack='R'$braces_stack
          } elif [[ $__arg == $'\x29' ]] {
            # ')', stack: letter 'R' for subshell
            [[ $braces_stack = R* ]] && { braces_stack=${braces_stack#R}; __style=${_fsh_theme_name}reserved-word; }
          } elif (( this_word & 14 )) {
            __style=${_fsh_theme_name}default
          } elif [[ $__arg = (';;'|';&'|';|') ]] && (( this_word & BIT_case_code )) {
            (( next_word = (next_word | BIT_case_item) & ~(BIT_case_code+3) ))
              __style=${_fsh_theme_name}default
          } elif [[ $__arg = \$\([^\(]* ]] {
            already_added=1
          }
        ;;
        *)
          # ADD
          # (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end commandtypefromthefuture-$REPLY")
          already_added=1
        ;;
      esac
    fi
  # in_redirection || BIT_regular || BIT_sudo_opt || BIT_sudo_arg
  elif (( in_redirection + this_word & 14 ))
  then # $__arg is a non-command word
      case $__arg in
        ']]')
                 # A - [[
                 [[ $braces_stack = A* ]] && {
                   __style=${_fsh_theme_name}double-sq-bracket
                   (( __delimited = __delimited ? 2 : __delimited ))
                   # Counting complex brackets (for brackets-highlighter): 8a. ]] for as-command [[
                   _fsh_complex_brackets+=( $(( _start_pos-__PBUFLEN )) $(( _start_pos-__PBUFLEN+1 )) )
                 } || {
                   [[ $braces_stack = *A* ]] && {
                      __style=${_fsh_theme_name}unknown-token
                      # Counting complex brackets (for brackets-highlighter): 8b. ]] for as-command [[
                      _fsh_complex_brackets+=( $(( _start_pos-__PBUFLEN )) $(( _start_pos-__PBUFLEN+1 )) )
                   } || __style=${_fsh_theme_name}default
                 }
                 braces_stack=${braces_stack#A}
                 ;;
        ']')
                 __style=${_fsh_theme_name}single-sq-bracket
                 _fsh_complex_brackets+=( $(( _start_pos-__PBUFLEN )) )
                 ;;
        $'\x28')
                 # '(' inside [[
                 __style=${_fsh_theme_name}reserved-word
                 braces_stack='R'$braces_stack
                 ;;
        $'\x29') # ')' - subshell or end of array assignment
                 if (( in_array_assignment )); then
                   in_array_assignment=0
                   (( next_word = next_word | 1 ))
                   (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}assign-array-bracket]}")
                   already_added=1
                   # Counting complex brackets (for brackets-highlighter): 3b. ) in array assign
                   _fsh_complex_brackets+=( $__start )
                 elif [[ $braces_stack = R* ]]; then
                   braces_stack=${braces_stack#R}
                   __style=${_fsh_theme_name}reserved-word
                 # Zsh doesn't tokenize final ) if it's just single ')',
                 # but logically what's below is correct, so it is kept
                 # in case Zsh will be changed / fixed, etc.
                 elif [[ $braces_stack = F* ]]; then
                   __style=${_fsh_theme_name}builtin
                 fi
                 ;;
        $'\x28\x29') # '()' - possibly a function definition
                 # || false # TODO: or if the previous word was a command word
                 (( _fsh_state[multi_func_def] )) && (( next_word = next_word | 1 ))
                 __style=${_fsh_theme_name}reserved-word
                 _fsh_complex_brackets+=( $(( _start_pos-__PBUFLEN )) $(( _start_pos-__PBUFLEN + 1 )) )
                 # Remove possible annoying unknown-token __style, or misleading function __style
                 reply[-1]=()
                 _fsh_command_type_cache[$active_command]="function"
                 ;;
        '--'*)   [[ $__arg == "--" ]] && { _was_double_hyphen=1; __style=${_fsh_theme_name}double-hyphen-option; } || {
                   (( !_was_double_hyphen )) && {
                     [[ "$__arg" = (#b)(--[a-zA-Z0-9_]##)=(*) ]] && {
                       (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && \
                         reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}double-hyphen-option]}")
                       (( __start=_start_pos-__PBUFLEN+1+mend[1], __end=_end_pos-__PBUFLEN, __start >= 0 )) && \
                        reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}optarg-${${${(M)match[2]:#<->}:+number}:-string}]}")
                       already_added=1
                     } || __style=${_fsh_theme_name}double-hyphen-option
                   } || __style=${_fsh_theme_name}default
                 }
                 ;;
        '-'*)    (( !_was_double_hyphen )) && __style=${_fsh_theme_name}single-hyphen-option || __style=${_fsh_theme_name}default;;
        \$\'*)
                 (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}dollar-quoted-argument]}")
                 _fsh_highlight_dollar_string
                 already_added=1
                 ;;
        [\"\']*|[^\"\\]##([\\][\\])#\"*|[^\'\\]##([\\][\\])#\'*)
                 # 256 is eval-mode
                 if (( this_word & 256 )) && [[ $__arg = [\'\"]* ]]; then
                   (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && \
                     reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}recursive-base]}")
                   if [[ -n ${_fsh_styles[${_fsh_theme_name}secondary]} ]]; then
                     __idx=1
                     _mybuf=$_fsh_theme_name
                     _fsh_theme_name=${${${_fsh_styles[${_fsh_theme_name}secondary]}:t:r}#(CONFIG|CACHE|LOCAL|HOME|OPT):}
                     (( ${+_fsh_styles[${_fsh_theme_name}default]} )) || {
                       [[ -r $_fsh_work_dir/secondary_theme.local.ini ]] && \
                         _fsh_theme_load_data "$_fsh_work_dir/secondary_theme.local.ini" 0 || \
                         _fsh_theme_load_data "$_fsh_base_dir/share/free_theme.ini" 0
                     }
                   else
                     __idx=0
                   fi
                   (( _start_pos-__PBUFLEN >= 0 )) && \
                     _fsh_highlight_process "$PREBUFFER" "${${__arg%[\'\"]}#[\'\"]}" $(( _start_pos + 1 ))
                   (( __idx )) && _fsh_theme_name=$_mybuf
                   already_added=1
                 else
                   [[ $__arg = *([^\\][\#][\#]|"(#b)"|"(#B)"|"(#m)"|"(#c")* && $highlight_glob -ne 0 ]] && \
                     (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && \
                       reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}globbing-ext]}")
                   # Reusing existing vars, treat this code like C++ STL
                   # header, full of underscores and unhelpful var names
                   itmp=0 __workbuf=$__arg __tmp="" cdpath_dir=$__arg
                   while [[ $__workbuf = (#b)[^\"\'\\]#(([\"\'])|[\\](*))(*) ]]; do
                     [[ -n ${match[3]} ]] && {
                       itmp+=${mbegin[1]}
                       # Optionally skip 1 quoted char
                       [[ $__tmp = \' ]] && __workbuf=${match[3]} || { itmp+=1; __workbuf=${match[3]:1}; }
                     } || {
                       itmp+=${mbegin[1]}
                       __workbuf=${match[4]}
                       # Toggle quoting
                       [[ ( ${match[1]} = \" && $__tmp != \' ) || ( ${match[1]} = \' && $__tmp != \" ) ]] && {
                         [[ $__tmp = [\"\'] ]] && {
                           # End of quoting
                           (( __start=_start_pos-__PBUFLEN+iitmp-1, __end=_start_pos-__PBUFLEN+itmp, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}${${${__tmp#\'}:+double-quoted-argument}:-single-quoted-argument}]}")
                           already_added=1

                           [[ $__tmp = \" ]] && {
                             __arg=${cdpath_dir[iitmp+1,itmp-1]}
                             (( _start_pos += iitmp - 1 + 1 ))
                             _fsh_highlight_string
                             (( _start_pos = _start_pos - iitmp + 1 - 1 ))
                           }
                           # The end-of-quoting proper algorithm action
                           __tmp=
                         } || {
                           # Beginning of quoting
                           iitmp=itmp
                           # The beginning-of-quoting proper algorithm action
                           __tmp=${match[1]}
                         }
                       }
                     }
                   done
                   [[ $__tmp = [\"\'] ]] && {
                     (( __start=_start_pos-__PBUFLEN+iitmp-1, __end=_start_pos-__PBUFLEN+__asize, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}${${${__tmp#\'}:+double-quoted-argument}:-single-quoted-argument}]}")
                     already_added=1

                     [[ $__tmp = \" ]] && {
                       __arg=${cdpath_dir[iitmp+1,__asize]}
                       (( _start_pos += iitmp - 1 + 1 ))
                       _fsh_highlight_string
                       (( _start_pos = _start_pos - iitmp + 1 - 1 ))
                     }
                   }
                 fi
                 ;;
        \$\(\(*)
                 already_added=1
                 _fsh_highlight_math_string
                 # ADD
                 (( __start=_start_pos-__PBUFLEN+1, __end=__start+2, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}double-paren]}")
                 # Counting complex brackets (for brackets-highlighter): 9. $(( as argument
                 _fsh_complex_brackets+=( $__start $(( __start + 1 )) )
                 # ADD
                 [[ $__arg[-2,-1] == '))' ]] && (( __start=_end_pos-__PBUFLEN-2, __end=__start+2, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}double-paren]}")
                 # Counting complex brackets (for brackets-highlighter): 10. )) for as-argument $((
                 _fsh_complex_brackets+=( $__start $(( __start + 1 )) )
                 ;;
        '`'*)
                 (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && \
                   reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}back-quoted-argument]}")
                 if [[ -n ${_fsh_styles[${_fsh_theme_name}secondary]} ]]; then
                   __idx=1
                   _mybuf=$_fsh_theme_name
                   _fsh_theme_name=${${${_fsh_styles[${_fsh_theme_name}secondary]}:t:r}#(CONFIG|CACHE|LOCAL|HOME|OPT):}
                   (( ${+_fsh_styles[${_fsh_theme_name}default]} )) || {
                     [[ -r $_fsh_work_dir/secondary_theme.local.ini ]] && \
                       _fsh_theme_load_data "$_fsh_work_dir/secondary_theme.local.ini" 0 || \
                       _fsh_theme_load_data "$_fsh_base_dir/share/free_theme.ini" 0
                   }
                 else
                   __idx=0
                 fi
                 (( _start_pos-__PBUFLEN >= 0 )) && \
                   _fsh_highlight_process "$PREBUFFER" "${${__arg%[\`]}#[\`]}" $(( _start_pos + 1 ))
                 (( __idx )) && _fsh_theme_name=$_mybuf
                 already_added=1
          ;;
        '((')    # 'F' - (( after for
                 (( this_word & 32 )) && {
                   braces_stack='F'$braces_stack
                   __style=${_fsh_theme_name}double-paren
                   # Counting complex brackets (for brackets-highlighter): 11. (( as for-syntax
                   _fsh_complex_brackets+=( $(( _start_pos-__PBUFLEN )) $(( _start_pos-__PBUFLEN+1 )) )
                   # This is set after __arg_type == 2, and also here,
                   # when another alternate-syntax capable command occurs
                   __delimited=1
                 }
                 ;;
        '))')    # 'F' - (( after for
                 [[ $braces_stack = F* ]] && {
                   braces_stack=${braces_stack#F}
                   __style=${_fsh_theme_name}double-paren
                   # Counting complex brackets (for brackets-highlighter): 12. )) as for-syntax
                   _fsh_complex_brackets+=( $(( _start_pos-__PBUFLEN )) $(( _start_pos-__PBUFLEN+1 )) )
                   (( __delimited = __delimited ? 2 : __delimited ))
                 }
                 ;;
        '<<<')
                 (( next_word = (next_word | 128) & ~3 ))
                 [[ ${_fsh_styles[${_fsh_theme_name}here-string-tri]} != "none" ]] && (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}here-string-tri]}")
                 already_added=1
                 ;;
        *)       # F - (( after for
                 if [[ $braces_stack = F* ]]; then
                   _fsh_highlight_string
                   _mybuf=$__arg
                   __idx=_start_pos
                   while [[ $_mybuf = (#b)[^a-zA-Z\{\$]#([a-zA-Z][a-zA-Z0-9]#)(*) ]]; do
                     (( __start=__idx-__PBUFLEN+${mbegin[1]}-1, __end=__idx-__PBUFLEN+${mend[1]}+1-1, __start >= 0 )) && \
                       reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}for-loop-variable]}")
                     __idx+=${mend[1]}
                     _mybuf=${match[2]}
                   done

                   _mybuf=$__arg
                   __idx=_start_pos
                   while [[ $_mybuf = (#b)[^+\<\>=:\*\|\&\^\~-]#([+\<\>=:\*\|\&\^\~-]##)(*) ]]; do
                     (( __start=__idx-__PBUFLEN+${mbegin[1]}-1, __end=__idx-__PBUFLEN+${mend[1]}+1-1, __start >= 0 )) && \
                       reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}for-loop-operator]}")
                     __idx+=${mend[1]}
                     _mybuf=${match[2]}
                   done

                   _mybuf=$__arg
                   __idx=_start_pos
                   while [[ $_mybuf = (#b)[^0-9]#([0-9]##)(*) ]]; do
                     (( __start=__idx-__PBUFLEN+${mbegin[1]}-1, __end=__idx-__PBUFLEN+${mend[1]}+1-1, __start >= 0 )) && \
                       reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}for-loop-number]}")
                     __idx+=${mend[1]}
                     _mybuf=${match[2]}
                   done

                   if [[ $__arg = (#b)[^\;]#(\;)[\ ]# ]]; then
                     (( __start=_start_pos-__PBUFLEN+${mbegin[1]}-1, __end=_start_pos-__PBUFLEN+${mend[1]}+1-1, __start >= 0 )) && \
                       reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}for-loop-separator]}")
                   fi

                   already_added=1
                 elif [[ $__arg = *([^\\][\#][\#]|"(#b)"|"(#B)"|"(#m)"|"(#c")* ]]; then
                   (( highlight_glob )) && __style=${_fsh_theme_name}globbing-ext || __style=${_fsh_theme_name}default
                 elif [[ $__arg = ([*?]*|*[^\\][*?]*) ]]; then
                   (( highlight_glob )) && __style=${_fsh_theme_name}globbing || __style=${_fsh_theme_name}default
                 elif [[ $__arg = \$* ]]; then
                   __style=${_fsh_theme_name}variable
                 elif [[ $__arg = $'\x7d' && $braces_stack = Y* && ${_fsh_state[right_brace_is_recognised_everywhere]} = "1" ]]; then
                   # right brace, i.e. $'\x7d' == '}'
                   # Parsing rule: # {
                   #
                   #     Additionally, `tt(})' is recognized in any position if neither the
                   #     tt(IGNORE_BRACES) option nor the tt(IGNORE_CLOSE_BRACES) option is set."""
                   braces_stack=${braces_stack#Y}
                   __style=${_fsh_theme_name}reserved-word
                   (( next_word = next_word | 16 ))
                 elif [[ $__arg = (';;'|';&'|';|') ]] && (( this_word & BIT_case_code )); then
                   (( next_word = (next_word | BIT_case_item) & ~(BIT_case_code+3) ))
                   __style=${_fsh_theme_name}default
                 elif [[ $__arg = ${histchars[1]}* && -n ${__arg[2]} ]]; then
                   __style=${_fsh_theme_name}history-expansion
                 elif (( __arg_type == 3 )); then
                   __style=${_fsh_theme_name}commandseparator
                 elif (( in_redirection == 2 )); then
                   __style=${_fsh_theme_name}redirection
                 elif (( ${+galiases[(e)${(Q)__arg}]} )); then
                   (( incremental_collect )) && _fsh_incremental_parse_safe=0
                   __style=${_fsh_theme_name}global-alias
                 else
                   if [[ ${_fsh_state[no_check_paths]} != 1 ]]; then
                     if [[ ${_fsh_state[use_async]} != 1 ]]; then
                       if _fsh_highlight_check_path noasync; then
                         # ADD
                         (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[$__style]}")
                         already_added=1

                         # TODO: path separators, optimize and add to async code-path
                         [[ -n ${_fsh_styles[${_fsh_theme_name}path_pathseparator]} && ${_fsh_styles[${_fsh_theme_name}path]} != ${_fsh_styles[${_fsh_theme_name}path_pathseparator]} ]] && {
                           for (( __pos = _start_pos; __pos <= _end_pos; __pos++ )) ; do
                             # ADD
                             [[ ${__buf[__pos]} == "/" ]] && (( __start=__pos-__PBUFLEN, __start >= 0 )) && reply+=("$(( __start - 1 )) $__start ${_fsh_styles[${_fsh_theme_name}path_pathseparator]}")
                           done
                         }
                       else
                         __style=${_fsh_theme_name}default
                       fi
                     else
                       if [[ -z ${_fsh_state[cache-path-${(q)__arg}-${_start_pos}]} || $(( EPOCHSECONDS - _fsh_state[cache-path-${(q)__arg}-${_start_pos}-born-at] )) -gt 8 ]]; then
                         if [[ $LASTWIDGET != *-or-beginning-search ]]; then
                           exec {PCFD}< <(_fsh_highlight_check_path; sleep 5)
                           command sleep 0
                           _fsh_state[path-queue]+=";$_start_pos $_end_pos;"
                           is-at-least 5.0.6 && __pos=1 || __pos=0
                           zle -F ${${__pos:#0}:+-w} $PCFD _fsh_check_path_handler_widget
                           _fsh_lifecycle_register_fd "$PCFD" \
                             _fsh_check_path_handler_widget "${sysparams[procsubstpid]-}"
                           already_added=1
                         else
                           __style=${_fsh_theme_name}default
                         fi
                       elif [[ ${_fsh_state[cache-path-${(q)__arg}-${_start_pos}]%D} -eq 1 ]]; then
                         (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}path${${(M)_fsh_state[cache-path-${(q)__arg}-${_start_pos}]%D}:+-to-dir}]}")
                         already_added=1
                       else
                         __style=${_fsh_theme_name}default
                       fi
                     fi
                   else
                     __style=${_fsh_theme_name}default
                   fi
                 fi
                 ;;
      esac
    elif (( this_word & 128 ))
    then
      (( next_word = (next_word | 2) & ~129 ))
      [[ ${_fsh_styles[${_fsh_theme_name}here-string-text]} != "none" ]] && (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}here-string-text]}")
      _fsh_highlight_string ${_fsh_styles[${_fsh_theme_name}here-string-var]:#none}
      already_added=1
    elif (( this_word & (BIT_case_preamble + BIT_case_item) ))
    then
      if (( this_word & BIT_case_preamble )); then
        [[ $__arg = "in" ]] && {
          __style=${_fsh_theme_name}reserved-word
          (( next_word = BIT_case_item ))
        } || {
          __style=${_fsh_theme_name}case-input
          (( next_word = BIT_case_preamble ))
        }
      else
        if (( this_word & BIT_case_nempty_item == 0 )) && [[ $__arg = "esac" ]]; then
          (( next_word = 1 ))
          __style=${_fsh_theme_name}reserved-word
        elif [[ $__arg = (\(*\)|\)|\() ]]; then
          [[ $__arg = *\) ]] && (( next_word = BIT_case_code | 1 )) || (( next_word = BIT_case_item | BIT_case_nempty_item ))
          _fsh_complex_brackets+=( $(( _start_pos-__PBUFLEN )) )
          (( ${#__arg} > 1 )) && {
            _fsh_complex_brackets+=( $(( _start_pos+${#__arg}-1-__PBUFLEN )) )
            (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && \
              reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}case-parentheses]}")
            (( __start=_start_pos+1-__PBUFLEN, __end=_end_pos-1-__PBUFLEN, __start >= 0 )) && \
              reply+=("$__start $__end ${_fsh_styles[${_fsh_theme_name}case-condition]}")
            already_added=1
          } || {
            __style=${_fsh_theme_name}case-parentheses
          }
        else
          (( next_word = BIT_case_item | BIT_case_nempty_item ))
          __style=${_fsh_theme_name}case-condition
        fi
      fi
    fi
    if [[ $__arg = (#b)*'#'(([0-9a-fA-F][0-9a-fA-F])([0-9a-fA-F][0-9a-fA-F])([0-9a-fA-F][0-9a-fA-F])|([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F]))(|[^[:alnum:]]*) || $__arg = (#b)*'rgb('(([0-9a-fA-F][0-9a-fA-F](#c0,1)),([0-9a-fA-F][0-9a-fA-F](#c0,1)),([0-9a-fA-F][0-9a-fA-F](#c0,1)))* ]]; then
      if [[ -n $match[2] ]]; then
        if [[ $match[2] = ?? || $match[3] = ?? || $match[4] = ?? ]]; then
          (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end bg=#${(l:2::0:)match[2]}${(l:2::0:)match[3]}${(l:2::0:)match[4]}")
        else
          (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end bg=#$match[2]$match[3]$match[4]")
        fi
      else
        (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end bg=#$match[5]$match[6]$match[7]")
      fi
      already_added=1
    fi

    # ADD
    (( already_added == 0 )) && [[ ${_fsh_styles[$__style]} != "none" ]] && (( __start=_start_pos-__PBUFLEN, __end=_end_pos-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[$__style]}")

    if (( (__arg_type == 3) && ((this_word & (BIT_case_preamble|BIT_case_item)) == 0) )); then
      if [[ $__arg == ';' ]] && (( in_array_assignment )); then
        # literal newline inside an array assignment
        (( next_word = 2 | (next_word & BIT_case_code) ))
      elif [[ -n ${braces_stack[(r)A]} ]]; then
        # 'A' in stack -> inside [[ ... ]]
        (( next_word = 2 | (next_word & BIT_case_code) ))
      else
        braces_stack=${braces_stack#T}
        (( next_word = 1 | (next_word & BIT_case_code) ))
        highlight_glob=1
        # A new command means that we should not expect that alternate
        # syntax will occur (this is also in the ';' short-path), but
        # || and && mean going down just 1 step, not all the way to 0
        [[ $__arg != ("||"|"&&") ]] && __delimited=0 || (( __delimited = __delimited == 2 ? 1 : __delimited ))
      fi
    elif (( ( (__arg_type == 1) || (__arg_type == 2) ) && (this_word & 1) )); then # (( __arg_type == 1 || __arg_type == 2 )) && (( this_word & 1 ))
        __delimited=1
        (( next_word = 1 | (next_word & (64 | BIT_case_code)) ))
    elif [[ $__arg == "repeat" ]] && (( this_word & 1 )); then
      __delimited=1
      # skip the repeat-count word
      in_redirection=2
      # The redirection mechanism assumes $this_word describes the word
      # following the redirection.  Make it so.
      #
      # That word can be a command word with shortloops (`repeat 2 ls`)
      # or a command separator (`repeat 2; ls` or `repeat 2; do ls; done`).
      #
      # The repeat-count word will be handled like a redirection target.
      (( this_word = 3 ))
    fi
    _start_pos=$_end_pos
    # This is the default/common codepath.
    (( this_word = in_redirection == 0 ? next_word : this_word )) #else # Stall $this_word.
  done

  # Do we have whole buffer? I.e. start at zero
  [[ $3 != 0 ]] && return 0

  # The loop overwrites ")" with "x", except those from $( ) substitution
  #
  # __pos: current nest level, starts from 0
  # __workbuf: copy of __buf, with limit on 250 characters
  # __idx: index in whole command line buffer
  # __list: list of coordinates of ) which shouldn't be ovewritten
  _mybuf=${__buf[1,250]} __workbuf=$_mybuf __idx=0 __pos=0 __list=()

  while [[ $__workbuf = (#b)[^\(\)]#([\(\)])(*) ]]; do
    if [[ ${match[1]} == \( ]]; then
      __arg=${_mybuf[__idx+${mbegin[1]}-1,__idx+${mbegin[1]}-1+2]}
      [[ $__arg = '$('[^\(] ]] && __list+=( $__pos )
      [[ $__arg = '$((' ]] && _mybuf[__idx+${mbegin[1]}-1]=x
      # Increase parenthesis level
      __pos+=1
    else
      # Decrease parenthesis level
      __pos=__pos-1
      [[ -z ${__list[(r)$__pos]} ]] && [[ $__pos -gt 0 ]] && _mybuf[__idx+${mbegin[1]}]=x
    fi
    __idx+=${mbegin[2]}-1
    __workbuf=${match[2]}
  done

  # Run on fake buffer with replaced parentheses: ")" into "x"
  if [[ "$_mybuf" = *$__nul* ]]; then
    # Try to avoid conflict with the \0, however
    # we have to split at *some* character - \7
    # is ^G, so one cannot have null and ^G at
    # the same time on the command line
    __nul=$'\7'
  fi

  __inputs=( ${(ps:$__nul:)${(S)_mybuf//(#b)*\$\(([^\)]#)(\)|(#e))/${mbegin[1]};${mend[1]}${__nul}}%$__nul*} )
  if [[ "${__inputs[1]}" != "$_mybuf" && -n "${__inputs[1]}" ]]; then
    if [[ -n ${_fsh_styles[${_fsh_theme_name}secondary]} ]]; then
      __idx=1
      __tmp=$_fsh_theme_name
      _fsh_theme_name=${${${_fsh_styles[${_fsh_theme_name}secondary]}:t:r}#(CONFIG|CACHE|LOCAL|HOME|OPT):}
      (( ${+_fsh_styles[${_fsh_theme_name}default]} )) || {
        [[ -r $_fsh_work_dir/secondary_theme.local.ini ]] && \
          _fsh_theme_load_data "$_fsh_work_dir/secondary_theme.local.ini" 0 || \
          _fsh_theme_load_data "$_fsh_base_dir/share/free_theme.ini" 0
      }
    else
      __idx=0
    fi
    for _mybuf in $__inputs; do
      (( __start=${_mybuf%%;*}-__PBUFLEN-1, __end=${_mybuf##*;}-__PBUFLEN, __start >= 0 )) && \
        reply+=("$__start $__end ${_fsh_styles[${__tmp}recursive-base]}")
      # Pass authentic buffer for recursive analysis
      _fsh_highlight_process "$PREBUFFER" "${__buf[${_mybuf%%;*},${_mybuf##*;}]}" $(( ${_mybuf%%;*} - 1 ))
    done
    # Restore theme
    (( __idx )) && _fsh_theme_name=$__tmp
  fi

  return 0
}

_fsh_highlight_check_path() {
  (( _start_pos-__PBUFLEN >= 0 )) || \
    { [[ $1 != "noasync" ]] && print -r -- "- $_start_pos $_end_pos"; return 1; }
  [[ $1 != "noasync" ]] && {
    print -r -- ${sysparams[pid]}
    # This is to fill cache
    print -r -- $__arg
  }

  : ${expanded_path:=${(Q)~__arg}}
  [[ -n ${_fsh_blocklist_patterns[(k)${${(M)expanded_path:#/*}:-$PWD/$expanded_path}]} ]] && { [[ $1 != "noasync" ]] && print -r -- "- $_start_pos $_end_pos"; return 1; }

  [[ -z $expanded_path ]] && { [[ $1 != "noasync" ]] && print -r -- "- $_start_pos $_end_pos"; return 1; }
  [[ -d $expanded_path ]] && { [[ $1 != "noasync" ]] && print -r -- "$_start_pos ${_end_pos}D" || __style=${_fsh_theme_name}path-to-dir; return 0; }
  [[ -e $expanded_path ]] && { [[ $1 != "noasync" ]] && print -r -- "$_start_pos $_end_pos" || __style=${_fsh_theme_name}path; return 0; }

  # Search the path in CDPATH, only for CD command
  [[ $active_command = "cd" ]] && for cdpath_dir in $cdpath; do
    [[ -d $cdpath_dir/$expanded_path ]] && { [[ $1 != "noasync" ]] && print -r -- "$_start_pos ${_end_pos}D" || __style=${_fsh_theme_name}path-to-dir; return 0; }
    [[ -e $cdpath_dir/$expanded_path ]] && { [[ $1 != "noasync" ]] && print -r -- "$_start_pos $_end_pos" || __style=${_fsh_theme_name}path; return 0; }
  done

  # It's not a path.
  [[ $1 != "noasync" ]] && print -r -- "- $_start_pos $_end_pos"
  return 1
}

_fsh_highlight_check_path_handler() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

  local IFS=$'\n' pid PCFD=$1 line stripped val
  integer idx

  if read -r -u $PCFD pid; then
    if read -r -u $PCFD val; then
      if read -r -u $PCFD line; then
        stripped=${${line#- }%D}
        _fsh_state[cache-path-${(q)val}-${stripped%% *}-born-at]=$EPOCHSECONDS
        idx=${${_fsh_state[path-queue]}[(I)$stripped]}
        (( idx > 0 )) && {
          if [[ $line != -* ]]; then
            _fsh_state[cache-path-${(q)val}-${stripped%% *}]="1${(M)line%D}"
            region_highlight+=("${line%% *} ${${line##* }%D} ${_fsh_styles[${_fsh_theme_name}path${${(M)line%D}:+-to-dir}]}")
          else
            _fsh_state[cache-path-${(q)val}-${stripped%% *}]=0
          fi
          val=${_fsh_state[path-queue]}
          val[idx-1,idx+${#stripped}]=""
          _fsh_state[path-queue]=$val
          [[ ${_fsh_state[cache-path-${(q)val}-${stripped%% *}]%D} = 1 && ${#val} -le 27 ]] && zle -R
        }
      fi
    fi
    kill -9 $pid 2>/dev/null
  fi

  zle -F -w ${PCFD}
  exec {PCFD}<&-
  _fsh_lifecycle_release_fd "$PCFD"
}

if [[ -o interactive ]] && (( ${+builtins[zle]} )); then
  zle -N -- _fsh_check_path_handler_widget _fsh_highlight_check_path_handler
fi

# Highlight special blocks inside double-quoted strings
#
# The while [[ ... ]] pattern is logically ((A)|(B)|(C)|(D)|(E))(*), where:
# - A matches $var[abc]
# - B matches ${(...)var[abc]}
# - C matches $
# - D matches \$ or \" or \'
# - E matches \*
#
# and the first condition -n ${match[7] uses D to continue searching when
# backslash-something (not ['"$]) is occurred.
#
# $1 - additional style to glue-in to added style
_fsh_highlight_string() {
  (( _start_pos-__PBUFLEN >= 0 )) || return 0
  _mybuf=$__arg
  __idx=_start_pos

  #                                                                                                                                                                                                    7   8
  while [[ $_mybuf = (#b)[^\$\\]#((\$(#B)([#+^=~](#c1,2))(#c0,1)(#B)([a-zA-Z_:][a-zA-Z0-9_:]#|[0-9]##)(#b)(\[[^\]]#\])(#c0,1))|(\$[{](#B)([#+^=~](#c1,2))(#c0,1)(#b)(\([a-zA-Z0-9_:@%#]##\))(#c0,1)[a-zA-Z0-9_:#]##(\[[^\]]#\])(#c0,1)[}])|\$|[\\][\'\"\$]|[\\](*))(*) ]]; do
    [[ -n ${match[7]} ]] && {
      # Skip following char – it is quoted. Choice is
      # made to not highlight such quoting
      __idx+=${mbegin[1]}+1
      _mybuf=${match[7]:1}
    } || {
      __idx+=${mbegin[1]}-1
      _end_idx=__idx+${mend[1]}-${mbegin[1]}+1
      _mybuf=${match[8]}

      # ADD
      (( __start=__idx-__PBUFLEN, __end=_end_idx-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${${1:+$1}:-${_fsh_styles[${_fsh_theme_name}back-or-dollar-double-quoted-argument]}}")

      __idx=_end_idx
    }
  done
  return 0
}

# Highlight math and non-math context variables inside $(( )) and (( ))
#
# The while [[ ... ]] pattern is logically ((A)|(B)|(C)|(D))(*), where:
# - A matches $var[abc]
# - B matches ${(...)var[abc]}
# - C matches $
# - D matches words [a-zA-Z]## (variables)
#
# Parameters used: _mybuf, __idx, _end_idx, __style
_fsh_highlight_math_string() {
  (( _start_pos-__PBUFLEN >= 0 )) || return 0
  _mybuf=$__arg
  __idx=_start_pos

  while [[ $_mybuf = (#b)[^\$_a-zA-Z0-9]#((\$(#B)(+|)(#B)([a-zA-Z_:][a-zA-Z0-9_:]#|[0-9]##)(#b)(\[[^\]]##\])(#c0,1))|(\$[{](#B)(+|)(#b)(\([a-zA-Z0-9_:@%#]##\))(#c0,1)[a-zA-Z0-9_:#]##(\[[^\]]##\])(#c0,1)[}])|\$|[a-zA-Z_][a-zA-Z0-9_]#|[0-9]##)(*) ]]; do
    __idx+=${mbegin[1]}-1
    _end_idx=__idx+${mend[1]}-${mbegin[1]}+1
    _mybuf=${match[7]}

    [[ ${match[1]} = [0-9]* ]] && __style=${_fsh_styles[${_fsh_theme_name}mathnum]} || {
      [[ ${match[1]} = [a-zA-Z_]* ]] && {
        [[ ${+parameters[${match[1]}]} = 1 || ${_fsh_assigns_seen[${match[1]}]} = 1 ]] && \
            __style=${_fsh_styles[${_fsh_theme_name}mathvar]} || \
            __style=${_fsh_styles[${_fsh_theme_name}matherr]}
      } || {
        [[ ${match[1]} = "$"* ]] && {
          match[1]=${match[1]//[\{\}+]/}
          local parameter_name=${match[1]:1}
          parameter_name=${parameter_name#\([^\)]#\)}
          parameter_name=${parameter_name%%\[*}
          if [[ ${match[1]} = "$" || ${_fsh_assigns_seen[$parameter_name]} = 1 ||
            ${+parameters[$parameter_name]} = 1 ]]; then
                __style=${_fsh_styles[${_fsh_theme_name}back-or-dollar-double-quoted-argument]}
          else
            __style=${_fsh_styles[${_fsh_theme_name}matherr]}
          fi
        }
      }
    }

    # ADD
    [[ $__style != "none" && -n $__style ]] && (( __start=__idx-__PBUFLEN, __end=_end_idx-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end $__style")

    __idx=_end_idx
  done
}

# Highlight special chars inside dollar-quoted strings
_fsh_highlight_dollar_string() {
  (( _start_pos-__PBUFLEN >= 0 )) || return 0
  local i j k __style
  local AA
  integer c

  # Starting dollar-quote is at 1:2, so __start parsing at offset 3 in the string.
  for (( i = 3 ; i < _end_pos - _start_pos ; i += 1 )) ; do
    (( j = i + _start_pos - 1 ))
    (( k = j + 1 ))

    case ${__arg[$i]} in
      "\\") __style=${_fsh_theme_name}back-dollar-quoted-argument
            for (( c = i + 1 ; c <= _end_pos - _start_pos ; c += 1 )); do
              [[ ${__arg[$c]} != ([0-9xXuUa-fA-F]) ]] && break
            done
            AA=$__arg[$i+1,$c-1]
            # Matching for HEX and OCT values like \0xA6, \xA6 or \012
            if [[    "$AA" == (#m)(#s)(x|X)[0-9a-fA-F](#c1,2)
                  || "$AA" == (#m)(#s)[0-7](#c1,3)
                  || "$AA" == (#m)(#s)u[0-9a-fA-F](#c1,4)
                  || "$AA" == (#m)(#s)U[0-9a-fA-F](#c1,8)
              ]]; then
              (( k += MEND ))
              (( i += MEND ))
            else
              if (( __asize > i+1 )) && [[ $__arg[i+1] == [xXuU] ]]; then
                # \x not followed by hex digits is probably an error
                __style=${_fsh_theme_name}unknown-token
              fi
              (( k += 1 )) # Color following char too.
              (( i += 1 )) # Skip parsing the escaped char.
            fi
            ;;
      *) continue ;;

    esac
    # ADD
    (( __start=j-__PBUFLEN, __end=k-__PBUFLEN, __start >= 0 )) && reply+=("$__start $__end ${_fsh_styles[$__style]}")
  done
}

_fsh_highlight_init() {
  _fsh_complex_brackets=()
  _fsh_command_type_cache=()
}

_fsh_incremental_reset() {
  builtin emulate -L zsh

  _fsh_incremental_cache_valid=0
  _fsh_incremental_buffer=
  _fsh_incremental_fingerprint=
  _fsh_incremental_prebuffer=
  _fsh_incremental_checkpoints=()
  _fsh_incremental_checkpoint_command_counts=()
  _fsh_incremental_checkpoint_region_counts=()
  _fsh_incremental_command_types=()
  _fsh_incremental_commands=()
  _fsh_incremental_regions=()
}

_fsh_incremental_make_fingerprint() {
  builtin emulate -L zsh

  local fingerprint=$_fsh_theme_name
  fingerprint+=$'\x1f'${(qqq)${(kv)_fsh_styles}}
  fingerprint+=$'\x1c'${(qqq)${(kv)galiases}}
  fingerprint+=$'\x1d'$PWD$'\x1d'$PATH$'\x1d'${CDPATH-}
  fingerprint+=$'\x1d'${_fsh_state[no_check_paths]-}$'\x1d'${_fsh_state[use_async]-}
  fingerprint+=$'\x1d'${_fsh_state[use_brackets]-}$'\x1d'${LASTWIDGET-}
  REPLY=$fingerprint
}

_fsh_incremental_capture_command_types() {
  builtin emulate -L zsh

  local command
  _fsh_incremental_command_types=()
  for command in "${_fsh_incremental_commands[@]}"; do
    (( ${+_fsh_incremental_command_types[(e)$command]} )) && continue
    _fsh_highlight_main_type "$command"
    _fsh_incremental_command_types[(e)$command]=$REPLY
  done
}

_fsh_incremental_store_full() {
  builtin emulate -L zsh

  local prebuffer=$1 buffer=$2

  if [[ -n $prebuffer ]] || (( ! _fsh_incremental_parse_safe )) ||
    (( ! $#_fsh_incremental_parse_checkpoints )); then
    _fsh_incremental_reset
    return 0
  fi

  _fsh_incremental_make_fingerprint
  _fsh_incremental_fingerprint=$REPLY
  _fsh_incremental_prebuffer=$prebuffer
  _fsh_incremental_buffer=$buffer
  _fsh_incremental_regions=( "${reply[@]}" )
  _fsh_incremental_commands=( "${_fsh_last_commands[@]}" )
  _fsh_incremental_checkpoints=( "${_fsh_incremental_parse_checkpoints[@]}" )
  _fsh_incremental_checkpoint_region_counts=( "${_fsh_incremental_parse_region_counts[@]}" )
  _fsh_incremental_checkpoint_command_counts=( "${_fsh_incremental_parse_command_counts[@]}" )
  _fsh_incremental_capture_command_types
  _fsh_incremental_cache_valid=1
}

_fsh_incremental_try() {
  builtin emulate -L zsh
  builtin setopt extended_glob typeset_silent

  local prebuffer=$1 buffer=$2 suffix command
  local -a prefix_regions prefix_commands suffix_regions suffix_commands
  local -a retained_checkpoints retained_region_counts retained_command_counts
  local -A checked_commands
  integer common=0 common_limit checkpoint_index=0 checkpoint=0
  integer region_count=0 command_count=0 index parse_status

  (( _fsh_incremental_cache_valid )) || return 1
  [[ -z $prebuffer && $prebuffer == $_fsh_incremental_prebuffer ]] || return 1
  [[ $buffer != $_fsh_incremental_buffer ]] || return 1
  [[ $buffer == [[:alnum:][:space:]_./,:@%+\;-]# && $buffer != *';;'* ]] || return 1

  _fsh_incremental_make_fingerprint
  [[ $REPLY == $_fsh_incremental_fingerprint ]] || return 1

  (( common_limit = $#buffer < $#_fsh_incremental_buffer ? $#buffer : $#_fsh_incremental_buffer ))
  while (( common < common_limit )) &&
    [[ ${buffer[common + 1]} == ${_fsh_incremental_buffer[common + 1]} ]]; do
    (( ++common ))
  done

  for (( index = 1; index <= $#_fsh_incremental_checkpoints; ++index )); do
    (( _fsh_incremental_checkpoints[index] <= common )) || break
    checkpoint_index=$index
  done
  (( checkpoint_index )) || return 1

  checkpoint=$_fsh_incremental_checkpoints[checkpoint_index]
  region_count=$_fsh_incremental_checkpoint_region_counts[checkpoint_index]
  command_count=$_fsh_incremental_checkpoint_command_counts[checkpoint_index]

  (( region_count )) && prefix_regions=( "${(@)_fsh_incremental_regions[1,region_count]}" )
  (( command_count )) && {
    prefix_commands=( "${(@)_fsh_incremental_commands[1,command_count]}" )
  }
  _fsh_highlight_init
  for command in "${prefix_commands[@]}"; do
    (( ${+checked_commands[(e)$command]} )) && continue
    checked_commands[(e)$command]=1
    _fsh_highlight_main_type "$command"
    [[ $REPLY == ${_fsh_incremental_command_types[(e)$command]-} ]] || return 1
  done
  suffix=${buffer[checkpoint + 1,-1]}
  _fsh_incremental_collect=1
  _fsh_incremental_parse_safe=1
  _fsh_incremental_parse_checkpoints=()
  _fsh_incremental_parse_region_counts=()
  _fsh_incremental_parse_command_counts=()
  reply=()
  if _fsh_highlight_process '' "$suffix" "$checkpoint"; then
    parse_status=0
  else
    parse_status=$?
  fi
  _fsh_incremental_collect=0

  (( parse_status == 0 && _fsh_incremental_parse_safe )) || return 1
  suffix_regions=( "${reply[@]}" )
  suffix_commands=( "${_fsh_last_commands[@]}" )
  reply=( "${prefix_regions[@]}" "${suffix_regions[@]}" )
  _fsh_last_commands=( "${prefix_commands[@]}" "${suffix_commands[@]}" )

  retained_checkpoints=( "${(@)_fsh_incremental_checkpoints[1,checkpoint_index]}" )
  retained_region_counts=( "${(@)_fsh_incremental_checkpoint_region_counts[1,checkpoint_index]}" )
  retained_command_counts=( "${(@)_fsh_incremental_checkpoint_command_counts[1,checkpoint_index]}" )
  _fsh_incremental_checkpoints=( "${retained_checkpoints[@]}" )
  _fsh_incremental_checkpoint_region_counts=( "${retained_region_counts[@]}" )
  _fsh_incremental_checkpoint_command_counts=( "${retained_command_counts[@]}" )
  for (( index = 1; index <= $#_fsh_incremental_parse_checkpoints; ++index )); do
    _fsh_incremental_checkpoints+=( $_fsh_incremental_parse_checkpoints[index] )
    _fsh_incremental_checkpoint_region_counts+=( $(( region_count + _fsh_incremental_parse_region_counts[index] )) )
    _fsh_incremental_checkpoint_command_counts+=( $(( command_count + _fsh_incremental_parse_command_counts[index] )) )
  done

  _fsh_incremental_buffer=$buffer
  _fsh_incremental_regions=( "${reply[@]}" )
  _fsh_incremental_commands=( "${_fsh_last_commands[@]}" )
  _fsh_incremental_capture_command_types
  _fsh_incremental_last_used=1
  return 0
}

_fsh_highlight_buffer() {
  builtin emulate -L zsh
  builtin setopt extended_glob

  local prebuffer=$1 buffer=$2
  integer parse_status

  _fsh_incremental_last_used=0
  _fsh_incremental_try "$prebuffer" "$buffer" && return 0

  _fsh_highlight_init
  if [[ -z $prebuffer && $buffer == [[:alnum:][:space:]_./,:@%+\;-]# &&
    $buffer != *';;'* ]]; then
    _fsh_incremental_collect=1
    _fsh_incremental_parse_safe=1
  else
    _fsh_incremental_collect=0
    _fsh_incremental_parse_safe=0
  fi
  _fsh_incremental_parse_checkpoints=()
  _fsh_incremental_parse_region_counts=()
  _fsh_incremental_parse_command_counts=()
  reply=()
  if _fsh_highlight_process "$prebuffer" "$buffer" 0; then
    parse_status=0
  else
    parse_status=$?
  fi
  _fsh_incremental_collect=0
  if (( parse_status != 0 )); then
    _fsh_incremental_reset
    return $parse_status
  fi
  _fsh_incremental_store_full "$prebuffer" "$buffer"
}

typeset -ga _fsh_style_ranges
_fsh_shappend() {
  _fsh_style_ranges+=( "$(( $1 - 1 ));;$(( $2 ))" )
}

functions -M fsh_sy_h_append 2 2 _fsh_shappend 2>/dev/null
