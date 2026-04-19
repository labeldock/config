# config

This is a collection of my git, tmux, and other configs.

See [PRINCIPLES.md](./PRINCIPLES.md) for the intent and direction of this repo.

# thanks
[A reference code](https://github.com/dsdstudio/dotfiles)

# install
You must have git installed. Then:
```bash
cd ~ && git clone https://github.com/labeldock/config.git
cd ~/config && bash install.sh
```
Reopen your terminal, then:
```
config
```

# GIT alias

Aliases are defined in [`dotfiles.templates/.gitconfig`](./dotfiles.templates/.gitconfig). Run `setup_gitconfig` from the `config` menu to apply.

## status / diff
* `s` : branch list + status
* `ss` : short status (`status -sb`)
* `dun` : unstaged diff (`diff`)
* `din` : indexed diff (`diff --cached`)
* `d-1` : diff HEAD^..HEAD
* `c <pattern>` : grep git config

## checkout / branch
* `ch` : checkout
* `chf <file>` : checkout file (`checkout --`)
* `cdf <file>` : clean untracked file (`clean -df --`)
* `fs <name>` : feature start — `checkout -b`
* `fd` : feature delete — delete current branch (master protected)

## add
* `aa` : add --all
* `ai` : add --interactive
* `ap` : add --patch
* `lfix` : add --renormalize

## commit
* `cm <msg>` : commit -m
* `cma` : commit --amend
* `cmau` : commit --amend --reset-author
* `cmad <date>` : amend with committer date
* `chmodx <file>` : mark file as +x in index
* `undo` : reset HEAD^
* `pick` : cherry-pick

## push / pull
* `pushf` : push -f
* `pullf` : fetch tags + hard reset to origin

## remote branch
* `rch <branch>` : checkout remote branch as local
* `rp` : push current branch to origin
* `rpp` : push with --set-upstream
* `rd` : delete remote branch matching current + unset upstream

## submodule
* `sc` : submodule update --init --recursive
* `su` : submodule update --recursive
* `spull` : submodule foreach git pull

## git lfs
* `lf` : lfs status
* `lfls` : lfs ls-files
* `lfa <pattern>` : lfs track
* `lfla` : lfs track --all
* `lfd <pattern>` : lfs untrack

## tag
* `tt` : list tags
* `ttl` : describe latest tag
* `tchl` : checkout latest tag
* `ts <tag>` : annotated tag
* `tss <tag>` : annotated tag + push
* `td <tag>` : delete local tag
* `tdd <tag>` : delete local + remote tag
* `tpp` : push --tags

## user config
* `gun` : config user.name
* `gue` : config user.email
* `gut` : list current user.* config

## credential helper
* `gcn` : cache credentials (no timeout)
* `gcc` : cache credentials (default timeout)
* `gcd` : unset credential helper

## rebase
* `squash <n>` : rebase -i HEAD~n

## graph / log
* `g` : current branch graph
* `ag` : all branch graph
* `ga <author>` : current graph by author
* `aga <pattern>` : all graph by commit message (grep)
* `gg` : remote graph
* `agg` : all remote graph
* `gga <author>` : remote graph by author
* `agga <author>` : all remote graph by author
