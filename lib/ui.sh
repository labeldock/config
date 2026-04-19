#!/usr/bin/env bash
# Interactive menu helpers.
# Arrow keys + Space (toggle) + Enter (confirm) + Esc/q (cancel).
# Targets bash 3.2+ (macOS default) and Git Bash.

if [ -t 1 ]; then
  UI_RESET=$'\033[0m'
  UI_BOLD=$'\033[1m'
  UI_DIM=$'\033[2m'
  UI_CYAN=$'\033[36m'
  UI_GREEN=$'\033[32m'
  UI_YELLOW=$'\033[33m'
else
  UI_RESET= UI_BOLD= UI_DIM= UI_CYAN= UI_GREEN= UI_YELLOW=
fi

UI__TTY_STATE=""

ui__tty_enter() {
  UI__TTY_STATE=$(stty -g 2>/dev/null)
  stty -icanon min 1 time 0 -echo 2>/dev/null
}
ui__tty_leave() {
  [ -n "$UI__TTY_STATE" ] && stty "$UI__TTY_STATE" 2>/dev/null
  UI__TTY_STATE=""
}
ui__hide_cursor() { printf '\033[?25l'; }
ui__show_cursor() { printf '\033[?25h'; }

ui__clear_lines() {
  local n=$1
  while [ "$n" -gt 0 ]; do
    printf '\033[1A\033[2K'
    n=$((n - 1))
  done
}

# Read a single key and classify it.
ui__read_key() {
  local key rest
  IFS= read -rsn1 key
  if [ "$key" = $'\033' ]; then
    # Might be lone ESC or start of CSI sequence. Peek using stty timeout.
    stty min 0 time 1 2>/dev/null
    IFS= read -rsn2 rest
    stty min 1 time 0 2>/dev/null
    case "$rest" in
      '[A') printf UP ;;
      '[B') printf DOWN ;;
      *)    printf ESC ;;
    esac
  elif [ -z "$key" ]; then
    printf ENTER
  elif [ "$key" = ' ' ]; then
    printf SPACE
  elif [ "$key" = q ] || [ "$key" = Q ]; then
    printf ESC
  else
    printf OTHER
  fi
}

# ui_menu TITLE LABELS_VAR
# Sets UI_CHOICE to selected index, or 255 on cancel.
ui_menu() {
  local title="$1"
  local labels_name="$2"
  local -a labels
  eval "labels=(\"\${${labels_name}[@]}\")"
  local n=${#labels[@]}
  if [ "$n" -eq 0 ]; then UI_CHOICE=255; return 1; fi

  ui__tty_enter
  ui__hide_cursor
  trap 'ui__tty_leave; ui__show_cursor' RETURN INT TERM

  printf '%s%s%s\n' "$UI_BOLD" "$title" "$UI_RESET"
  printf '%s(↑/↓ 이동, Enter 선택, Esc/q 취소)%s\n' "$UI_DIM" "$UI_RESET"

  local idx=0 first=1 i key
  while true; do
    if [ "$first" -eq 1 ]; then first=0; else ui__clear_lines "$n"; fi
    for ((i=0; i<n; i++)); do
      if [ "$i" -eq "$idx" ]; then
        printf '  %s▶ %s%s\n' "$UI_CYAN" "${labels[$i]}" "$UI_RESET"
      else
        printf '    %s\n' "${labels[$i]}"
      fi
    done
    key=$(ui__read_key)
    case "$key" in
      UP)    idx=$(( (idx - 1 + n) % n )) ;;
      DOWN)  idx=$(( (idx + 1) % n )) ;;
      ENTER) UI_CHOICE=$idx; return 0 ;;
      ESC)   UI_CHOICE=255;  return 1 ;;
    esac
  done
}

# ui_multiselect TITLE LABELS_VAR [PRESEL_INDICES]
# Sets UI_CHOICES to space-separated indices, or "" on cancel.
ui_multiselect() {
  local title="$1"
  local labels_name="$2"
  local preselected="${3:-}"
  local -a labels
  eval "labels=(\"\${${labels_name}[@]}\")"
  local n=${#labels[@]}
  if [ "$n" -eq 0 ]; then UI_CHOICES=""; return 1; fi

  local -a marked
  local i
  for ((i=0; i<n; i++)); do marked[$i]=0; done
  for i in $preselected; do marked[$i]=1; done

  ui__tty_enter
  ui__hide_cursor
  trap 'ui__tty_leave; ui__show_cursor' RETURN INT TERM

  printf '%s%s%s\n' "$UI_BOLD" "$title" "$UI_RESET"
  printf '%s(↑/↓ 이동, Space 토글, Enter 완료, Esc/q 취소)%s\n' "$UI_DIM" "$UI_RESET"

  local idx=0 first=1 key marker
  while true; do
    if [ "$first" -eq 1 ]; then first=0; else ui__clear_lines "$n"; fi
    for ((i=0; i<n; i++)); do
      if [ "${marked[$i]}" = "1" ]; then
        marker="${UI_GREEN}[x]${UI_RESET}"
      else
        marker="[ ]"
      fi
      if [ "$i" -eq "$idx" ]; then
        printf '  %s▶%s %s %s\n' "$UI_CYAN" "$UI_RESET" "$marker" "${labels[$i]}"
      else
        printf '   %s %s\n' "$marker" "${labels[$i]}"
      fi
    done
    key=$(ui__read_key)
    case "$key" in
      UP)    idx=$(( (idx - 1 + n) % n )) ;;
      DOWN)  idx=$(( (idx + 1) % n )) ;;
      SPACE) marked[$idx]=$((1 - marked[$idx])) ;;
      ENTER)
        local out=""
        for ((i=0; i<n; i++)); do
          [ "${marked[$i]}" = "1" ] && out="$out $i"
        done
        UI_CHOICES="${out# }"
        return 0
        ;;
      ESC)
        UI_CHOICES=""
        return 1
        ;;
    esac
  done
}
