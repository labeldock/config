#!/bin/bash

main (){
  SHELL_CONFIGURATION=
  FLAG_CONFIGURATION="#~/config/bin:path:flag"
  PATH_CONFIGURATION="[ -d \"$PWD/bin\" ] && PATH=\"$PWD/bin:\$PATH\" "$FLAG_CONFIGURATION

  echo "Checking shell environment..."
  if echo $SHELL | grep -q "zsh"; then
    echo "Detected zsh shell. Using ~/.zshrc for configuration."
    SHELL_CONFIGURATION=~/.zshrc
  elif echo $SHELL | grep -q "bash"; then
    echo "Detected bash shell. Using ~/.bashrc for configuration."
    SHELL_CONFIGURATION=~/.bashrc
  else
    echo "Unsupported shell environment. Exiting..."
    exit 1
  fi

  echo "Checking if .*rc exists. Creating it if not..."
  if [ ! -f $SHELL_CONFIGURATION ]; then
    touch $SHELL_CONFIGURATION
  fi

  echo "Checking if PATH_CONFIGURATION exists in .*rc..."
  if grep -q "$FLAG_CONFIGURATION" $SHELL_CONFIGURATION; then
    existing_line=$(grep "$FLAG_CONFIGURATION" $SHELL_CONFIGURATION)
    if [ "$existing_line" != "$PATH_CONFIGURATION" ]; then 
      echo "Replacing existing line with PATH_CONFIGURATION..."
      awk -v existing="$existing_line" -v target="$PATH_CONFIGURATION" '{ if ($0 == existing) { $0=target } print }' $SHELL_CONFIGURATION > temp && mv temp $SHELL_CONFIGURATION
    else
      echo "Great job! It looks like the installation is already completed."
    fi
  else
    echo "Appending PATH_CONFIGURATION to $SHELL_CONFIGURATION..."
    echo "$PATH_CONFIGURATION" >> $SHELL_CONFIGURATION
  fi
}

main "$@"
