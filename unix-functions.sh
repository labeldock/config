#!/bin/bash

# setting
. ./helper.sh
CONFIG_TEMPLATES_PATH="$HOME/config/dotfiles.templates"
CONFIG_ACTIVE_PATH="$HOME/config/dotfiles.active"

# read_val "프롬프트 질문 내용" "변수이름"
read_val() {
  if [[ ! -z $2 ]]; then
    local val
    printf "$1"
    read -e val
    eval "$2='${val}'"
  fi
}

# default_with_read_val "변수이름" "기본입력값" "변수이름에 값이 없을시 프롬프트 활성화 하며 물어볼 내용"
default_with_read_val() {
  if [[ -z $2 || $2 == false ]]; then
    eval "read_val '$3' $1"
  else
    eval "$1='$2'"
  fi
}


configRemoveActivedDotfils() {
  if [[ -z $1 ]]; then
    return 1
  fi
  
  rm -rf $CONFIG_ACTIVE_PATH/$1
  rm -rf $HOME/$1
  
  echo "remove file $CONFIG_ACTIVE_PATH/$1"
  echo "remove file $HOME/$1"
}

configCopyAndLinkDotfils() {
  if [[ -z $1 ]]; then
    return 1
  fi
  configRemoveActivedDotfils $1
  
  if [[ -d "$CONFIG_TEMPLATES_PATH/$1" ]]; then
    cp -rf $CONFIG_TEMPLATES_PATH/$1 $CONFIG_ACTIVE_PATH/$1
    echo "copy directory $CONFIG_ACTIVE_PATH/$1"
  else
    cp $CONFIG_TEMPLATES_PATH/$1 $CONFIG_ACTIVE_PATH/$1
    echo "copy file $CONFIG_ACTIVE_PATH/$1"
  fi
  
  ln -sf $CONFIG_ACTIVE_PATH/$1 $HOME/$1
  echo "link file $CONFIG_ACTIVE_PATH/$1 => $HOME/$1"
}

#softtab $1 = softtab $2 = $tabsize
configTmPropertiesReadVal() {
  read -p "TextMate::softtab? [true/false] " softtab
  read -p "TextMate::tabsize? (2/4/...) " tabsize
  echo "1 $softtab $tabsize"
  eval "$1='$softtab'"
  eval "$2='$tabsize'"
}

# $1 = path $2 = $softtab $3 = $tabsize
configTmPropertiesSet(){
  if [[ $2 ]]
  then
    echo "softWrap=$2" >> "$1"
    echo "softTabs=$2" >> "$1"
  fi
      
  if [[ $3 ]]
  then
    echo "tabSize=$3" >> "$1"
  fi
}


