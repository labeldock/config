#!/usr/bin/env bash
# Onboarding: brew / mise / mise-managed tools / clipaste.

ob_has() { command -v "$1" >/dev/null 2>&1; }

# PATH as the user's shell had it, before ob__extend_path adds tool dirs.
OB_ORIG_PATH=${OB_ORIG_PATH:-$PATH}

# mise tool name → binary name (for `command -v` checks).
ob__bin_of() {
  case "$1" in
    ripgrep) echo rg ;;
    *)       echo "$1" ;;
  esac
}

ob_tool_installed() {
  ob_has "$(ob__bin_of "$1")"
}

# Make locally-installed tools discoverable in the current shell.
ob__extend_path() {
  local p
  for p in \
    "$HOME/.local/bin" \
    "$HOME/.local/share/mise/shims" \
    /opt/homebrew/bin \
    /usr/local/bin \
    /home/linuxbrew/.linuxbrew/bin; do
    if [ -d "$p" ] && [[ ":$PATH:" != *":$p:"* ]]; then
      export PATH="$p:$PATH"
    fi
  done
}

ob_install_brew() {
  if ob_has brew; then
    printf '%s✓%s brew already installed (%s)\n' "$UI_GREEN" "$UI_RESET" "$(command -v brew)"
    return 0
  fi
  printf '%s→%s installing Homebrew...\n' "$UI_CYAN" "$UI_RESET"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    printf '%s✗%s Homebrew install failed\n' "$UI_YELLOW" "$UI_RESET" >&2
    return 1
  }
  ob__extend_path
  if ob_has brew; then
    printf '%s✓%s brew installed (%s)\n' "$UI_GREEN" "$UI_RESET" "$(command -v brew)"
  else
    printf '%s!%s brew installed but not on PATH; add `eval "$(brew shellenv)"` to your shell rc\n' "$UI_YELLOW" "$UI_RESET"
  fi
}

ob__ensure_mise_activation() {
  local rc shell_name
  local flag='#~/config:mise:activate:flag'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    grep -qF "$flag" "$rc" && continue
    case "$rc" in
      *.bashrc) shell_name=bash ;;
      *.zshrc)  shell_name=zsh ;;
    esac
    {
      printf '\n'
      printf 'eval "$(~/.local/bin/mise activate %s)" %s\n' "$shell_name" "$flag"
    } >> "$rc"
    printf '%s+%s mise activation added to %s\n' "$UI_CYAN" "$UI_RESET" "$rc"
  done
}

ob_install_mise() {
  if ob_has mise; then
    printf '%s✓%s mise already installed (%s)\n' "$UI_GREEN" "$UI_RESET" "$(command -v mise)"
    ob__ensure_mise_activation
    return 0
  fi
  printf '%s→%s installing mise...\n' "$UI_CYAN" "$UI_RESET"
  curl -fsSL https://mise.run | sh || {
    printf '%s✗%s mise install failed\n' "$UI_YELLOW" "$UI_RESET" >&2
    return 1
  }
  ob__extend_path
  ob__ensure_mise_activation
  if ob_has mise; then
    printf '%s✓%s mise installed (%s)\n' "$UI_GREEN" "$UI_RESET" "$(command -v mise)"
  else
    printf '%s!%s mise installed but not yet on PATH\n' "$UI_YELLOW" "$UI_RESET"
  fi
}

# ob_install_mise_tools tool1 tool2 ...
ob_install_mise_tools() {
  ob__extend_path
  if ! ob_has mise; then
    printf '%s✗%s mise is not installed; cannot install tools\n' "$UI_YELLOW" "$UI_RESET" >&2
    return 1
  fi
  local tool
  for tool in "$@"; do
    if ob_tool_installed "$tool"; then
      printf '%s✓%s %s already installed\n' "$UI_GREEN" "$UI_RESET" "$tool"
      continue
    fi
    printf '%s→%s installing %s@latest...\n' "$UI_CYAN" "$UI_RESET" "$tool"
    mise use -g "${tool}@latest" || printf '%s✗%s failed to install %s\n' "$UI_YELLOW" "$UI_RESET" "$tool" >&2
  done
}

