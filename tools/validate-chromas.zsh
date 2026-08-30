#!/usr/bin/env zsh

builtin emulate -R zsh
builtin setopt extended_glob no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h}
typeset -g _fsh_theme_name=validator-
typeset -gA _fsh_state ZI ZI_EXTS
typeset -gA validation_keys
typeset -ga validation_errors
typeset -g validation_path validation_key
typeset -g REPLY
typeset -grA generic_handlers=(
  _fsh_chroma_option_action 1
  _fsh_chroma_option_argument_action 1
  _fsh_chroma_option_separator_action 1
  _fsh_chroma_verify_pattern 1
  _fsh_chroma_verify_url 1
)

trim() {
  REPLY=${1//((#s)[[:space:]]##|[[:space:]]##(#e))/}
}

validation_error() {
  validation_errors+=( "$validation_path:$validation_key: $1: $2" )
}

validate_handler() {
  local handler=$1

  [[ $handler == NO-OP ]] && return 0
  if [[ $handler != ::[A-Za-z_][A-Za-z0-9_]# ]]; then
    validation_error malformed-handler "expected NO-OP or ::function, got ${(qqq)handler}"
    return 0
  fi
  handler=${handler#::}
  (( ${+generic_handlers[$handler]} || ${+functions[$handler]} )) ||
    validation_error unknown-handler "function is not defined: $handler"
}

validate_action_record() {
  local record=$1 action handler style
  local -a fields

  fields=( "${(@s://:)record}" )
  fields=( "${fields[@]//((#s)[[:space:]]##|[[:space:]]##(#e))/}" )
  if (( $#fields != 2 )); then
    validation_error malformed-entry "expected action // handler, got ${(qqq)record}"
    return 0
  fi

  action=$fields[1]
  handler=$fields[2]
  if [[ $action != NO-OP ]]; then
    if [[ $action != '__style='* ]]; then
      validation_error unknown-action "unsupported action: ${(qqq)action}"
    else
      style=${action#__style=}
      [[ $style == '${_fsh_theme_name}'* ]] && style=validator-${style#'${_fsh_theme_name}'}
      [[ $style == [-[:alnum:]_]## ]] ||
        validation_error unknown-action "invalid style action: ${(qqq)action}"
    fi
  fi
  validate_handler "$handler"
}

validate_reference_list() {
  local value=$1 reference
  local -a references

  references=( "${(@s://:)value}" )
  references=( "${references[@]//((#s)[[:space:]]##|[[:space:]]##(#e))/}" )
  for reference in "${references[@]}"; do
    if [[ -z $reference ]]; then
      validation_error malformed-entry 'empty node reference'
    elif (( ! ${+validation_keys[$reference]} )); then
      validation_error undefined-node "node is not defined: $reference"
    fi
  done
}

validate_option_node() {
  local value=$1 clause selector record
  local -a clauses fields

  clauses=( "${(@s:||:)value}" )
  for clause in "${clauses[@]}"; do
    fields=( "${(@s:<<>>:)clause}" )
    fields=( "${fields[@]//((#s)[[:space:]]##|[[:space:]]##(#e))/}" )
    selector=$fields[1]
    if [[ -z $selector || $#fields == 1 ]]; then
      validation_error malformed-entry "option clause needs a selector and record: ${(qqq)clause}"
      continue
    fi
    if [[ $selector == *:(add|del) ]]; then
      (( $#fields == 2 )) ||
        validation_error malformed-entry "directive clause has extra records: ${(qqq)clause}"
      validate_reference_list "$fields[2]"
      continue
    fi
    if (( $#fields > 3 )); then
      validation_error malformed-entry "option clause has more than two action records: ${(qqq)clause}"
      continue
    fi
    for record in "${(@)fields[2,-1]}"; do
      validate_action_record "$record"
    done
  done
}

validate_argument_node() {
  local value=$1 record directive operation reference
  local -a fields references

  fields=( "${(@s:<<>>:)value}" )
  fields=( "${fields[@]//((#s)[[:space:]]##|[[:space:]]##(#e))/}" )
  record=$fields[1]
  if [[ $record == *:::::* ]]; then
    trim "${record%%:::::*}"
    [[ -n $REPLY ]] || validation_error malformed-entry 'expected-value pattern is empty'
    trim "${record#*:::::}"
    record=$REPLY
  fi
  validate_action_record "$record"

  (( $#fields >= 2 )) || return 0
  for directive in "${(@)fields[2,-1]}"; do
    references=( "${(@s://:)directive}" )
    references=( "${references[@]//((#s)[[:space:]]##|[[:space:]]##(#e))/}" )
    operation=${references[1]%%:*}
    reference=${references[1]#*:}
    if [[ $operation != (add|del) || $reference == $references[1] ]]; then
      validation_error malformed-entry "expected add:node or del:node, got ${(qqq)directive}"
      continue
    fi
    references[1]=$reference
    validate_reference_list "${(j: // :)references}"
  done
}

validate_definition() {
  local definition_name=$1 entry_name value handler
  local -a keys

  validation_keys=()
  keys=( "${(@kP)definition_name}" )
  for validation_key in "${keys[@]}"; do
    validation_keys[$validation_key]=1
  done

  for validation_key in subcommands subcmd:NULL; do
    (( ${+validation_keys[$validation_key]} )) ||
      validation_error missing-entry "required entry is absent: $validation_key"
  done

  for validation_key in "${keys[@]}"; do
    entry_name="${definition_name}[${validation_key}]"
    value=${(P)entry_name}
    case $validation_key in
      subcommands)
        if [[ $value == ::* ]]; then
          handler=${value#::}
          (( ${+functions[$handler]} )) ||
            validation_error unknown-handler "function is not defined: $handler"
        elif [[ -z $value ]]; then
          validation_error malformed-entry 'subcommands must not be empty'
        fi
        ;;
      subcmd-hook)
        (( ${+functions[$value]} )) ||
          validation_error unknown-handler "function is not defined: $value"
        ;;
      subcommands-blacklist)
        ;;
      subcmd:*)
        [[ -n ${validation_key#subcmd:} ]] ||
          validation_error malformed-entry 'subcommand selector is empty'
        validate_reference_list "$value"
        ;;
      *)
        if [[ $validation_key != [A-Za-z0-9_]##_(<->|\#)_(opt|arg)(\*|\^|) ]]; then
          validation_error malformed-entry 'node name must end in _POSITION_opt or _POSITION_arg'
        elif [[ $validation_key == *_opt(\*|\^|) ]]; then
          validate_option_node "$value"
        else
          validate_argument_node "$value"
        fi
        ;;
    esac
  done
}

typeset -a definition_paths=( "$@" )
typeset source_path source_text chroma_name definition_name
integer initial_error_count

if (( ! $#definition_paths )); then
  for source_path in "$plugin_root"/chroma/_fsh_chroma_*(N-.); do
    source_text=$(<"$source_path")
    [[ $source_text == *'typeset -gA _fsh_chroma_'*'_def'* ]] && definition_paths+=( "$source_path" )
  done
fi

if (( ! $#definition_paths )); then
  builtin print -u2 -r -- 'f-sy-h: no Chroma definition files found'
  exit 1
fi

for source_path in "${definition_paths[@]}"; do
  validation_path=${source_path:A}
  chroma_name=${source_path:t}
  chroma_name=${chroma_name#_fsh_chroma_}
  definition_name=_fsh_chroma_${chroma_name}_def
  validation_key='<definition>'
  initial_error_count=$#validation_errors
  _fsh_state=()
  builtin unset "$definition_name" 2>/dev/null
  if ! source "$source_path"; then
    validation_error source-failed 'definition file returned non-zero'
    continue
  fi
  if [[ ${(tP)definition_name} != association ]]; then
    validation_error missing-definition "expected associative array: $definition_name"
    continue
  fi
  validate_definition "$definition_name"
  if (( $#validation_errors == initial_error_count )); then
    builtin print -r -- "$validation_path: ok (${#${(kP)definition_name}} entries)"
  fi
done

if (( $#validation_errors )); then
  builtin print -u2 -rl -- "${validation_errors[@]}"
  exit 1
fi
