#!/usr/bin/env bash
# doctor — 셸 rc 파일의 잘못된 설정을 찾아 고친다.
#
# 점검 항목
#   1. 같은 `#~/config:...` 마커 줄이 여러 번 들어간 경우            → 중복 줄 삭제
#   2. 예전 onboard 가 넣은 `~/.local/bin/mise activate` 하드코딩 줄  → 경로 독립적인 줄로 교체
#   3. `#~/config:<tag>:source` 줄이 가리키는 템플릿이 없는 경우       → 현재 레포 경로로 교체
#   4. `eval "$(<절대경로> ...)"` 의 실행 파일이 없는 경우              → PATH 기준 호출로 교체 / 주석 처리
#   5. `source <절대경로>` / `. <절대경로>` 의 파일이 없는 경우          → 주석 처리
#   6. onboard 의 mise activate 줄 외에 다른 mise activate 줄이 또 있는 경우 → 주석 처리
#   7. macOS 에 Homebrew 가 있는데 어떤 프로파일에도 `brew shellenv` 가 없는 경우 → 추가
#
# 고칠 때는 원본을 `<rc>.onboard-backup-<시각>` 으로 백업하고, 줄을 지우기보다
# 주석 처리하는 쪽을 택한다(삭제는 완전히 같은 마커 줄이 중복된 경우뿐).
#
# Requires: lib/ui.sh, lib/onboard.sh 가 먼저 source 되어 있어야 하고,
#           DOTFILES_DIR / XDG_DIR 가 설정되어 있어야 한다(onboard 가 설정).
# Targets bash 3.2+ (macOS 기본 bash).

DR_RC_FILES=(".bashrc" ".zshrc" ".bash_profile" ".zprofile" ".profile")
DR_COMMENT_PREFIX='# [onboard doctor] '
DR_MISE_FLAG='#~/config:mise:activate:flag'
DR_BREW_FLAG='#~/config:brew:shellenv:flag'

# 발견된 이슈 (같은 인덱스끼리 한 건)
DR_FILE=() DR_LINE=() DR_ACTION=() DR_TEXT=() DR_DESC=() DR_BEFORE=()

dr__reset() {
  DR_FILE=() DR_LINE=() DR_ACTION=() DR_TEXT=() DR_DESC=() DR_BEFORE=()
}

# dr__add FILE LINE ACTION TEXT DESC BEFORE
#   ACTION: replace | comment | delete | append
# 같은 파일의 같은 줄에 이미 이슈가 있으면 무시한다(한 줄에 수정은 하나만).
dr__add() {
  local i
  if [ "$3" != append ]; then
    for ((i=0; i<${#DR_FILE[@]}; i++)); do
      [ "${DR_FILE[$i]}" = "$1" ] && [ "${DR_LINE[$i]}" = "$2" ] && return 0
    done
  fi
  DR_FILE+=("$1"); DR_LINE+=("$2"); DR_ACTION+=("$3")
  DR_TEXT+=("$4"); DR_DESC+=("$5"); DR_BEFORE+=("$6")
}

# 마커 tag → 현재 레포의 템플릿 경로 (apply_rc_source 호출부와 맞춰야 함)
dr__template_for_tag() {
  case "$1" in
    tmux|herdr|completion) echo "$DOTFILES_DIR/$1.bashrc.template" ;;
    claude)                echo "$DOTFILES_DIR/.claude/.bashrc.template" ;;
    opencode)              echo "$XDG_DIR/opencode/.bashrc.template" ;;
    *)                     return 1 ;;
  esac
}

