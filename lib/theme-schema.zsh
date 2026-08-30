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

# Shipped themes declare their rendering assumptions. External themes may omit
# this metadata for compatibility, but when it is present the validator applies
# the same contract used by CI.
typeset -ga _fsh_theme_metadata_keys=( palette foreground background )
typeset -g _fsh_theme_contrast_floor=4.5
typeset -g _fsh_theme_critical_contrast_floor=7.0
typeset -gA _fsh_theme_critical_styles=(
  unknown-token     1
  incorrect-subtle  1
  matherr           1
)

# Fixed-palette correctness signals retain a project-defined CIELAB distance
# under the published Machado, Oliveira, and Fernandes severity-1.0 models.
# https://doi.org/10.1109/TVCG.2009.113
# Matrix rows are kept as ordered strings because Zsh arrays cannot nest.
typeset -g _fsh_theme_cvd_separation_floor=20.0
typeset -ga _fsh_theme_cvd_models=( protanopia deuteranopia tritanopia )
typeset -gA _fsh_theme_cvd_matrices=(
  protanopia   '0.152286 1.052583 -0.204868 0.114503 0.786281 0.099216 -0.003882 -0.048116 1.051998'
  deuteranopia '0.367322 0.860646 -0.227968 0.280085 0.672501 0.047413 -0.011820 0.042940 0.968881'
  tritanopia   '1.255528 -0.076749 -0.178779 -0.078411 0.930809 0.147602 0.004733 0.691367 0.303900'
)

# Semantic pairs are ordered for deterministic validator diagnostics. Distinct
# pairs must not resolve to the same effective rendering. Shared pairs document
# intentional command-family and alias-family grouping.
typeset -ga _fsh_theme_semantic_pair_policy=(
  'require-distinct single-hyphen-option double-hyphen-option'
  'require-distinct optarg-string optarg-number'
  'require-distinct subcommand optarg-string'
  'allow-shared command builtin'
  'allow-shared alias suffix-alias'
  'allow-shared function command'
)
