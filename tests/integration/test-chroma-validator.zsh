#!/usr/bin/env zsh

builtin emulate -R zsh
builtin setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-chroma-validator.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset output
output=$(zsh -f "$plugin_root/tools/validate-chromas.zsh")
[[ $output == *'/_fsh_chroma_git: ok (138 entries)'* ]]
[[ $output == *'/_fsh_chroma_zi: ok (36 entries)'* ]]

{
  builtin print -r -- 'typeset -gA _fsh_chroma_bad_def=('
  builtin print -r -- '  subcommands "(bad)"'
  builtin print -r -- '  subcmd:NULL "MISSING_0_arg"'
  builtin print -r -- '  MALFORMED_0_arg "NO-OP"'
  builtin print -r -- '  UNKNOWN_HANDLER_0_arg "NO-OP // ::_fsh_chroma_missing"'
  builtin print -r -- '  UNKNOWN_ACTION_0_arg "eval something // NO-OP"'
  builtin print -r -- ')'
} >| "$fixture_root/_fsh_chroma_bad"

if output=$(zsh -f "$plugin_root/tools/validate-chromas.zsh" \
  "$fixture_root/_fsh_chroma_bad" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: invalid Chroma definition unexpectedly passed validation'
  exit 1
fi
[[ $output == *': undefined-node: node is not defined: MISSING_0_arg'* ]]
[[ $output == *': malformed-entry: expected action // handler'* ]]
[[ $output == *': unknown-handler: function is not defined: _fsh_chroma_missing'* ]]
[[ $output == *': unknown-action: unsupported action: "eval something"'* ]]
