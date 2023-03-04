#!/bin/bash
ask_nth () {
  local var_name=$1
  shift
  local options=("$@")
  local num_options=${#options[@]}
  
  for i in $(seq 1 $num_options); do
    echo "$i) ${options[$i-1]}"
  done
  
  while true; do
    read -p "Enter your choice: " choice
    for i in $(seq 1 $num_options); do
      if [[ "$choice" == "$i" || "$choice" == "${options[$i-1]}" ]]; then
        choice=$i
        break 2
      fi
    done
    echo "Invalid choice. Please enter a valid option."
  done
  
  eval "$var_name=$choice"
}

call_nth() {
  local n="$1"
  shift
  local funcs=("$@")
  
  if (( n < 1 || n > ${#funcs[@]} )); then
    echo "Run number is incorrect."
    exit 1
  fi
  
  local func="${funcs[$((n-1))]}"
  if [[ "$(type -t "$func")" != "function" ]]; then
    echo "[$func] is not an executable function"
    exit 1
  fi
  
  "$func"
}

call_all() {
  for arg in "$@"; do
    "$arg"
  done
}

eval_keys() {
  local -n map=$1
  for key in $(echo "${!map[@]}" | tr ' ' '\n' | sort); do
    echo "$key"
  done
}

eval_values() {
  local -n map=$1
  for key in $(echo "${map[@]}" | tr ' ' '\n' | sort); do
    echo "$key"
  done
}