# `~/x`, `$HOME/x`, `${HOME}/x` 를 실제 경로로. 그 밖의 변수가 들어 있으면 실패.
dr__expand_path() {
  local p="$1"
  case "$p" in
    '~/'*)       p="$HOME/${p#'~/'}" ;;
    '$HOME/'*)   p="$HOME/${p#'$HOME/'}" ;;
    '${HOME}/'*) p="$HOME/${p#'${HOME}/'}" ;;
  esac
  case "$p" in
    *'$'*) return 1 ;;
    /*)    printf '%s\n' "$p" ;;
    *)     return 1 ;;
  esac
}

# dr__guarded LINE RAW — 줄이 RAW 경로 자체의 존재를 먼저 검사하면(`[ -x RAW ] && ...`) 안전한 줄로 본다.
dr__guarded() {
  local line="$1" raw="$2" op
  for op in -x -f -r -e -s; do
    case "$line" in
      *"$op $raw"*|*"$op \"$raw\""*) return 0 ;;
    esac
  done
  case "$line" in
    *"command -v $raw"*|*"command -v \"$raw\""*) return 0 ;;
  esac
  return 1
}

dr__shell_of_rc() {
  case "$1" in
    *zshrc|*zprofile) echo zsh ;;
    *)                echo bash ;;
  esac
}

# 한 rc 파일을 점검한다.
dr__scan_rc() {
  local rc="$1"
  local shell_name; shell_name=$(dr__shell_of_rc "$rc")
  local re_marker='(#~/config:[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+(:[A-Za-z0-9_.-]+)?)'
  local re_source_marker='^\[ -f "([^"]+)" \] && \. "[^"]+" #~/config:([A-Za-z0-9_.-]+):source'
  local re_eval='eval[[:space:]]+"\$\(([^[:space:])"]+)'
  local re_dot='^[[:space:]]*(source|\.)[[:space:]]+"?([^[:space:]";|&]+)'
  local re_comment='^[[:space:]]*#'
  local n=0 line seen=$'\n' marker raw path tag want name new
  local has_mise_flag=0 other_mise_lines=""

  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    # 주석 줄(앞 공백 허용)은 건너뛴다. 마커는 줄 끝에 붙으므로 영향 없음.
    [[ $line =~ $re_comment ]] && continue

    # 1. 마커 중복
    if [[ $line =~ $re_marker ]]; then
      marker="${BASH_REMATCH[1]}"
      if [[ $seen == *$'\n'"$marker"$'\n'* ]]; then
        dr__add "$rc" "$n" delete "" "같은 설정 줄이 중복됨 ($marker)" "$line"
        continue
      fi
      seen="$seen$marker"$'\n'
    fi

    # 2. 예전 mise activate 하드코딩 줄
    if [[ $line == *"$DR_MISE_FLAG"* ]]; then
      has_mise_flag=1
      if [[ $line == *'~/.local/bin/mise activate'* ]]; then
        dr__add "$rc" "$n" replace "$(ob__mise_activation_line "$shell_name" "$DR_MISE_FLAG")" \
          "mise 경로가 ~/.local/bin 으로 고정되어 있음 (brew 설치 시 오류)" "$line"
      fi
      continue
    fi

    # 3. 템플릿이 사라진 source 줄
    if [[ $line =~ $re_source_marker ]]; then
      path="${BASH_REMATCH[1]}" tag="${BASH_REMATCH[2]}"
      [ -f "$path" ] && continue
      if want=$(dr__template_for_tag "$tag") && [ -f "$want" ]; then
        dr__add "$rc" "$n" replace "[ -f \"$want\" ] && . \"$want\" #~/config:${tag}:source" \
          "$tag 템플릿 경로가 없음 → 현재 레포 경로로 교체" "$line"
      else
        dr__add "$rc" "$n" comment "" "$tag 템플릿을 찾을 수 없음 → 주석 처리" "$line"
      fi
      continue
    fi

    # 6. 사용자가 따로 넣은 mise activate 줄 (판단은 루프 뒤에서)
    if [[ $line == *'mise activate'* || $line == *'mise'*'activate'* ]] && [[ $line == *eval* ]]; then
      other_mise_lines="$other_mise_lines $n"
    fi

    # 4. eval "$(<절대경로> ...)" 의 실행 파일이 없음
    if [[ $line =~ $re_eval ]]; then
      raw="${BASH_REMATCH[1]}"
      if ! dr__guarded "$line" "$raw" && path=$(dr__expand_path "$raw") && [ ! -x "$path" ]; then
        name="${path##*/}"
        if [ "$name" = mise ] && [ "$has_mise_flag" = 1 ]; then
          dr__add "$rc" "$n" comment "" "$raw 가 없음 (mise activate 는 이미 있음) → 주석 처리" "$line"
        elif [ "$name" = mise ]; then
          new=$(ob__mise_activation_line "$shell_name" "$DR_MISE_FLAG")
          has_mise_flag=1
          seen="$seen$DR_MISE_FLAG"$'\n'   # 뒤에 오는 onboard mise 줄은 중복으로 처리
          dr__add "$rc" "$n" replace "$new" "$raw 가 없음 → 설치 위치와 무관한 mise activate 로 교체" "$line"
        elif ob_has "$name"; then
          new="command -v $name >/dev/null 2>&1 && ${line/"$raw"/$name}"
          dr__add "$rc" "$n" replace "$new" "$raw 가 없음 → PATH 의 $name 사용" "$line"
        else
          dr__add "$rc" "$n" comment "" "$raw 가 없음 → 주석 처리" "$line"
        fi
        continue
      fi
    fi

    # 5. source/. <절대경로> 의 파일이 없음
    if [[ $line =~ $re_dot ]]; then
      raw="${BASH_REMATCH[2]}"
      if ! dr__guarded "$line" "$raw" && path=$(dr__expand_path "$raw") && [ ! -e "$path" ]; then
        dr__add "$rc" "$n" comment "" "$raw 파일이 없음 → 주석 처리" "$line"
        continue
      fi
    fi
  done < "$rc"

  # 6. onboard 의 mise activate 줄과 별도 mise activate 줄이 같이 있으면 activate 가 두 번 돈다.
  #    onboard 줄은 PATH(또는 ~/.local/bin)에서 mise 를 찾으므로, 그 경로로 찾을 수 있는
  #    표준 위치의 mise 를 부르는 줄만 주석 처리한다(특이한 경로면 손대지 않음).
  if [ "$has_mise_flag" = 1 ] && [ -n "$other_mise_lines" ]; then
    for n in $other_mise_lines; do
      line=$(sed -n "${n}p" "$rc")
      [[ $line =~ $re_eval ]] || continue
      raw="${BASH_REMATCH[1]}"
      case "$raw" in
        mise|/opt/homebrew/bin/mise|/usr/local/bin/mise|/home/linuxbrew/.linuxbrew/bin/mise) ;;
        '~/.local/bin/mise'|'$HOME/.local/bin/mise'|'${HOME}/.local/bin/mise') ;;
        *) continue ;;
      esac
      dr__add "$rc" "$n" comment "" "mise activate 가 중복됨 (onboard 줄이 이미 있음) → 주석 처리" "$line"
    done
  fi
}

