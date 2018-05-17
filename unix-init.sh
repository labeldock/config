#!/bin/sh

# paste to ~/.bash_profile
# [[ -s "$HOME/config/unix-init.sh" ]] && source "$HOME/config/unix-init.sh"

echo "ACTIVATE CUSTOM CONFIG ($HOME/config/unix-source/)"

# setting
LINK_TARGET_FILES=".gitconfig .vim .vimrc .tmux.conf .tm_properties"

function configbootstrap {
  # 미리 정의해놓은 설정파일들 링크 처리
  for FILE_ITEM in $LINK_TARGET_FILES
  do

    if [ ! -h $HOME/$FILE_ITEM ]
    then
      echo "link file $HOME/config/unix-source/$FILE_ITEM"
      ln -sf $HOME/config/unix-source/$FILE_ITEM $HOME/$FILE_ITEM
    fi
  done
}

function vundleinstall {
  vim +PluginInstall +qall
}

# command
function config {

  echo -e "Your pwd => $PWD\nENTER COMMAND\ni!) setup or resetup\nr!) reload your all config \ngu) git user \ngc) git credential timeout\ntmp) local tm_properties \nvundle) install vim bundle from .vimrc \nrvm) rvm-setup \nnvm) nvm-setup \nnpmi!)clean and install npm"
  read selected

  case "$selected" in
  "i!")
    local UTIME=$(date +%s)

    if [ -d $HOME/config/unix-source ]
    then
      cp -rf "$HOME/config/unix-source" "$HOME/config/unix-source.removed.$UTIME"
      rm -rf "$HOME/config/unix-source"
      echo "removed $HOME/config/unix-source"
    fi
        
    rm -rf "$HOME/config/unix-source.default/.vim/bundle/Vundle.vim"
    git clone https://github.com/VundleVim/Vundle.vim.git "$HOME/config/unix-source.default/.vim/bundle/Vundle.vim/"
        
    cp -rf "$HOME/config/unix-source.default" "$HOME/config/unix-source"
    echo "copyed $HOME/config/unix-source.default to $HOME/config/unix-source"
        
    for FILE_ITEM in $LINK_TARGET_FILES
    do
      rm $HOME/$FILE_ITEM
      echo "rm $FILE_ITEM"
    done
        
    configbootstrap
        
    vundleinstall

    tmux source-file ~/.tmux.conf
    ;;
  "r!")
    source "$HOME/config/unix-init.sh"
    ;;
  "gu")
    echo "user name"
    read name
    echo "user email"
    read email
        
    git config user.name "$name"
    git config user.email "$email"
        
    git config --list | grep "user."
    ;;
  "gc")
    echo "credential.helper cache timeout ? [y=forever,n|0==cancle,number=millisecond]"
    read ctimeout
        
    if [[ $ctimeout == "Y" || $ctimeout == "y" ]]; then
      git config credential.helper cache
    elif [[ $ctimeout == "M" || $ctimeout == "n" || $ctimeout == "0" ]]; then
      git config credential.helper "cache --timeout=0"
    else
      git config credential.helper "cache --timeout=$ctimeout"
    fi
        
    git config --list | grep "credential"
    ;;
  "tmp")
    if [ ! -h $PWD/.tm_properties ]
    then
      touch .tm_properties
    fi
        
    read -p "usesofttab?[true/false]" softtab
    read -p "tabsize?(2/4/...)" tabsize
        
    if [ $softtab ]
    then
      echo "softWrap=$softtab" >> "$PWD/.tm_properties"
      echo "softTabs=$softtab" >> "$PWD/.tm_properties"
    fi
        
    if [ $tabsize ]
    then
      echo "tabSize=$tabsize" >> "$PWD/.tm_properties"
    fi
    ;;
  "vundle")
    vundleinstall
    ;;
  "rvm")
    curl -sSL https://get.rvm.io | bash -s stable
    ;;
  "nvm")
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
    ;;
  "npmi!")
    if [ -d node_modules ]
    then
      rm -rf node_modules
    else
      echo "node_modules is not exsist"
    fi
    
    if [ -e package-lock.json ]
    then
      rm -f pacakge-lock.json
    else
      echo "pacakge-lock.json is not exsist"
    fi
    
    if [ -e package.json ]
    then
      npm install
    else
      echo "You can not install the npm package because package.json is not exsist"
    fi
    ;;
  esac

}

# alias
alias mfzf='mate $(fzf)'
alias vfzf='vim $(fzf)'