function configunixfunctions {
  
  echo "Please select"
  call_nth

  echo -e "Your pwd => $PWD\nENTER COMMAND\ni!) setup or resetup \ngu) git user \ngc) git credential timeout\ntmp) local tm_properties \nvundle) install vim bundle from .vimrc \nrvm) rvm-setup \nnvm) nvm-setup \nnl) nvm install lts \nnpmi!)clean and install npm \nkp) Kill processor by port"
  read selected

  case "$selected" in
  "i!")
    # automatic install
    local AUTOMATIC_INSTALL
    read_val "Do you want to install all of them AUTOMATIC_INSTALL? [y] " AUTOMATIC_INSTALL
    [[ $AUTOMATIC_INSTALL =~ ^(y|Y)$ ]] && AUTOMATIC_INSTALL=y || AUTOMATIC_INSTALL=false
    
    
    # setup vundle
    local SHOULD_SETUP_GIT
    local SHOULD_SETUP_VIM
    local SHOULD_SETUP_TMUX
    local SHOULD_SETUP_TM_PROPERTIES
    
    default_with_read_val SHOULD_SETUP_GIT $AUTOMATIC_INSTALL "Do you setup .gitconfig? [y] "
    default_with_read_val SHOULD_SETUP_VIM $AUTOMATIC_INSTALL "Do you setup .vimrc and vundle? [y] "
    default_with_read_val SHOULD_SETUP_TMUX $AUTOMATIC_INSTALL "Do you setup setup .tmux.conf? [y] "
    default_with_read_val SHOULD_SETUP_TM_PROPERTIES $AUTOMATIC_INSTALL "Do you setup .tm_properties? [y] "
    
    #
    local TM_SOFTTAB=true
    local TM_TABSIZE=2
    if [[ $SHOULD_SETUP_TM_PROPERTIES == "y" && $AUTOMATIC_INSTALL == false ]]; then
      configTmPropertiesReadVal TM_SOFTTAB TM_TABSIZE
    fi
    
    
    # backup legacy dotfiles
    local UTIME=$(date +%s)
    if [[ -d $HOME/config/dotfiles.active ]]; then
      cp -rf "$HOME/config/dotfiles.active" "$HOME/config/dotfiles.backup.$UTIME"
    fi
    
    
    if [[ ! -d $CONFIG_ACTIVE_PATH ]]; then
      mkdir $CONFIG_ACTIVE_PATH
    fi
    
    
    # .gitconfig
    if [[ $SHOULD_SETUP_GIT == 'y' ]]; then
      configCopyAndLinkDotfils ".gitconfig"
    fi
    
    
    # git, vundle
    if [[ $SHOULD_SETUP_VIM == 'y' ]]; then
      rm -rf "$CONFIG_TEMPLATES_PATH/.vim/bundle/Vundle.vim"
      git clone https://github.com/VundleVim/Vundle.vim.git "$CONFIG_TEMPLATES_PATH/.vim/bundle/Vundle.vim/"
      
      sleep 2
      configCopyAndLinkDotfils ".vimrc"
      configCopyAndLinkDotfils ".vim"
      
      vim +PluginInstall +qall
      echo "install complete vundle"
    fi
    
    
    # setup tmux
    if [[ $SHOULD_SETUP_TMUX == 'y' ]]; then
      configCopyAndLinkDotfils ".tmux.conf"
      tmux source-file ~/.tmux.conf
    fi
    
    
    # setup textmate
    if [[ $SHOULD_SETUP_TM_PROPERTIES == 'y' ]]; then
      configCopyAndLinkDotfils ".tm_properties"
      echo "softWrap=${TM_SOFTTAB}" >> "$CONFIG_ACTIVE_PATH/.tm_properties"
      echo "softTabs=${TM_TABSIZE}" >> "$CONFIG_ACTIVE_PATH/.tm_properties"
    fi

    echo "complete config i!"
    ;;
  "gu")
    local name
    local email
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
    local softtab
    local tabsize
    configTmPropertiesReadVal softtab tabsize
    
    if [[ ! -h $PWD/.tm_properties ]]; then
      touch .tm_properties
    fi
    
    configTmPropertiesSet "$PWD/.tm_properties" $softtab $tabsize
    ;;
  "rvm")
    curl -sSL https://get.rvm.io | bash -s stable
    ;;
  "nvm")
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
    ;;
  "nl")
    nvm install lts/*
    ;;
  "npmi!")
    if [[ -d node_modules ]]; then
      rm -rf node_modules
    else
      echo "node_modules is not exsist"
    fi
    
    if [[ -e package-lock.json ]]; then
      rm -f pacakge-lock.json
    else
      echo "pacakge-lock.json is not exsist"
    fi
    
    if [[ -e package.json ]]; then
      npm install
    else
      echo "You can not install the npm package because package.json is not exsist"
    fi
  ;;
  "kp")
    local KILL_PORT
    echo "Please enter the port the processor is using. ex) 8080"
    read KILL_PORT
    kill -9 $(lsof -t -i:$KILL_PORT) && echo "kp $KILL_PORT command success" || echo "kp $KILL_PORT command failed"
  ;;
  esac
}