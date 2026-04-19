# config

A personal collection of git, tmux, shell, terminal, and CLI-tool configs. See [PRINCIPLES.md](./PRINCIPLES.md) for the intent and direction of this repo.

This repo is dual-mode: you can either clone it and run `onboard`, or open any template file on GitHub and copy it by hand into your home directory — both paths land on the same baseline.

# install

You must have git installed. Then:

```bash
cd ~ && git clone https://github.com/labeldock/config.git
~/config/onboard
```

`onboard` opens an arrow-key / Space / Enter / Esc menu. Picking `install → Recommend` installs brew + mise + a global CLI toolset in one go; the `config` and `ai-config` submenus apply dotfile / XDG templates with a status badge and a diff-prompt flow so existing settings aren't silently overwritten.

# What we prefer here

This is a personal taste. If any of it looks useful, feel free to borrow.

## Tools we like (install submenu)

We reach for [Homebrew](https://brew.sh) as the system package manager and [mise](https://mise.jdx.dev) for runtime versions. On top of that, these are the CLI tools we keep globally installed via mise:

| Category | Tools |
| --- | --- |
| Text processing | `jq`, `yq` |
| File / search | `fd`, `ripgrep` |
| Git workflow | `lazygit`, `delta` |
| File browsing | `yazi` |
| Shell productivity | `fzf`, `zoxide` |

`Recommend` installs the lot in one go. Anything already on `$PATH` is shown as `(installed)` and skipped.

## Configs we use

Templates live in two directories, each mapping to a destination:

| Source directory | Destination | Examples |
| --- | --- | --- |
| [`dotfiles.templates/`](./dotfiles.templates) | `$HOME/...` | `.gitconfig`, `.tmux.conf`, `.nanorc`, `.tm_properties` |
| [`xdg_config.templates/`](./xdg_config.templates) | `$HOME/.config/...` | `ghostty/config`, `opencode/*.json`, `yazi/keymap.toml` |

When you pick a menu item, one of these strategies applies:

| Strategy | When used | Behaviour |
| --- | --- | --- |
| **copy** | plain config files (nanorc, tmux.conf, ghostty/config, tm_properties, opencode JSON) | missing → copy; differs → show unified diff and ask before overwriting; identical → no-op |
| **source** | shell rc snippets (`claude/.bashrc.template`, `opencode/.bashrc.template`) | appends a single `[ -f <template> ] && . <template>` line to `~/.bashrc` / `~/.zshrc`, tagged with a marker comment so it runs exactly once |
| **gitconfig-merge** | `.gitconfig` | per-key upsert: template keys overwrite matching keys in the target, keys that exist only in the target are preserved, and sections that exist only in the target (e.g. `[user]`, `[credential "..."]`, `[core]`, `[delta]`) are left untouched |
| **toml-merge** | `yazi/keymap.toml` | parses `[[mgr.prepend_keymap]]` blocks, replaces matching blocks by their `on =` key, appends new ones; user-added keys and non-block comments are preserved |

The merge logic lives in [`lib/gitconfig_merge.py`](./lib/gitconfig_merge.py) and [`lib/toml_merge.py`](./lib/toml_merge.py); `onboard` calls them via `python3`.

## Menu items at a glance

| Submenu | Items |
| --- | --- |
| `install` | `Recommend`, `Brew`, `Mise` |
| `config` | `gitconfig`, `nanorc`, `tmux`, `ghostty`, `tm_properties`, `yazi` |
| `ai-config` | `opencode`, `claude` |

Each item shows a status badge so you can see where you stand before touching anything: `+ missing`, `= in sync`, `~ diff`, `~ partial`, `= sourced`, `+ not sourced`.

# GIT alias

Aliases are defined in [`dotfiles.templates/.gitconfig`](./dotfiles.templates/.gitconfig). Run `onboard` and pick `gitconfig` to apply. Click a section to expand.

<details>
<summary><strong>status / diff</strong></summary>

* `s` : branch list + status
* `ss` : short status (`status -sb`)
* `dun` : unstaged diff (`diff`)
* `din` : indexed diff (`diff --cached`)
* `d-1` : diff HEAD^..HEAD
* `c <pattern>` : grep git config

</details>

<details>
<summary><strong>checkout / branch</strong></summary>

* `ch` : checkout
* `fs <name>` : feature start — `checkout -b`
* `fd` : feature delete — delete current branch (master protected)

</details>

<details>
<summary><strong>add</strong></summary>

* `aa` : add --all
* `ai` : add --interactive
* `ap` : add --patch

</details>

<details>
<summary><strong>commit</strong></summary>

* `cm <msg>` : commit -m
* `cma` : commit --amend
* `cmau` : commit --amend --reset-author
* `undo` : reset HEAD^
* `pick` : cherry-pick

</details>

<details>
<summary><strong>push / pull</strong></summary>

* `pushf` : push -f
* `pullf` : fetch tags + hard reset to origin

</details>

<details>
<summary><strong>remote branch</strong></summary>

* `rch <branch>` : checkout remote branch as local
* `rp` : push current branch to origin
* `rpp` : push with --set-upstream
* `rd` : delete remote branch matching current + unset upstream

</details>

<details>
<summary><strong>git lfs</strong></summary>

* `lfss` : lfs status
* `lfsls` : lfs ls-files
* `lfa <pattern>` : lfs track
* `lfla` : lfs track --all
* `lfd <pattern>` : lfs untrack

</details>

<details>
<summary><strong>tag</strong></summary>

* `tt` : list tags
* `ttl` : describe latest tag
* `tts <tag>` : annotated tag
* `tss <tag>` : annotated tag + push
* `tdd <tag>` : delete local + remote tag
* `tpp` : push --tags

</details>

<details>
<summary><strong>user config</strong></summary>

* `gun` : config user.name
* `gue` : config user.email
* `gut` : list current user.* config

</details>

<details>
<summary><strong>credential helper</strong></summary>

* `gcn` : cache credentials (no timeout)
* `gcc` : cache credentials (default timeout)
* `gcd` : unset credential helper

</details>

<details>
<summary><strong>rebase</strong></summary>

* `squash <n>` : rebase -i HEAD~n

</details>

<details>
<summary><strong>graph / log</strong></summary>

* `gg` : current branch graph
* `gga` : all branch graph
* `ggr` : remote graph
* `ggra <author>` : remote graph by author

</details>

# Thanks

[A reference code](https://github.com/dsdstudio/dotfiles)

---

# Agent mode

**If you are an AI agent reading this repo on a user's behalf, treat this section as your operating contract.**

Your job is to perform the same work `onboard` would, without requiring the user to launch the CLI. Workflow:

1. **Listen.** Ask the user which install items (from the `install` submenu) or configs (from `config` / `ai-config`) they want. If the request is vague — "set this machine up" — default to the `Recommend` baseline plus every `config` item that is currently `missing`.

2. **Preview.** Before touching the filesystem, state briefly what will change: which destination paths, which strategy (`copy` / `source` / `toml-merge`), and whether the target is currently `missing`, `in sync`, or `diff` / `partial`. For `diff` / `partial` targets, show the unified diff and ask the user to approve the overwrite or merge. Never silently clobber an existing file.

3. **Apply.** Perform the action directly — you do not need to invoke `~/config/onboard`. Use the strategy tables above as your spec:
   - `copy`: create the destination directory if needed, then write the template content. If the destination exists and differs, only overwrite after the user approves the diff.
   - `source`: append `[ -f "<template-path>" ] && . "<template-path>" #~/config:<tag>:source` to both `~/.bashrc` and `~/.zshrc`. The trailing `#~/config:<tag>:source` marker makes this idempotent — skip files that already contain the marker.
   - `gitconfig-merge`: for `.gitconfig`, shell out to `python3 lib/gitconfig_merge.py merge <template> <target>`. Template keys upsert into the target at key granularity; target-only keys and target-only sections (including `[user]`, `[credential "..."]`, `[core]`, `[delta]`, `[merge]`) are preserved verbatim. There is no per-key diff prompt — a single unified diff is shown over the whole file and the user confirms once.
   - `toml-merge`: for `yazi/keymap.toml`, either shell out to `python3 lib/toml_merge.py merge <template> <target>` or reproduce its logic (match `[[mgr.prepend_keymap]]` blocks by their `on =` line, replace matches, append the rest, leave everything else untouched).

4. **Install items** (`Recommend` / `Brew` / `Mise`) still require running the respective installers — drive them from the shell as the scripts in [`lib/onboard.sh`](./lib/onboard.sh) do. You may reuse that file directly.

5. **Be conservative.** Templates in this repo are the single source of truth, but the *user's* customizations take precedence when they conflict. Favour merge over overwrite when both sides are meaningful (the yazi case), and always ask before replacing a `diff` target.

6. **Summarize.** At the end, report what you changed, per file, using the same status vocabulary (`missing → copied`, `diff → overwritten`, `partial → merged`, `not sourced → sourced`, etc.).
