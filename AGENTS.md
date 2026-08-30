# AGENTS.md - z-shell/F-Sy-H

Contributor and agent orientation for this repository. Organization policy,
decisions, patterns, and runbooks live in
[`z-shell/.github`](https://github.com/z-shell/.github).

## Repository contract

F-Sy-H is a Zsh 5.8+ interactive syntax-highlighting plugin consumed directly
from Git. It is class 3, git-consumed source: `main` is both the integration
branch and the stable consumable branch. Version tags mark reviewed snapshots;
do not add release automation or a package-registry workflow.

- Branch from and target `main`.
- Name work branches `feature-<issue>`, `bug-<issue>`, or `hotfix-<issue>`.
- Use [Conventional Commits](https://www.conventionalcommits.org/).
- Never add a bot, AI agent, or automation as a `Co-authored-by` contributor.
- Track active work, blockers, and deferred scope in GitHub issues and pull
  requests. Project 28 is a portfolio view, not a second source of truth.

See the organization
[branch decision](https://github.com/z-shell/.github/blob/main/decisions/0019-trunk-on-main-default.md),
[commit decision](https://github.com/z-shell/.github/blob/main/decisions/0003-conventional-commits.md),
and [release runbook](https://github.com/z-shell/.github/blob/main/runbooks/release.md).

## Plugin boundaries

The portable contract follows version 2 of the
[Zsh Plugin Standard](https://wiki.zshell.dev/community/zsh_plugin_standard).
`F-Sy-H.plugin.zsh` is the only entrypoint. Direct sourcing and conventional
plugin managers must work without manager-owned registries or capabilities.
Zi is the reference manager for documentation and validation, not a runtime
requirement.

Public shell API:

- functions: `fsh_theme`, `fsh_plugin_unload`
- configuration: `zstyle ':fsh:config' ...`
- private state and callbacks: `_fsh_*`

Preserve caller state outside the documented load effects. Plugin loading and
passive highlighting perform no network activity and do not create files.
Keep filesystem and subprocess work behind explicit commands or the existing
asynchronous chroma boundary.

## Repository map

| Path                 | Purpose                                                         |
| -------------------- | --------------------------------------------------------------- |
| `F-Sy-H.plugin.zsh`  | Entrypoint, lifecycle, configuration, and setup                 |
| `lib/`               | Private implementation sourced eagerly by the entrypoint        |
| `functions/`         | Autoload functions, including `fsh_theme`                       |
| `chroma/`            | Private command-specific highlighters                           |
| `completions/`       | Native completion functions; the plugin does not run `compinit` |
| `themes/`            | Shipped declarative INI themes                                  |
| `share/`             | Declarative schema and chroma data                              |
| `tools/`             | Maintainer validation commands                                  |
| `tests/integration/` | Standalone behavior and lifecycle profiles                      |
| `tests/unit/`        | ZUnit specifications                                            |

The [README](README.md) owns the public API, configuration, migration, and
user-facing verification guidance. Do not duplicate those contracts here.

## Validation

Before changing Zsh, classify the execution profile and follow the
[organization Zsh instructions](https://github.com/z-shell/.github/blob/main/.github/instructions/zsh-scripting.instructions.md).
Zsh itself is the syntax authority; do not use ShellCheck for Zsh sources.

Run native syntax checks and the integration profiles affected by the change.
The baseline local command list is under `README.md` section `Verification`;
`.github/workflows/zsh-n.yml` is the exact CI matrix for Zsh 5.8 and 5.9.2.

ZUnit uses `.zunit.yml` and the exact released ZUnit 0.8.2 commit
`15061c83373be80b523988121b7ba12c6b2d82dc`, built as shown in
`.github/workflows/zunit.yml`. With that binary in `bin/`, run:

```sh
PATH="$PWD/bin:$PATH" zunit
```

Use `tools/validate-themes.zsh` for shipped or changed theme files. Run Trunk
on changed files before publication; CI uses `.github/workflows/trunk-check.yml`.
Never weaken a check to make a change pass.

## Before non-trivial work

1. Read the owning issue and related pull requests, then verify its Project 28
   state.
2. Check the current `main` commit and existing worktrees before creating a
   branch.
3. Reuse established code and tests; avoid new dependencies and parallel
   sources of truth.
4. Keep the change scoped, update nearby documentation when behavior changes,
   and record unfinished work in the owning issue.

Cross-repository idioms belong in
[`PATTERNS.md`](https://github.com/z-shell/.github/blob/main/PATTERNS.md), not
in a local duplicate. Use the organization
[test guidance](https://github.com/z-shell/.github/blob/main/.github/instructions/testing.instructions.md)
and [handoff format](https://github.com/z-shell/.github/blob/main/.github/AGENT_MEMORY.md)
when they apply.