# 7. macOS: Homebrew 가 있는데 PATH 설정(brew shellenv)이 없음
dr__scan_brew() {
  [ "$(uname -s 2>/dev/null)" = Darwin ] || return 0
  local brew="" f target
  for f in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$f" ] && { brew="$f"; break; }
  done
  [ -n "$brew" ] || return 0
  for f in "${DR_RC_FILES[@]}"; do
    grep -q 'brew shellenv' "$HOME/$f" 2>/dev/null && return 0
  done
  case "${SHELL:-}" in
    *zsh) target="$HOME/.zprofile" ;;
    *)    target="$HOME/.bash_profile" ;;
  esac
  dr__add "$target" 0 append "[ -x $brew ] && eval \"\$($brew shellenv)\" $DR_BREW_FLAG" \
    "brew 가 설치되어 있지만 PATH 설정(brew shellenv)이 없음 → 추가" ""
}

# dr_scan — 모든 점검을 돌려 DR_* 배열을 채운다. 이슈 수를 stdout 이 아닌 DR_COUNT 로 남긴다.
dr_scan() {
  dr__reset
  local f
  for f in "${DR_RC_FILES[@]}"; do
    [ -f "$HOME/$f" ] && dr__scan_rc "$HOME/$f"
  done
  dr__scan_brew
  DR_COUNT=${#DR_FILE[@]}
}

# dr__apply_file RC "IDX IDX ..." — 선택된 이슈 중 RC 에 해당하는 것을 적용.
dr__apply_file() {
  local rc="$1" idxs="$2" i fixes tmp backup changed=0
  fixes=$(mktemp) || return 1
  for i in $idxs; do
    [ "${DR_FILE[$i]}" = "$rc" ] || continue
    [ "${DR_ACTION[$i]}" = append ] && continue
    printf '%s\t%s\t%s\n' "${DR_LINE[$i]}" "${DR_ACTION[$i]}" "${DR_TEXT[$i]}" >> "$fixes"
    changed=1
  done
  for i in $idxs; do
    [ "${DR_FILE[$i]}" = "$rc" ] && [ "${DR_ACTION[$i]}" = append ] && changed=1
  done
  if [ "$changed" = 0 ]; then rm -f "$fixes"; return 0; fi

  if [ -f "$rc" ]; then
    backup="$rc.onboard-backup-$(date +%Y%m%d%H%M%S)"
    cp -p "$rc" "$backup"
  else
    touch "$rc"
  fi

  if [ -s "$fixes" ]; then
    tmp=$(mktemp) || { rm -f "$fixes"; return 1; }
    PREFIX="$DR_COMMENT_PREFIX" awk -F'\t' '
      NR == FNR { act[$1] = $2; txt[$1] = substr($0, length($1) + length($2) + 3); next }
      (FNR in act) {
        a = act[FNR]
        if (a == "replace")      print txt[FNR]
        else if (a == "comment") print ENVIRON["PREFIX"] $0
        next                                  # delete: 출력하지 않음
      }
      { print }
    ' "$fixes" "$rc" > "$tmp" && cat "$tmp" > "$rc"   # cat > 로 써서 심볼릭 링크/권한 유지
    rm -f "$tmp"
  fi
  rm -f "$fixes"

  for i in $idxs; do
    [ "${DR_FILE[$i]}" = "$rc" ] && [ "${DR_ACTION[$i]}" = append ] || continue
    printf '\n%s\n' "${DR_TEXT[$i]}" >> "$rc"
  done

  printf '%s✓%s %s 수정됨' "$UI_GREEN" "$UI_RESET" "$rc"
  [ -n "${backup:-}" ] && printf ' %s(백업: %s)%s' "$UI_DIM" "$backup" "$UI_RESET"
  printf '\n'
}

# dr_apply "IDX IDX ..." — 선택된 이슈를 파일별로 적용.
dr_apply() {
  local idxs="$1" i f done_files=$'\n'
  for i in $idxs; do
    f="${DR_FILE[$i]}"
    [[ $done_files == *$'\n'"$f"$'\n'* ]] && continue
    done_files="$done_files$f"$'\n'
    dr__apply_file "$f" "$idxs"
  done
}

dr__short_path() {
  case "$1" in
    "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
    *)         printf '%s' "$1" ;;
  esac
}

# dr_report — 이슈 목록과 변경 미리보기를 출력.
dr_report() {
  local i where
  for ((i=0; i<DR_COUNT; i++)); do
    where=$(dr__short_path "${DR_FILE[$i]}")
    [ "${DR_ACTION[$i]}" != append ] && where="$where:${DR_LINE[$i]}"
    printf '%s%d)%s %s%s%s — %s\n' "$UI_BOLD" "$((i + 1))" "$UI_RESET" "$UI_CYAN" "$where" "$UI_RESET" "${DR_DESC[$i]}"
    [ -n "${DR_BEFORE[$i]}" ] && printf '   %s- %s%s\n' "$UI_YELLOW" "${DR_BEFORE[$i]}" "$UI_RESET"
    case "${DR_ACTION[$i]}" in
      replace|append) printf '   %s+ %s%s\n' "$UI_GREEN" "${DR_TEXT[$i]}" "$UI_RESET" ;;
      comment)        printf '   %s+ %s%s%s\n' "$UI_GREEN" "$DR_COMMENT_PREFIX" "${DR_BEFORE[$i]}" "$UI_RESET" ;;
      delete)         printf '   %s(삭제)%s\n' "$UI_DIM" "$UI_RESET" ;;
    esac
  done
}
