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
0!
```

#GIT alias
## basic command
* ago : The degree of change of remote and current brunch
* ma : Go to Master Brunch
* pick : Cherry pick's Shortcut
* s : This is a shortcut for 'git status'. I can see the contents of the brunch.
* ch : It's a shortcut to 'git checkout'.
* rch : Checkout the remote brunch as a local brunch.
* rp : Upload a local brunch that is not registered on the remote.
* rpp : Upload a local brunch that is not registered on the remote.
* rd : Delete the remote brunch, such as the current local brunch, from the remote.
* fs : checkout (Feature start)
* fm : Run the 'no fast forward' merge from the current brunch on the master.
* fr : Run the 'rebase' merge from the current brunch on the master.
* fd : Delete current branche (Feature delete)
* aa : git add --all
* ai : git add --interactive
* ap : git add --patch
* np : git reset --patch
* cm : git commit -m
* un : View the unindexed diff.
* in : View the indexed diff.
* undo : Cancel the current commit.
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