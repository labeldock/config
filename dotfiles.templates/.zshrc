# brew install zplug
export ZPLUG_HOME=/usr/local/opt/zplug
source $ZPLUG_HOME/init.zsh

# Plugins
zplug "plugins/git",   from:oh-my-zsh
zplug "plugins/tmux", from:oh-my-zsh
#zplug "lib/completion",   from:oh-my-zsh
#zplug 'lib/key-bindings', from:oh-my-zsh
#zplug "lib/directories",  from:oh-my-zsh

zplug "zsh-users/zsh-apple-touchbar"
zplug "zsh-users/zsh-syntax-highlighting"
zplug "zsh-users/zsh-history-substring-search"
zplug "zsh-users/zsh-autosuggestions"

# THEME!
zplug romkatv/powerlevel10k, as:theme, depth:1

# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

# Then, source plugins and add commands to $PATH
zplug load