# ---- clipaste ----------------------------------------------------------------
# Screenshot paste for Claude Code — locally, over SSH, and in WSL2.
# https://github.com/hqhq1025/clipaste
#
# 두 부분은 서로 다른 머신에 따로 설치한다.
#   paste server  스크린샷을 찍는 머신. 클립보드 이미지를 127.0.0.1:18340 으로 내어 준다.
#                 macOS: brew + brew services / Linux 데스크톱: 릴리스 바이너리 + 자동 시작 /
#                 Windows: windows/clipaste.cmd
#   client        Claude Code 가 도는 머신. 18340 에서 이미지를 받아 붙여넣는 도우미.
#                 macOS/Linux: dotfiles.templates/.local/bin 의 스크립트를 복사 (onboard 쪽)
#                 WSL2: 바이너리 + clipaste wsl-setup
# SSH 로 이으려면 서버 쪽 ~/.ssh/config 의 해당 Host 에 RemoteForward 18340 127.0.0.1:18340 이
# 있어야 한다. 서버에서 clipaste ssh-setup 을 돌리면 이 줄과 원격 클라이언트를 한 번에 설치한다.

OB_CLIPASTE_REPO="hqhq1025/clipaste"
OB_CLIPASTE_PORT=18340

ob_clipaste_role() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo wsl
      elif [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && [ -z "${SSH_CONNECTION:-}" ]; then
        echo linux-desktop
      else
        echo linux-remote
      fi
      ;;
    *) echo unsupported ;;
  esac
}

# Path of the installed clipaste binary, or empty.
ob_clipaste_bin() {
  if ob_has clipaste; then
    command -v clipaste
  elif [ -x "$HOME/.local/bin/clipaste" ]; then
    echo "$HOME/.local/bin/clipaste"
  fi
}

# "2.5.0" or empty
ob_clipaste_version() {
  local bin
  bin=$(ob_clipaste_bin)
  [ -n "$bin" ] || return 0
  "$bin" --version 2>/dev/null | awk '{print $2}'
}

# Latest release tag such as v2.5.0. CLIPASTE_VERSION=v2.5.0 pins it.
ob__clipaste_latest_tag() {
  if [ -n "${CLIPASTE_VERSION:-}" ]; then
    echo "$CLIPASTE_VERSION"
    return 0
  fi
  local tag
  tag=$(curl -fsSL "https://api.github.com/repos/$OB_CLIPASTE_REPO/releases/latest" 2>/dev/null |
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
  if [ -z "$tag" ]; then
    tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$OB_CLIPASTE_REPO/releases/latest" 2>/dev/null)
    tag=${tag##*/}
    case "$tag" in v[0-9]*) ;; *) tag= ;; esac
  fi
  if [ -z "$tag" ] && ob_has git; then
    tag=$(git ls-remote --tags --refs "https://github.com/$OB_CLIPASTE_REPO" 2>/dev/null |
      sed 's|.*refs/tags/||' | grep '^v[0-9]' | sort -V | tail -1)
  fi
  [ -n "$tag" ] && echo "$tag"
}

# ob__pkg_install_hint pkg... → echoes the distro install command, or nothing.
ob__pkg_install_hint() {
  if ob_has apt-get; then echo "sudo apt-get install -y $*"
  elif ob_has dnf; then echo "sudo dnf install -y $*"
  elif ob_has pacman; then echo "sudo pacman -S --needed $*"
  elif ob_has zypper; then echo "sudo zypper install -y $*"
  fi
}

