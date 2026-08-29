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
- Supports shipped and user-defined themes through `fsh_theme`.
- Highlights nested command substitutions, arithmetic, strings, paths, and
  shell control structures.

![A command line highlighted with an F-Sy-H theme](docs/images/theme.png)

## Requirements

- Zsh 5.8 or newer
- An interactive Zsh Line Editor session for live highlighting

## Portable shell contract

- Project identifier: `fsh`
- Authoritative entrypoint: `F-Sy-H.plugin.zsh`
- Public functions: `fsh_theme` and `fsh_plugin_unload`
- Public configuration context: `:fsh:config`
- Autoload paths: `functions/`, `completions/`, and the private `chroma/`

The plugin has no public aliases or public parameters. Persistent implementation
state and callbacks use the private `_fsh_` prefix. Native completion naming is
the one required exception: the completion for `fsh_theme` is `_fsh_theme`.

### Repository layout

- `F-Sy-H.plugin.zsh` is the only entrypoint.
- `lib/` contains private code sourced eagerly by the entrypoint and is not on
  `fpath`.
- `functions/` contains one autoload function per file.
- `chroma/` contains private command-specific autoload functions.
- `completions/` contains native completion functions. The plugin makes this
  directory available on `fpath` but never calls `compinit`.
- `themes/` and `share/` contain declarative INI data.
- `tests/integration/` and `tests/unit/` contain executable integration profiles
  and ZUnit specifications, respectively.

### Owned shell state

- Public functions: `fsh_theme` and `fsh_plugin_unload`
- Private persistent functions and parameters: names beginning with `_fsh_`
- Direct module requests: `zsh/parameter`, `zsh/system`, optional
  `zsh/nearcolor`, and interactive-only `zsh/zleparameter`
- Hook: `_fsh_preexec_hook` in `preexec_functions`
- Widgets: `_fsh_check_path_handler_widget`, `_fsh_widget_*` wrappers, and
  temporary `fsh-orig-*` saved-widget names

The unload function tracks modules loaded transitively during initialization
and lazy plugin operations. It only claims modules that were not loaded before
the plugin.

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

### Version 2 migration

This layout intentionally uses the Zsh Plugin Standard version 2 contract as a
clean interface. Existing configurations need these changes:

- Replace `fast-theme` and the `f-sy-h` alias with `fsh_theme`.
- Replace `FAST_WORK_DIR` with `zstyle ':fsh:config' work-dir ...`.
- Replace `ZSH_HIGHLIGHT_MAXLENGTH` with
  `zstyle ':fsh:config' max-length ...`.
- Replace `FAST_THEME_MANAGER_DISABLED=1` with
  `zstyle ':fsh:config' theme-manager disabled`.
- Replace direct mutation of plugin globals with the documented settings below.
- Reapply a theme with `fsh_theme`; executable legacy theme cache files are not
  loaded.

Legacy functions, aliases, parameters, and executable cache formats are not
retained as a second compatibility interface.

## Configuration

All ordinary settings use `:fsh:config`. Set them before loading the plugin:

```zsh
zstyle ':fsh:config' work-dir "${XDG_CACHE_HOME:-$HOME/.cache}/f-sy-h"
zstyle ':fsh:config' max-length 10000
zstyle ':fsh:config' theme-manager enabled
zstyle ':fsh:config' bracket-highlighting enabled
zstyle ':fsh:config' path-blocklist '/private/*' '/mnt/slow/**'
zi light z-shell/F-Sy-H
```

The settings are:

- `work-dir`: scalar path, default
  `${XDG_CACHE_HOME:-$HOME/.cache}/f-sy-h`.
- `max-length`: non-negative integer, default `10000`.
- `theme-manager`: boolean-like scalar, default `enabled`.
- `bracket-highlighting`: boolean-like scalar, default `enabled`.
- `path-blocklist`: array of Zsh patterns excluded from path probing, empty by
  default.

For boolean-like settings, `disabled`, `false`, `no`, `off`, and `0` disable
the feature; any other value enables it.

Theme file examples and additional usage guidance are documented in the
[wiki guide](https://wiki.zshell.dev/ecosystem/plugins/f-sy-h).

## Usage

List available themes:

```zsh
fsh_theme --list
```

Test a theme for the current session:

```zsh
fsh_theme --test clean
```

Apply a theme:

```zsh
fsh_theme clean
```

## Lifecycle and side effects

Interactive loading:

- adds `functions/`, `completions/`, and `chroma/` to `fpath` when absent;
- wraps existing ZLE widgets and creates the path-check handler widget;
- registers `_fsh_preexec_hook` in `preexec_functions`;
- loads the Zsh modules needed by highlighting; and
- defines the documented functions and private state above.

Non-interactive loading defines the shell API but does not change widgets or
install the `preexec` hook. Repeated sourcing is a no-op after a successful
load.

`fsh_plugin_unload` removes plugin-owned hooks, widgets, functions,
parameters, modules, and `fpath` entries. It restores state captured
before the first load only while the installed value remains unchanged. A
widget, function, or parameter changed after loading is preserved.

Loading performs no network request and does not create the cache directory.
The explicit `fsh_theme` command creates storage only when it needs to write
theme state. Saved state uses `current_theme.ini`, `theme_overlay.ini`, and
`secondary_theme.local.ini`. These files are parsed as data. Legacy writable
`*.zsh` theme caches are deliberately ignored and never sourced.

## Verification

From the repository root:

```bash
zsh -f -n F-Sy-H.plugin.zsh lib/*.zsh functions/* completions/* chroma/*
zsh -f tests/integration/test-plugin-entrypoint.zsh
zsh -f tests/integration/test-plugin-lifecycle.zsh noninteractive
zsh -f -i tests/integration/test-plugin-lifecycle.zsh interactive
zsh -f tests/integration/test-function-completion.zsh
zsh -f tests/integration/test-git-chroma-regions.zsh
zsh -f tests/integration/test-passive-safety.zsh
zsh -f tests/integration/test-hostile-autoloads.zsh
zunit
```

The ZUnit command requires the repository's pinned ZUnit toolchain.

## Documentation and support

- [F-Sy-H wiki guide](https://wiki.zshell.dev/ecosystem/plugins/f-sy-h)
- [Release history](https://github.com/z-shell/F-Sy-H/releases)
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
