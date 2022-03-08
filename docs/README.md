<h1 align="center">
  <a href="https://github.com/z-shell/zi">
    <img src="https://github.com/z-shell/zi/raw/main/docs/images/logo.svg" alt="Logo" width="80" height="80" />
  </a>
❮ ZI - F-Sy-H ❯
</h1>
<div align="center">
<h3>Feature-rich Syntax Highlighting for Zsh</h3>
<a href="https://github.com/z-shell/fast-syntax-highlighting/actions/workflows/zunit.yml"><img src="https://github.com/z-shell/fast-syntax-highlighting/actions/workflows/zunit.yml/badge.svg"></a>
</div>

---

<details open="open">
<summary>Table of Contents</summary>

- [Related](#related)
- [News](#news)
- [Installation](#installation)
  - [Manual](#manual)
  - [ZI](#zi)
  - [Zinit](#zinit)
  - [Antigen](#antigen)
  - [Zgen](#zgen)
  - [Oh-My-Zsh](#oh-my-zsh)
- [Features](#features)
  - [Themes](#themes)
  - [Variables](#variables)
  - [Brackets](#brackets)
  - [Conditions](#conditions)
  - [Strings](#strings)
  - [here-strings](#here-strings)
  - [`exec` descriptor-variables](#exec-descriptor-variables)
  - [for-loops and alternate syntax (brace `{`/`}` blocks)](#for-loops-and-alternate-syntax-brace--blocks)
  - [Function definitions](#function-definitions)
  - [Recursive `eval` and `$( )` highlighting](#recursive-eval-and---highlighting)
  - [Chroma functions](#chroma-functions)
  - [Math-mode highlighting](#math-mode-highlighting)
  - [Zcalc highlighting](#zcalc-highlighting)
- [Performance](#performance)

</details>

## Related

- [License](../LICENSE)
- [Changelog](CHANGELOG.md)
- [Theme Guide](THEME_GUIDE.md)
- [Chroma Guide](CHROMA_GUIDE.adoc)

## News

- 15-06-2019
  - A new architecture for defining the highlighting for **specific commands**: it now
    uses **abstract definitions** instead of **top-down, regular code**. The first effect
    is the highlighting for the `git` command it is now **maximally faithful**, it
    follows the `git` command almost completely.
    [Screencast](https://asciinema.org/a/253411)

## Installation

### Manual

Clone the Repository.

```zsh
git clone https://github.com/z-shell/fast-syntax-highlighting ~/path/to/fsh
```

And add the following to your `zshrc` file.

```zsh
source ~/path/to/fsh/fast-syntax-highlighting.plugin.zsh
```

### ZI

Add the following to your `zshrc` file.

```zsh
zi light z-shell/fast-syntax-highlighting
```

Here's an example of how to load the plugin together with a few other popular
ones with the use of
[Turbo](https://z.digitalclouds.dev/docs/getting_started/overview#turbo-mode-zsh--53),
i.e.: speeding up the Zsh startup by loading the plugin right after the first
prompt, in background:

```zsh
zi wait lucid for \
 atinit"ZI[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    z-shell/fast-syntax-highlighting \
 blockf \
    zsh-users/zsh-completions \
 atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions
```

### Zinit

Add the following to your `zshrc` file.

```zsh
zinit light z-shell/fast-syntax-highlighting
```

### Antigen

Add the following to your `zshrc` file.

```zsh
antigen bundle z-shell/fast-syntax-highlighting
```

### Zgen

Add the following to your `.zshrc` file in the same place you're doing
your other `zgen load` calls in.

```zsh
zgen load z-shell/fast-syntax-highlighting
```

### Oh-My-Zsh

Clone the Repository.

```zsh
git clone https://github.com/z-shell/fast-syntax-highlighting.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
```

And add `fast-syntax-highlighting` to your plugin list.

## Features

### Themes

Switch themes via `fast-theme {theme-name}`.

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/theme.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

Run `fast-theme -t {theme-name}` option to obtain the snippet above.

Run `fast-theme -l` to list available themes.

### Variables

Comparing to the project `zsh-users/zsh-syntax-highlighting` (the upper line):

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/parameter.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/in_string.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Brackets

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/brackets.gif"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Conditions

Comparing to the project `zsh-users/zsh-syntax-highlighting` (the upper line):

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/cplx_cond.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Strings

Exact highlighting that recognizes quotings.

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/ideal-string.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### here-strings

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/herestring.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### `exec` descriptor-variables

Comparing to the project `zsh-users/zsh-syntax-highlighting` (the upper line):

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/execfd_cmp.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### for-loops and alternate syntax (brace `{`/`}` blocks)

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/for-loop-cmp.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Function definitions

Comparing to the project `zsh-users/zsh-syntax-highlighting` (the upper 2 lines):

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/function.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Recursive `eval` and `$( )` highlighting

Comparing to the project `zsh-users/zsh-syntax-highlighting` (the upper line):

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/eval_cmp.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Chroma functions

Highlighting that is specific for a given command.

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/git_chroma.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

The [chromas](https://github.com/z-shell/fast-syntax-highlighting/tree/main/chroma)
that are enabled by default can be found
[here](https://github.com/z-shell/fast-syntax-highlighting/blob/main/fast-highlight#L166).

### Math-mode highlighting

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/math.gif"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Zcalc highlighting

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/fast-syntax-highlighting/main/images/zcalc.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

## Performance

Performance differences can be observed in this Asciinema recording, where a `10 kB` function is being edited.

<div style="width:100%;background-color:#121314;border:3px solid #121314;border-radius:6px;margin:5px 0;padding:2px 5px">
  <a href="https://asciinema.org/a/112367">
    <img src="https://asciinema.org/a/112367.png" alt="asciicast">
  </a>
</div>