# ob__ensure_packages bin:pkg ... — offer to install missing distro packages.
ob__ensure_packages() {
  local spec bin pkg cmd yn
  local missing=""
  for spec in "$@"; do
    bin=${spec%%:*}
    pkg=${spec#*:}
    ob_has "$bin" || missing="$missing $pkg"
  done
  missing=${missing# }
  [ -z "$missing" ] && return 0
  cmd=$(ob__pkg_install_hint $missing)
  printf '%s!%s missing packages: %s\n' "$UI_YELLOW" "$UI_RESET" "$missing"
  if [ -z "$cmd" ]; then
    printf '  install them with your package manager, then run this again\n'
    return 1
  fi
  printf '  %s%s%s\n  Run it now? [y/N] ' "$UI_DIM" "$cmd" "$UI_RESET"
  read -r yn
  case "$yn" in
    y|Y) $cmd ;;
    *) printf 'skipped\n'; return 1 ;;
  esac
}

# Download the release binary into ~/.local/bin/clipaste (checksum verified).
ob__clipaste_install_linux_binary() {
  local arch tag current asset base tmp
  case "$(uname -m)" in
    x86_64|amd64)  arch=x86_64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *)
      printf '%s✗%s no clipaste release for %s\n' "$UI_YELLOW" "$UI_RESET" "$(uname -m)" >&2
      return 1
      ;;
  esac

  tag=$(ob__clipaste_latest_tag)
  if [ -z "$tag" ]; then
    printf '%s✗%s could not find the latest clipaste release; pin one with CLIPASTE_VERSION=v2.5.0\n' "$UI_YELLOW" "$UI_RESET" >&2
    return 1
  fi
  current=$(ob_clipaste_version)
  if [ -n "$current" ] && [ "v$current" = "$tag" ]; then
    printf '%s✓%s clipaste %s already installed (%s)\n' "$UI_GREEN" "$UI_RESET" "$tag" "$(ob_clipaste_bin)"
    return 0
  fi

  asset="clipaste-${tag}-${arch}-unknown-linux-musl.tar.gz"
  base="https://github.com/$OB_CLIPASTE_REPO/releases/download/$tag"
  tmp=$(mktemp -d)
  printf '%s→%s downloading %s...\n' "$UI_CYAN" "$UI_RESET" "$asset"
  if ! curl -fsSL -o "$tmp/$asset" "$base/$asset" || ! curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"; then
    printf '%s✗%s download failed: %s\n' "$UI_YELLOW" "$UI_RESET" "$base/$asset" >&2
    rm -rf "$tmp"
    return 1
  fi
  if ! (cd "$tmp" && awk -v f="$asset" '$2 == f' SHA256SUMS | sha256sum -c - >/dev/null 2>&1); then
    printf '%s✗%s checksum mismatch for %s\n' "$UI_YELLOW" "$UI_RESET" "$asset" >&2
    rm -rf "$tmp"
    return 1
  fi
  tar xzf "$tmp/$asset" -C "$tmp" clipaste || { rm -rf "$tmp"; return 1; }
  mkdir -p "$HOME/.local/bin"
  # rename into place so a running daemon keeps its old inode
  install -m 755 "$tmp/clipaste" "$HOME/.local/bin/.clipaste.new" &&
    mv -f "$HOME/.local/bin/.clipaste.new" "$HOME/.local/bin/clipaste"
  rm -rf "$tmp"
  ob__extend_path
  printf '%s✓%s clipaste %s%s installed to %s\n' "$UI_GREEN" "$UI_RESET" \
    "${current:+v$current → }" "$tag" "$HOME/.local/bin/clipaste"
}

ob__clipaste_install_macos() {
  if ! ob_has brew; then
    ob_install_brew || return 1
  fi
  if brew list --formula clipaste >/dev/null 2>&1; then
    if [ -n "$(brew outdated --formula clipaste 2>/dev/null)" ]; then
      printf '%s→%s upgrading clipaste...\n' "$UI_CYAN" "$UI_RESET"
      brew upgrade clipaste || return 1
      brew services restart clipaste
    else
      printf '%s✓%s clipaste %s already installed\n' "$UI_GREEN" "$UI_RESET" "$(ob_clipaste_version)"
    fi
  else
    printf '%s→%s brew install %s/clipaste\n' "$UI_CYAN" "$UI_RESET" "$OB_CLIPASTE_REPO"
    brew install "$OB_CLIPASTE_REPO/clipaste" || return 1
  fi
  if [ "$(brew services list 2>/dev/null | awk '$1 == "clipaste" {print $2}')" = started ]; then
    printf '%s✓%s clipaste service running\n' "$UI_GREEN" "$UI_RESET"
  else
    brew services start clipaste ||
      printf '%s!%s brew services start failed; over SSH, log in to the Mac desktop and run it there\n' "$UI_YELLOW" "$UI_RESET"
  fi
}

