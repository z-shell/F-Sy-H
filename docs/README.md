<table style="width:100%;height:auto">
 <tr align="justify" margin-left="auto" margin-right="auto"><td align="center">
  <h1>
   <a title="❮ ZW ❯" target="_self" href="https://github.com/z-shell/zw">
  <img style="width:60;height:60px"
    src="https://raw.githubusercontent.com/z-shell/zi/main/docs/images/favicon.svg"
    alt="Logo" /></a>❮ ZI ❯ - F-Sy-H
  </h1>
  <h2>
    Feature-rich Syntax Highlighting for Zsh
  </h2>
<h3>
  <a href="https://github.com/orgs/z-shell/discussions/">《❔》Ask a Question </a>
  <a href="https://z.digitalclouds.dev/search/">《💡》Search Wiki </a>
  <a href="https://github.com/z-shell/community/issues/new?assignees=&labels=%F0%9F%91%A5+member&template=membership.yml&title=team%3A+">《💜》Join </a>
  <a href="https://digitalclouds.crowdin.com/z-shell/">《🌐》Localize </a>
</h3>
  </td></tr>
<tr>
<td align="center">
  <a title="Crowdin" target="_self" href="https://crowdin.digitalclouds.dev/z-shell">
    <img align="center" src="https://badges.crowdin.net/e/f108c12713ee8526ac878d5671ad6e29/localized.svg" />
  </a>
  <a href="https://github.com/z-shell/f-sy-h/actions/workflows/zunit.yml">
    <img align="center" src="https://github.com/z-shell/f-sy-h/actions/workflows/zunit.yml/badge.svg">
  </a>
  <a title="VIM" target="_self" href="https://github.com/z-shell/zi-vim-syntax/">
    <img align="center" src="https://img.shields.io/badge/--019733?logo=vim" alt="VIM" />
  </a>
  <a title="ZW" target="_self" href="https://open.vscode.dev/z-shell/f-sy-h/">
    <img
      align="center"
      src="https://img.shields.io/badge/--007ACC?logo=visual%20studio%20code&logoColor=ffffff"
      alt="Visual Studio Code"
    />
  </a>
</td>
</tr>
<tr>
  <td align="center">
  <img
    align="center" style="width:80%;height:auto"
    src="https://raw.githubusercontent.com/z-shell/.github/main/metrics/plugin/followup/f-sy-h_followup.svg"
  />
  <img
    align="center" style="width:80%;height:auto"
    src="https://raw.githubusercontent.com/z-shell/.github/main/metrics/metrics.svg"
  />
  <img
    align="center" style="width:80%;height:auto"
    src="https://raw.githubusercontent.com/z-shell/.github/main/metrics/plugin/projects/projects.svg"
  />
</td></tr><tr><td>
  
<h2 align="left">Related<h2>

- [License](../LICENSE)
- [Changelog](CHANGELOG.md)
- [Theme Guide](THEME_GUIDE.md)
- [Chroma Guide](CHROMA_GUIDE.adoc)

</td></tr><tr><td>
<h2 align="left">Installation</h2>

### Manual

Clone the Repository.

```zsh
git clone https://github.com/z-shell/F-Sy-H ~/path/to/fsh
```

And add the following to your `zshrc` file.

```zsh
source ~/path/to/fsh/f-sy-h.plugin.zsh
```

### ZI

Add the following to your `zshrc` file.

```zsh
zi light z-shell/F-Sy-H
```

Here's an example of how to load the plugin together with a few other popular
ones with the use of
[Turbo](https://z.digitalclouds.dev/docs/getting_started/overview#turbo-mode-zsh--53),
i.e.: speeding up the Zsh startup by loading the plugin right after the first
prompt, in background:

```zsh
zi wait lucid for \
 atinit"ZI[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    z-shell/F-Sy-H \
 blockf \
    zsh-users/zsh-completions \
 atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions
```

### Zinit

Add the following to your `zshrc` file.

```zsh
zinit light z-shell/F-Sy-H
```

### Antigen

Add the following to your `zshrc` file.

```zsh
antigen bundle z-shell/F-Sy-H
```

### Zgen

Add the following to your `.zshrc` file in the same place you're doing
your other `zgen load` calls in.

```zsh
zgen load z-shell/F-Sy-H . main
```

### Oh-My-Zsh

Clone the Repository.

```zsh
git clone https://github.com/z-shell/F-Sy-H.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/F-Sy-H
```

And add `F-Sy-H` to your plugin list.

## Features

### Themes

Switch themes via `fast-theme {theme-name}`.

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/theme.png"
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
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/parameter.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/in_string.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Brackets

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/brackets.gif"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Conditions

Comparing to the project `zsh-users/zsh-syntax-highlighting` (the upper line):

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/cplx_cond.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Strings

Exact highlighting that recognizes quotings.

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/ideal-string.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### here-strings

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/herestring.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### `exec` descriptor-variables

Comparing to the project `zsh-users/zsh-syntax-highlighting` (the upper line):

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/images/execfd_cmp.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### for-loops and alternate syntax (brace `{`/`}` blocks)

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/for-loop-cmp.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Function definitions

Comparing to the project `zsh-users/zsh-syntax-highlighting` (the upper 2 lines):

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/function.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Recursive `eval` and `$( )` highlighting

Comparing to the project `zsh-users/zsh-syntax-highlighting` (the upper line):

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/eval_cmp.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Chroma functions

Highlighting that is specific for a given command.

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/git_chroma.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

The [chromas](https://github.com/z-shell/F-Sy-H/tree/main/%E2%86%92chroma)
that are enabled by default can be found
[here](https://github.com/z-shell/F-Sy-H/blob/main/fast-highlight#L166).

### Math-mode highlighting

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/math.gif"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div>

### Zcalc highlighting

<div style="width:100%;background-color:black;border:3px solid black;border-radius:6px;margin:5px 0;padding:2px 5px">
  <img
    src="https://raw.githubusercontent.com/z-shell/F-Sy-H/main/docs/images/zcalc.png"
    alt="image could not be loaded"
    style="color:red;background-color:black;font-weight:bold"
  />
</div><h2 align="left">Performance</h2>

Performance differences can be observed in this Asciinema recording, where a `10 kB` function is being edited.

<div style="width:100%;background-color:#121314;border:3px solid #121314;border-radius:6px;margin:5px 0;padding:2px 5px">
 <a href="https://asciinema.org/a/112367">
    <img src="https://asciinema.org/a/112367.png" alt="asciicast">
 </a>
 </div>
  </td>
</tr>
<tr><td align="center"><h2 align="left">Credits</h2><a href="https://cloudflare.com" rel="nofollow">
  <img style="width:140;height:40px" src="https://space.ss-o.workers.dev/img/brand/cloudflare/cf-logo-v-rgb.png" alt="Cloudflare" />
 </a>
 <a href="https://crowdin.com/?utm_source=badge&utm_medium=referral&utm_campaign=badge-add-on" rel="nofollow">
  <img style="width:140;height:40px" src="https://space.ss-o.workers.dev/img/brand/crowdin/localization-at-dark-rounded@2x.png" alt="Crowdin | Agile localization for tech companies" />
 </a>
 <a href="https://www.digitalocean.com/?refcode=090bdb63f800&utm_campaign=Referral_Invite&utm_medium=Referral_Program&utm_source=badge" rel="nofollow">
  <img style="width:140;height:40px" src="https://web-platforms.sfo2.digitaloceanspaces.com/WWW/Badge%203.svg" alt="DigitalOcean Referral Badge" />
 </a>
 </td></tr>
</table>
