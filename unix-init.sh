#!/bin/sh

# paste to ~/.bash_profile
# [[ -s "$HOME/config/unix-init.sh" ]] && source "$HOME/config/unix-init.sh"

echo -e "ACTIVATE CUSTOM CONFIG ($HOME/config/unix-source/)"

# command
function config {
  source "$HOME/config/unix-functions.sh"
  configunixfunctions
}

# alias
alias fzm='mate $(fzf)'
alias fzv='vim $(fzf)'
