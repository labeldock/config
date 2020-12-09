#!/bin/sh
main() {
  cp template/kiosk.sh ~/kiosk.sh
  echo "Copy ~/kiosk.sh"
  sudo cp template/kiosk.service /lib/systemd/system/kiosk.service
  echo "Copy /lib/systemd/system/kiosk.service"

  local ENABLE_RIGHT_NOW
  read_val "Start up service enable? [y/n]" ENABLE_RIGHT_NOW
  
  if [ "$ENABLE_RIGHT_NOW" -eq "y" ]; then
    sudo systemctl enable kiosk.service && echo "Success enable kiosk.service"
  else
    echo "To use the startup service, use the command below"
    echo ""
    echo "# sudo systemctl enable kiosk.service"
    echo ""
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