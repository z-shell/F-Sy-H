#!/usr/bin/env zsh

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-registry.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
command mkdir -p -- "$ZDOTDIR"
zstyle ':fsh:config' work-dir "$fixture_root/work"

source "$plugin_root/F-Sy-H.plugin.zsh"

(( ! ${+_fsh_state[chroma-example]} ))
(( ! ${+_fsh_state[chroma-vim]} ))
(( ! ${+_fsh_state[chroma-which]} ))
(( ! ${+functions[_fsh_chroma_ogit]} ))
[[ ${_fsh_state[chroma-svnadmin]} == _fsh_chroma_subversion ]]

# The whatis chroma is platform-gated. Autoload state and registry state must
# agree on every platform, otherwise the reachability sweep below is a lie.
if [[ $OSTYPE == darwin* ]]; then
  (( ! ${+_fsh_state[chroma-whatis]} ))
  (( ! ${+_fsh_state[chroma-man]} ))
  (( ! ${+functions[_fsh_chroma_whatis]} ))
else
  [[ ${_fsh_state[chroma-whatis]} == _fsh_chroma_whatis ]]
  [[ ${_fsh_state[chroma-man]} == _fsh_chroma_whatis ]]
  (( ${+functions[_fsh_chroma_whatis]} ))
fi

typeset key target function_name
typeset -A registry_targets
for key in ${(k)_fsh_state}; do
  [[ $key == chroma-* ]] || continue
  target=${_fsh_state[$key]%%%*}
  (( ${+functions[$target]} )) || {
    builtin print -u2 -r -- "f-sy-h: registry target is not autoloadable: $key -> $target"
    exit 1
  }
  registry_targets[$target]=1
done

for function_name in ${(k)functions}; do
  [[ $function_name == _fsh_chroma_* ]] || continue
  case $function_name in
    _fsh_chroma_example|_fsh_chroma_git|_fsh_chroma_zi)
      continue
      ;;
  esac
  (( ${+registry_targets[$function_name]} )) || {
    builtin print -u2 -r -- "f-sy-h: autoloaded chroma is unreachable: $function_name"
    exit 1
  }
done

fsh_plugin_unload

typeset output
output=$(ZDOTDIR=$fixture_root/opt-in-zdotdir XDG_CACHE_HOME=$fixture_root/opt-in-cache \
  zsh -f -c '
    zstyle ":fsh:config" work-dir "$1"
    zstyle ":fsh:config" chroma-opt-in vim which
    source "$2/F-Sy-H.plugin.zsh"
    [[ ${_fsh_state[chroma-vim]} == _fsh_chroma_vim ]]
    [[ ${_fsh_state[chroma-which]} == _fsh_chroma_which ]]
    (( ${+functions[_fsh_chroma_vim]} ))
    (( ${+functions[_fsh_chroma_which]} ))
    fsh_plugin_unload
  ' zsh "$fixture_root/opt-in-work" "$plugin_root" 2>&1) || {
    builtin print -u2 -r -- "f-sy-h: chroma opt-in failed: $output"
    exit 1
  }
[[ -z $output ]]

if output=$(ZDOTDIR=$fixture_root/invalid-zdotdir XDG_CACHE_HOME=$fixture_root/invalid-cache \
  zsh -f -c '
    zstyle ":fsh:config" work-dir "$1"
    zstyle ":fsh:config" chroma-opt-in unknown
    source "$2/F-Sy-H.plugin.zsh"
  ' zsh "$fixture_root/invalid-work" "$plugin_root" 2>&1); then
  builtin print -u2 -r -- 'f-sy-h: invalid chroma opt-in unexpectedly succeeded'
  exit 1
fi
[[ $output == *'unsupported :fsh:config chroma-opt-in value: unknown'* ]]
