# F-Sy-H

<div align="center">
  <a href="https://github.com/z-shell/F-Sy-H">
    <img
      src="https://raw.githubusercontent.com/z-shell/zi/main/docs/images/logo.png"
      alt="Z-Shell logo"
      width="72"
      height="72"
    />
  </a>

  <p>Feature-rich, interactive syntax highlighting for Zsh.</p>
  <p>
    <a href="https://github.com/z-shell/F-Sy-H/actions/workflows/zunit.yml">
      <img
        src="https://github.com/z-shell/F-Sy-H/actions/workflows/zunit.yml/badge.svg?branch=main"
        alt="ZUnit status"
      />
    </a>
    <a href="LICENSE">
      <img
        src="https://img.shields.io/github/license/z-shell/F-Sy-H"
        alt="License"
      />
    </a>
  </p>
</div>

## Features

- Highlights Zsh syntax as a command line is edited.
- Provides command-specific chroma highlighters for tools such as Git, Docker,
  grep, and make.
- Supports shipped and user-defined themes through `fast-theme`.
- Highlights nested command substitutions, arithmetic, strings, paths, and
  shell control structures.

![A command line highlighted with an F-Sy-H theme](docs/images/theme.png)

## Requirements

- Zsh 5.8 or newer
- An interactive Zsh Line Editor session for live highlighting

## Portable shell contract

- Project identifier: `f-sy-h`
- Authoritative entrypoint: `F-Sy-H.plugin.zsh`
- Public command: `fast-theme`
- Public alias: `f-sy-h` (an alias for `fast-theme`)
- Unload function: `f-sy-h_plugin_unload`
- Autoload paths: the repository root and `functions/`

The existing compatibility configuration surface uses the
`:plugin:fast-syntax-highlighting` `zstyle` context and the documented
`FAST_WORK_DIR`, `FAST_HIGHLIGHT`, `FAST_HIGHLIGHT_STYLES`,
`FAST_THEME_NAME`, `ZSH_HIGHLIGHT_MAXLENGTH`, and `ZLAST_COMMANDS` parameters.
These names are retained for existing users. New lifecycle state is private and
uses the `_fsh_` prefix.

### Owned shell state

- Public functions: `fast-theme` and `f-sy-h_plugin_unload`
- Public alias: `f-sy-h=fast-theme`
- Public parameters: `FAST_BASE_DIR`, `FAST_HIGHLIGHT_VERSION`,
  `FAST_WORK_DIR`, `FAST_HIGHLIGHT`, `FAST_HIGHLIGHT_STYLES`,
  `FAST_THEME_NAME`, `ZSH_HIGHLIGHT_MAXLENGTH`, and `ZLAST_COMMANDS`
- Direct module requests: `zsh/parameter`, `zsh/system`, optional
  `zsh/nearcolor`, and interactive-only `zsh/zleparameter`
- Hook: `_zsh_highlight_preexec_hook` in `preexec_functions`
- Widgets: `fast-highlight-check-path-handler` plus wrappers around existing
  widgets, excluding dot-prefixed widgets and ZLE helper widgets documented in
  `_zsh_highlight_bind_widgets`

Other `_fsh_*`, `_zsh_highlight*`, `/f-sy-h-*`, `.fast-*`, and `chroma/*`
functions, plus other matching `FAST_*`, `_FAST_*`, `FSH_*`,
`_ZSH_HIGHLIGHT_*`, `__FAST_*`, and `__fast_*` parameters, are implementation
details. The unload function also tracks modules loaded transitively during
initialization and only claims modules that were not loaded before the plugin.

## Installation

### Zi

```zsh
zi light z-shell/F-Sy-H
```

Zi is the reference plugin manager for Z-Shell documentation and validation.

### Direct source

```zsh
git clone https://github.com/z-shell/F-Sy-H.git ~/path/to/f-sy-h
source ~/path/to/f-sy-h/F-Sy-H.plugin.zsh
```

### Other plugin managers

Managers that source conventional `*.plugin.zsh` entrypoints can load
`z-shell/F-Sy-H`. Detailed manager-specific examples live in the
[F-Sy-H wiki guide](https://wiki.zshell.dev/ecosystem/plugins/f-sy-h).

## Configuration

Select the startup theme before loading the plugin:

```zsh
zstyle ':plugin:fast-syntax-highlighting' theme default
zi light z-shell/F-Sy-H
```

Set a custom work directory before loading when the default XDG cache location
is unsuitable:

```zsh
typeset -g FAST_WORK_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/f-sy-h
```

Theme files and the full compatibility configuration surface are documented in
the [wiki guide](https://wiki.zshell.dev/ecosystem/plugins/f-sy-h).

## Usage

List available themes:

```zsh
fast-theme --list
```

Test a theme for the current session:

```zsh
fast-theme --test clean
```

Apply a theme:

```zsh
fast-theme clean
```

## Lifecycle and side effects

Interactive loading:

- adds the repository root and `functions/` to `fpath` when absent;
- wraps existing ZLE widgets and creates the path-check handler widget;
- registers `_zsh_highlight_preexec_hook` in `preexec_functions`;
- loads the Zsh modules needed by highlighting; and
- defines the documented functions, parameters, and alias above.

Non-interactive loading defines the shell API but does not change widgets or
install the `preexec` hook. Repeated sourcing is a no-op after a successful
load.

`f-sy-h_plugin_unload` removes plugin-owned hooks, widgets, functions,
parameters, aliases, modules, and `fpath` entries. It restores state captured
before the first load only while the installed value remains unchanged. A
widget, alias, function, or parameter changed after loading is preserved.

Loading performs no network request and does not create the cache directory.
The explicit `fast-theme` command creates storage only when it needs to write
theme state. Existing theme files under `FAST_WORK_DIR` are treated as
user-managed configuration.

## Verification

From the repository root:

```bash
zsh -f -n F-Sy-H.plugin.zsh lib/lifecycle.zsh
zsh -f scripts/test-plugin-entrypoint.zsh
zsh -f scripts/test-plugin-lifecycle.zsh noninteractive
zsh -f -i scripts/test-plugin-lifecycle.zsh interactive
zsh -f scripts/test-function-completion.zsh
zunit
```

The ZUnit command requires the repository's pinned ZUnit toolchain.

## Documentation and support

- [F-Sy-H wiki guide](https://wiki.zshell.dev/ecosystem/plugins/f-sy-h)
- [Theme guide](docs/THEME_GUIDE.md)
- [Chroma guide](docs/CHROMA_GUIDE.adoc)
- [Changelog](docs/CHANGELOG.md)
- [Zsh Plugin Standard](https://wiki.zshell.dev/community/zsh_plugin_standard)
- [Zsh documentation](https://zsh.sourceforge.io/Doc/)
- [Report an issue](https://github.com/z-shell/F-Sy-H/issues)

## Release model

Contributions integrate on `main`. F-Sy-H is consumed directly from Git;
version tags identify reviewed snapshots and do not introduce a separate
package registry.

## Contributing and license

Contributions follow the
[Z-Shell organization guidance](https://github.com/z-shell/.github).
This project is distributed under the terms in [LICENSE](LICENSE).
