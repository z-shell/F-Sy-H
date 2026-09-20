#!/usr/bin/env zsh
# Exact parser regions for inline color-literal previews (issue #157).
# A literal previews only its own span, after the token style, so quoted
# arguments keep their configured style around it.

emulate -R zsh
setopt err_exit no_unset no_function_argzero posix_argzero

typeset -r plugin_root=${${(%):-%N}:A:h:h:h}
typeset -r fixture_root=$(command mktemp -d "${TMPDIR:-/tmp}/fsyh-color.XXXXXXXX")
trap 'command rm -rf -- "$fixture_root"' EXIT HUP INT TERM

typeset -gx ZDOTDIR=$fixture_root/zdotdir
typeset -gx XDG_CACHE_HOME=$fixture_root/cache-home
command mkdir -p -- "$ZDOTDIR"
zstyle ':fsh:config' work-dir "$fixture_root/work"

source "$plugin_root/F-Sy-H.plugin.zsh"
source "$plugin_root/tests/integration/chroma-fixture.zsh"

(( _fsh_state[use_color_preview] == 1 ))

_fsh_styles[command]=fg=1
_fsh_styles[builtin]=fg=1
_fsh_styles[default]=fg=3
_fsh_styles[single-hyphen-option]=fg=4
_fsh_styles[double-hyphen-option]=fg=5
_fsh_styles[optarg-string]=fg=6
_fsh_styles[single-quoted-argument]=fg=48
_fsh_styles[double-quoted-argument]=fg=49
_fsh_styles[globbing]=fg=7
_fsh_styles[path]=fg=8
_fsh_styles[path-to-dir]=fg=9

# The exact command from the issue: both literals inside the quoted sed
# expression preview their own span and the token keeps its quoted style.
fsh_assert_exact_regions 'find . -type f -name "*.svg" -exec sed -i '"'"'s/#aaaaaa/#eceff4/gI'"'"' {} +' \
  '0 4 fg=1' \
  '5 6 fg=9' \
  '7 12 fg=4' \
  '13 14 fg=3' \
  '15 20 fg=4' \
  '21 28 fg=49' \
  '29 34 fg=4' \
  '35 38 fg=3' \
  '39 41 fg=4' \
  '42 64 fg=48' \
  '45 52 fg=black,bg=#aaaaaa' \
  '53 60 fg=black,bg=#eceff4' \
  '65 67 fg=3' \
  '68 69 fg=3'

# Unquoted tokens keep their ordinary style underneath the preview.
fsh_assert_exact_regions 'echo #ff0000' \
  '0 4 fg=1' \
  '5 12 fg=3' \
  '5 12 fg=white,bg=#ff0000'

# A double-quoted token is offset by its opening quote.
fsh_assert_exact_regions 'echo "x #ff0000"' \
  '0 4 fg=1' \
  '5 16 fg=49' \
  '8 15 fg=white,bg=#ff0000'

# Short and rgb() forms expand to six hex digits; light colors get black text.
fsh_assert_exact_regions 'echo --color=#abc rgb(0,ff,0)' \
  '0 4 fg=1' \
  '5 17 fg=5' \
  '13 17 fg=6' \
  '13 17 fg=black,bg=#aabbcc' \
  '18 29 fg=3' \
  '18 29 fg=black,bg=#00ff00'

# No boundary means no literal: seven hex digits, a letter before the hash, or
# a short literal running straight into a skipped rgb() form.
fsh_assert_exact_regions 'echo #abcdefg foo#abc #abcrgb(1,2,3)' \
  '0 4 fg=1' \
  '5 13 fg=3' \
  '14 21 fg=3' \
  '22 36 fg=3'

# Disabling the preview leaves only the ordinary token styles.
_fsh_state[use_color_preview]=0
fsh_assert_exact_regions 'sed -i '"'"'s/#aaaaaa/#eceff4/gI'"'"' file' \
  '0 3 fg=1' \
  '4 6 fg=4' \
  '7 29 fg=48' \
  '30 34 fg=3'