ob__clipaste_autostart_linux() {
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
  local file="$dir/clipaste.desktop"
  local yn
  if [ -f "$file" ]; then
    printf '%s=%s desktop autostart already set (%s)\n' "$UI_DIM" "$UI_RESET" "$file"
  else
    printf 'Start clipaste with the desktop session (%s)? [y/N] ' "$file"
    read -r yn
    case "$yn" in
      y|Y)
        mkdir -p "$dir"
        cat > "$file" <<DESKTOP
[Desktop Entry]
Type=Application
Name=clipaste
Comment=Serve clipboard screenshots to SSH and WSL2 consumers
Exec=$HOME/.local/bin/clipaste
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKTOP
        printf '%s+%s %s\n' "$UI_GREEN" "$UI_RESET" "$file"
        ;;
      *) printf 'skipped\n' ;;
    esac
  fi
  if pgrep -x clipaste >/dev/null 2>&1; then
    printf '%s✓%s clipaste daemon running\n' "$UI_GREEN" "$UI_RESET"
  else
    local log="${XDG_CACHE_HOME:-$HOME/.cache}/clipaste-daemon.log"
    mkdir -p "$(dirname -- "$log")"
    nohup "$HOME/.local/bin/clipaste" >"$log" 2>&1 &
    sleep 1
    if pgrep -x clipaste >/dev/null 2>&1; then
      printf '%s+%s clipaste daemon started (log: %s)\n' "$UI_GREEN" "$UI_RESET" "$log"
    else
      printf '%s!%s clipaste daemon exited right away; last log lines:\n' "$UI_YELLOW" "$UI_RESET"
      tail -n 5 "$log" | sed 's/^/  /'
    fi
  fi
}

# Ask for remote hosts and run `clipaste ssh-setup` for each. One host per line.
ob__clipaste_ssh_setup_prompt() {
  local line
  printf '\n%sRemote hosts that should receive pasted screenshots.%s\n' "$UI_BOLD" "$UI_RESET"
  printf '%sOne per line, e.g. "user@server" or "user@server -p 2222". Empty line to finish.%s\n' "$UI_DIM" "$UI_RESET"
  printf '%sssh-setup adds "RemoteForward %s" for each host to ~/.ssh/config.%s\n' "$UI_DIM" "$OB_CLIPASTE_PORT" "$UI_RESET"
  while true; do
    printf 'host> '
    read -r line || break
    [ -z "$line" ] && break
    # shellcheck disable=SC2086 — word splitting keeps "-p PORT"
    "$(ob_clipaste_bin)" ssh-setup $line ||
      printf '%s!%s ssh-setup failed for %s\n' "$UI_YELLOW" "$UI_RESET" "$line"
  done
}

# Make sure ~/.local/bin comes first on PATH in new shells, so the xclip and
# wl-paste helpers win over the real tools. Uses the same "# clipaste PATH"
# marker as `clipaste ssh-setup`, so neither side adds the line twice.
ob_clipaste_ensure_path() {
  local first rc yn
  first=$(printf '%s' "$OB_ORIG_PATH" | tr ':' '\n' | grep -n -x -e "$HOME/.local/bin" -e /usr/bin -e /bin | head -1)
  case "$first" in
    *:"$HOME/.local/bin") return 0 ;;
  esac
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if grep -qs 'clipaste PATH' "$rc"; then
      printf '%s=%s %s already puts ~/.local/bin first; open a new shell\n' "$UI_DIM" "$UI_RESET" "$rc"
      return 0
    fi
  done
  printf '%s!%s ~/.local/bin is not first on PATH, so the real xclip would answer Ctrl+V.\n' "$UI_YELLOW" "$UI_RESET"
  printf 'Add  export PATH="$HOME/.local/bin:$PATH"  to ~/.bashrc and ~/.zshrc? [y/N] '
  read -r yn
  case "$yn" in
    y|Y)
      for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || touch "$rc"
        printf '\n# clipaste PATH\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
        printf '%s+%s %s\n' "$UI_GREEN" "$UI_RESET" "$rc"
      done
      ;;
    *) printf 'skipped\n' ;;
  esac
}

