#!/bin/bash

# ask_nth CHOICE "RED" "BLUE"
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

# read_nth number ...CHOICES
read_nth() {
  local n=$1
  shift
  local string="$*"
  local words=($string)
  if [[ $n -gt 0 && $n -le ${#words[@]} ]]; then
    echo "${words[$((n-1))]}"
  fi
}

# exectue function
# call_nth 1 ...FUNCTIONS
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

# deprecated (unused)
eval_keys() {
  local map=$1
  for key in $(echo "${!map[@]}" | tr ' ' '\n' | sort); do
    echo "$key"
  done
}

# deprecated (unused)
eval_values() {
  local map=$1
  for key in $(echo "${map[@]}" | tr ' ' '\n' | sort); do
    echo "$key"
  done
}


# ENTRIES=()
# ENTRIES+=("Rice todo")
# ENTRIES+=("Coke todo description")
# ENTRIES+=("Ice exitConfig")

# echo $(entries_to_words ENTRIES)
# Rico Coke Ice

# echo $(entries_to_words ENTRIES) 1
# Rico Coke Ice

# echo $(entries_to_words ENTRIES) 2
# Rico Coke Ice

# echo $(entries_to_words ENTRIES) 3
# NULL description NULL

# echo $(entries_to_words ENTRIES) 4
# NULL NULL NULL

entries_to_words () {
  local entries=("${!1}")  # 첫 번째 인자로 받은 배열
  local word_num=${2:-1}   # 두 번째 인자로 받은 단어 번호 (기본값: 1)

  local result=()          # 추출된 단어를 저장할 배열
  for entry in "${entries[@]}"; do
    local words=($entry)  # entry를 단어로 분리하여 배열로 저장
    local word=${words[word_num-1]:-NULL}  # 지정된 단어 추출 (없으면 NULL)
    result+=("$word")     # 추출된 단어를 결과 배열에 추가
  done
  echo "${result[*]}"
}

