#!/bin/bash
. ../helper.sh

echo "What's your favorite color?"
ask_nth CHOICE "RED" "GREEN" "BLUE"
echo "You chose ${CHOICE}"

ask_nth CHOICE 11 12 123
echo "You chose ${CHOICE}"

installAll (){
  installTmux
  installHtop
}
installTmux (){
  echo "You have installed tmux."
}
installHtop (){
  echo "You have installed htop."
}
echo "What would you like to install?"

INSTALLS="all tmux htop"
ask_nth CHOICE $INSTALLS
call_nth CHOICE installAll installTmux installHtop