# Client side: report whether the helpers and the tunnel are in place.
ob_clipaste_client_status() {
  local bin="$HOME/.local/bin"
  if [ -x "$bin/clipaste-paste" ]; then
    printf '%s✓%s clipaste-paste helper (%s)\n' "$UI_GREEN" "$UI_RESET" "$bin/clipaste-paste"
  else
    printf '%s+%s clipaste-paste helper not installed\n' "$UI_CYAN" "$UI_RESET"
  fi
  if grep -qs "$OB_CLIPASTE_PORT" "$bin/xclip" "$bin/wl-paste"; then
    printf '%s✓%s xclip / wl-paste helpers — Claude Code Ctrl+V uses them\n' "$UI_GREEN" "$UI_RESET"
  fi
  ob_has curl || printf '%s!%s curl is missing; the helpers need it\n' "$UI_YELLOW" "$UI_RESET"
  if curl -fsS -m 2 "http://127.0.0.1:$OB_CLIPASTE_PORT/health" >/dev/null 2>&1; then
    printf '%s✓%s paste server reachable on 127.0.0.1:%s\n' "$UI_GREEN" "$UI_RESET" "$OB_CLIPASTE_PORT"
  else
    printf '%s!%s no paste server on 127.0.0.1:%s yet\n' "$UI_YELLOW" "$UI_RESET" "$OB_CLIPASTE_PORT"
    printf '  On the machine you SSH from, the paste server must be running and its ~/.ssh/config\n'
    printf '  Host block for this machine needs:\n'
    printf '    %sRemoteForward %s 127.0.0.1:%s%s\n' "$UI_DIM" "$OB_CLIPASTE_PORT" "$OB_CLIPASTE_PORT" "$UI_RESET"
    printf '  (clipaste ssh-setup %s@%s adds it). Then open a new SSH session.\n' \
      "$(id -un)" "${HOSTNAME:-$(uname -n)}"
  fi
}

# Paste server: install and start the daemon on the machine you take screenshots on.
ob_install_clipaste_server() {
  local role yn
  role=$(ob_clipaste_role)
  printf 'role: %s%s%s\n\n' "$UI_BOLD" "$role" "$UI_RESET"
  case "$role" in
    macos)
      ob__clipaste_install_macos || return 1
      ;;
    linux-desktop)
      ob__ensure_packages curl:curl xclip:xclip wl-paste:wl-clipboard ||
        printf '%s!%s continuing; the paste server needs xclip (X11) or wl-clipboard (Wayland)\n' "$UI_YELLOW" "$UI_RESET"
      ob__clipaste_install_linux_binary || return 1
      ob__clipaste_autostart_linux
      ;;
    wsl)
      printf 'In WSL2 the paste server is clipaste.exe on Windows: run windows\\clipaste.cmd there.\n'
      printf 'Use "clipaste client" here to connect to it.\n'
      return 0
      ;;
    linux-remote)
      printf 'No desktop session here, so there is no clipboard to serve.\n'
      printf 'Run the paste server on the machine you take screenshots on,\n'
      printf 'and use "clipaste client" on this machine.\n'
      return 0
      ;;
    *)
      printf '%s✗%s unsupported OS: %s\n' "$UI_YELLOW" "$UI_RESET" "$(uname -s)" >&2
      return 1
      ;;
  esac

  printf '\nRegister remote hosts with ssh-setup now? It also installs the client there. [y/N] '
  read -r yn
  case "$yn" in y|Y) ob__clipaste_ssh_setup_prompt ;; esac
  echo
  "$(ob_clipaste_bin)" doctor || true
}
