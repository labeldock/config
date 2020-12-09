#!/bin/sh

main() {
  local SHOULD_PURGE
  local SHOULD_SETUP_OPTIONAL
  local SHOULD_SETUP_KIOSK

  read_val "Should I purge to delete unnecessary packages? [y/n]" SHOULD_PURGE
  read_val "Install optional utils? [y/n]" SHOULD_SETUP_OPTIONAL
  read_val "Install chromium kiosk? [y/n]" SHOULD_SETUP_KIOSK

  if [ "$SHOULD_PURGE" == "y" ]; then
    ./purge-apt.sh
  fi

  ./upgrade-apt.sh
  ./install-git-vim.sh
  ./install-nvm.sh

  if [ "$SHOULD_SETUP_OPTIONAL" == "y" ]; then
    ./install-optional-utils.sh
  fi
  
  if [ "$SHOULD_SETUP_KIOSK" == "y" ]; then
    ./kiosk/kiosk-wizard.sh
  fi
}

read_val() {
  if [ ! -z $2 ]; then
    local val
    read -p "$1 " val
    eval "$2=\"$val\""
  fi
}

main