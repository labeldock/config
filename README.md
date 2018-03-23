# config
This is a collection of my vim, tmux, and other configs.

# thanks
[A reference code](https://github.com/dsdstudio/dotfiles)

# install
You must have git installed. and..
```bash
cd ~ && git clone https://github.com/labeldock/config.git
```

# setting
```bash
#bash
vim ~/.bash_profile

#paste
[[ -s "$HOME/config/unix-init.sh" ]] && source "$HOME/config/unix-init.sh"

#:wq

# reopen terminal

config
i!
```

# GIT alias
## basic command
* ago : The degree of change of remote and current brunch
* pick : Cherry pick's Shortcut
* s :(status) This is a shortcut for 'git status'. I can see the contents of the brunch.
* ch :(change) It's a shortcut to 'git checkout'.
* rch :(remote change) Checkout the remote brunch as a local brunch.
* rp  :(remote push) Upload a local brunch that is not registered on the remote.
* rpp :(remote push with stream) Upload a local brunch that is not registered on the remote.
* rd :(remote delete) Delete the remote brunch, such as the current local brunch, from the remote.
* fs :(feature start) checkout (Feature start)
* fd :(feature delete) Delete current branche (Feature delete)
* aa :(add all) git add --all
* ai :(add intractive) git add --interactive
* ap :(add patch) git add --patch
* cm :(commit) git commit -m
* un :(unstage) View the unindexed diff.
* in : View the indexed diff.
* inn : Compare to previous commit.
* undo : Cancel the current commit.
* co : (checkout -- file) Change to the contents of the previous commit. [ git co . | git cf path/file.md ]
* cf : (clean unstage file) delete unstage file with [ git cf . | git cf file.md ]
* i : Find the git setting.
## graph command
* ag : All graph
* g : Curret graph
* aga : Find all graph with author param
* ga : Find graph with author
* agg : All remote graph
* gg : Remote graph
* agga : Find all remote graph with author param
* gga : Find remote graph with author param
