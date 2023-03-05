#!/bin/bash
. ../helper.sh

installAll (){
  echo "installAll start"
  installTmux
  installHtop
  echo "installAll end"
}
installTmux (){
  echo "You have installed tmux."
}
installHtop (){
  echo "You have installed htop."
}

declare -A installMap

installMap["all"]=installAll
installMap["tmux"]=installTmux
installMap["htop"]=installHtop

echo $(eval_keys installMap)
echo $(eval_values installMap)
call_all $(eval_values installMap)
