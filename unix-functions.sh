# setting
LINK_TARGET_FILES=".gitconfig .vim .vimrc .tmux.conf .tm_properties"

# read_val "프롬프트 질문 내용" "변수이름"
read_val() {
  if [ ! -z $2 ]; then
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


CONFIG_TEMPLATES_PATH=$HOME/config/dotfiles.templates
CONFIG_ACTIVE_PATH=$HOME/config/dotfiles.active

configRemoveActivedDotfils() {
  if [[ -z $1 ]]; then
    return 1
  fi
  
  rm $CONFIG_ACTIVE_PATH/$1
  rm $HOME/$1
  
  echo "link file $CONFIG_ACTIVE_PATH/$1"
}

configCopyAndLinkDotfils() {
  if [[ -z $1 ]]; then
    return 1
  fi
  
  cp $CONFIG_TEMPLATES_PATH/$1 $CONFIG_ACTIVE_PATH/$1
  echo "copy file $CONFIG_ACTIVE_PATH/$1"
  
  ln -sf $CONFIG_ACTIVE_PATH/$1 $HOME/$1
  echo "link file $CONFIG_ACTIVE_PATH/$1"
}


function configunixfunctions {
  
  echo -e "Your pwd => $PWD\nENTER COMMAND\ni!) setup or resetup \ngu) git user \ngc) git credential timeout\ntmp) local tm_properties \nvundle) install vim bundle from .vimrc \nrvm) rvm-setup \nnvm) nvm-setup \nnl) nvm install lts \nnpmi!)clean and install npm"
  read selected

  case "$selected" in
  "i!")
    read_val "Do you want to install all of them automatically?[y]" automatically
    [[ $automatically =~ ^(y|Y)$ ]] && automatically=y || automatically=false
    
    # setup vundle
    default_with_read_val setupGitConfig $automatically "Do you setup setup .gitconfig?[y]"
    default_with_read_val setupVimVundle $automatically "Do you setup .vimrc and vundle?[y]"
    default_with_read_val setupTmuxConfig $automatically "Do you setup setup .tmux.conf?[y]"
    default_with_read_val setupTmProperties $automatically "Do you setup .tm_properties?[y]"
    
    # backup legacy dotfiles
    local UTIME=$(date +%s)
    if [[ -d $HOME/config/dotfiles.active ]]; then
      cp -rf "$HOME/config/dotfiles.active" "$HOME/config/dotfiles.backup.$UTIME"
      rm -rf "$HOME/config/dotfiles.active"
      echo "removed $HOME/config/dotfiles.active"
    fi
    
    
    if [[ ! -d $CONFIG_ACTIVE_PATH ]]; then
      mkdir $CONFIG_ACTIVE_PATH
    fi
    
    
    
    # .gitconfig
    if [[ $setupGitConfig == 'y' ]]; then
      configCopyAndLinkDotfils ".gitconfig"
    else
      echo "Sorry. Custom setup is not ready yet, but it will work soon."
    fi
    
    
    # git, vundle
    if [[ $setupVimVundle == 'y' ]]; then
      configCopyAndLinkDotfils ".vimrc"
      
      rm -rf "$HOME/config/dotfiles.templates/.vim/bundle/Vundle.vim"
      git clone https://github.com/VundleVim/Vundle.vim.git "$HOME/config/dotfiles.templates/.vim/bundle/Vundle.vim/"
      vim +PluginInstall +qall
      echo "install complete vundle"
    else
      echo "Sorry. Custom setup is not ready yet, but it will work soon."
    fi
    
    
    # setup tmux
    if [[ $setupTmuxConfig == 'y' ]]; then
      configCopyAndLinkDotfils ".tmux.conf"
      tmux source-file ~/.tmux.conf
    else
      echo "Sorry. Custom setup is not ready yet, but it will work soon."
    fi
    
    
    # setup textmate
    if [[ $setupTmProperties == 'y' ]]; then
      configCopyAndLinkDotfils ".tm_properties"
    else
      echo "Sorry. Custom setup is not ready yet, but it will work soon."
    fi

    echo "complete config i!"
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