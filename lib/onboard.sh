#!/usr/bin/env bash
# Onboarding: brew / mise / mise-managed tools.

ob_has() { command -v "$1" >/dev/null 2>&1; }

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
