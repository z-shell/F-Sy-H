# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

# Canonical theme declaration and fallback schema. Theme loading, validation,
# and CI consume these tables so declared and resolved styles cannot drift.
typeset -gA _fsh_theme_style_fallbacks=(
  default                     '-'
  unknown-token               '-'
  reserved-word               '-'
  subcommand                  '- reserved-word'
  alias                       '- command builtin'
  suffix-alias                '- alias command builtin'
  builtin                     '-'
  function                    '- builtin command'
  command                     '-'
  precommand                  '- command'
  commandseparator            '-'
  hashed-command              '- command'
  path                        '-'
  path_pathseparator          'pathseparator'
  globbing                    '- back-or-dollar-double-quoted-argument'
  globbing-ext                '- double-quoted-argument'
  history-expansion           '-'
  single-hyphen-option        '- single-quoted-argument'
  double-hyphen-option        '- double-quoted-argument'
  back-quoted-argument        '-'
  single-quoted-argument      '-'
  double-quoted-argument      '-'
  dollar-quoted-argument      '-'
  back-or-dollar-double-quoted-argument '- back-dollar-quoted-argument'
  back-dollar-quoted-argument '- back-or-dollar-double-quoted-argument'
  assign                      '- reserved-word'
  redirection                 '- reserved-word'
  comment                     '-'
  variable                    '-'
  mathvar                     '- forvar variable'
  mathnum                     '- fornum'
  matherr                     '- incorrect-subtle'
  assign-array-bracket        '-'
  for-loop-variable           'forvar mathvar variable'
  for-loop-number             'fornum mathnum'
  for-loop-operator           'foroper reserved-word'
  for-loop-separator          'forsep commandseparator'
  exec-descriptor             '- reserved-word'
  here-string-tri             '-'
  here-string-text            '- subtle-bg'
  here-string-var             '- back-or-dollar-double-quoted-argument'
  recursive-base              '- default'
  case-input                  '- variable'
  case-parentheses            '- reserved-word'
  case-condition              '- correct-subtle'
  correct-subtle              '-'
  incorrect-subtle            '-'
  subtle-separator            '- commandseparator'
  subtle-bg                   '- correct-subtle'
  path-to-dir                 '- path'
  paired-bracket              '- subtle-bg correct-subtle'
  bracket-level-1             '-'
  bracket-level-2             '-'
  bracket-level-3             '-'
  global-alias                '- alias suffix-alias'
  single-sq-bracket           '-'
  double-sq-bracket           '-'
  double-paren                '-'
  optarg-string               '- double-quoted-argument'
  optarg-number               '- mathnum'
)

typeset -ga _fsh_theme_style_order=(
  default unknown-token reserved-word alias suffix-alias builtin function command precommand
  commandseparator hashed-command path path_pathseparator globbing globbing-ext history-expansion
  single-hyphen-option double-hyphen-option back-quoted-argument single-quoted-argument
  double-quoted-argument dollar-quoted-argument back-or-dollar-double-quoted-argument
  back-dollar-quoted-argument assign redirection comment variable mathvar
  mathnum matherr assign-array-bracket for-loop-variable for-loop-number for-loop-operator
  for-loop-separator exec-descriptor here-string-tri here-string-text here-string-var secondary
  case-input case-parentheses case-condition correct-subtle incorrect-subtle subtle-separator subtle-bg
  path-to-dir paired-bracket bracket-level-1 bracket-level-2 bracket-level-3
  global-alias subcommand single-sq-bracket double-sq-bracket double-paren
  optarg-string optarg-number recursive-base
)
